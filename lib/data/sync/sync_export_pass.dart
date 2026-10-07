/// The "push" half of `sync_engine.dart`'s sync pass (ARCHITECTURE.md §5) —
/// split into its own file (RULES.md §2) since export + import + engine
/// glue together would exceed 500 lines.
///
/// Order of operations, per pass: first flush any queued
/// [PendingGoogleDeletion]s (an app-side delete always wins over any other
/// pending push for the same event, since the event no longer exists
/// locally), then push every dirty event — a single [ExportCandidate] for a
/// non-recurring event, or one per occurrence `recurrence_expander.dart`
/// computes within the rolling export window for a recurring one.
library;

import '../../domain/event/event.dart';
import '../../domain/event/event_occurrence.dart';
import '../../domain/event/event_repository.dart';
import '../../domain/event/recurrence_expander.dart';
import '../../domain/event/recurrence_rule.dart';
import '../../domain/hebrew_date/hebrew_date.dart';
import '../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../domain/sync/export_candidate.dart';
import '../../domain/sync/occurrence_key.dart';
import '../../domain/sync/remote_event_snapshot.dart';
import '../../domain/sync/sync_action.dart';
import '../../domain/sync/sync_planner.dart';
import '../../domain/sync/sync_state.dart';
import 'event_sync_mapper.dart';
import 'google_calendar_api.dart';

/// The result of pushing a single occurrence: where to record the resulting
/// [GoogleSyncState] (an event's top-level `googleSync` for a non-recurring
/// event; one `googleInstanceSync` entry, keyed by `occurrenceKey`, for a
/// recurring one) — or null if nothing needs recording (a delete, a skip, or
/// a conflict resolved in the remote's favor, which already wrote the new
/// local state itself via `EventRepository.upsertFromGoogle`/
/// `applyRemoteDelete`).
typedef _PushOutcome = ({String occurrenceKey, GoogleSyncState state})?;

class SyncExportPass {
  SyncExportPass({
    required GoogleCalendarApi api,
    required EventRepository repository,
    required HebrewDateEngine engine,
    DateTime Function() now = DateTime.now,
    Duration exportWindow = const Duration(days: 730),
  }) : _api = api,
       _repository = repository,
       _engine = engine,
       _now = now,
       _exportWindow = exportWindow;

  final GoogleCalendarApi _api;
  final EventRepository _repository;
  final HebrewDateEngine _engine;
  final DateTime Function() _now;
  final Duration _exportWindow;

  /// [ownExportsLookup] (built by `SyncImportPass` from remote events
  /// carrying our own extendedProperties) lets a candidate whose local
  /// state is unknown adopt an already-existing remote instance instead of
  /// creating a duplicate (ARCHITECTURE.md §5 "never create duplicate
  /// exports"). Keyed by `'$eventId|$occurrenceKey'`.
  Future<void> run({
    required Map<String, GoogleSyncState> ownExportsLookup,
  }) async {
    await _flushPendingDeletions();
    final List<Event> events = await _repository.getAllForSync();
    final DateTime start = _now();
    final HebrewDate from = _engine.fromGregorian(start);
    final HebrewDate to = _engine.fromGregorian(start.add(_exportWindow));
    for (final Event event in events) {
      if (!event.googleSync.dirty) {
        continue;
      }
      if (event.recurrence.type == RecurrenceType.none) {
        await _exportSingle(event, ownExportsLookup);
      } else {
        await _exportRecurring(event, from, to, ownExportsLookup);
      }
    }
  }

  Future<void> _flushPendingDeletions() async {
    final List<PendingGoogleDeletion> pending = await _repository
        .takePendingGoogleDeletions();
    for (final PendingGoogleDeletion deletion in pending) {
      for (final GoogleSyncState instance in deletion.remoteInstances) {
        final String? googleEventId = instance.googleEventId;
        if (googleEventId != null) {
          await _api.deleteEvent(
            googleEventId: googleEventId,
            etag: instance.etag,
          );
        }
      }
    }
  }

  Future<void> _exportSingle(
    Event event,
    Map<String, GoogleSyncState> ownExportsLookup,
  ) async {
    final String key = occurrenceKeyFor(event.hebrewDate);
    final GoogleSyncState? known = event.googleSync.googleEventId != null
        ? event.googleSync
        : ownExportsLookup['${event.id}|$key'];
    final List<SyncAction> actions = planExportActions(
      candidates: <ExportCandidate>[
        ExportCandidate(
          event: event,
          occurrenceDate: event.hebrewDate,
          occurrenceKey: key,
          knownState: known,
        ),
      ],
      staleInstances: const <StaleExportInstance>[],
    );
    for (final SyncAction action in actions) {
      final _PushOutcome outcome = await _applyExportAction(action);
      if (outcome != null) {
        await _repository.updateSyncState(event.id, googleSync: outcome.state);
      }
    }
  }

  Future<void> _exportRecurring(
    Event event,
    HebrewDate from,
    HebrewDate to,
    Map<String, GoogleSyncState> ownExportsLookup,
  ) async {
    final List<EventOccurrence> occurrences = occurrencesForEventInRange(
      event: event,
      from: from,
      to: to,
      engine: _engine,
    );
    final Set<String> currentKeys = <String>{};
    final List<ExportCandidate> candidates = <ExportCandidate>[
      for (final EventOccurrence occurrence in occurrences)
        _candidateFor(event, occurrence, ownExportsLookup, currentKeys),
    ];
    final List<StaleExportInstance> stale = <StaleExportInstance>[
      for (final MapEntry<String, GoogleSyncState> entry
          in event.googleInstanceSync.entries)
        if (!currentKeys.contains(entry.key) &&
            entry.value.googleEventId != null)
          StaleExportInstance(
            eventId: event.id,
            occurrenceKey: entry.key,
            state: entry.value,
          ),
    ];
    final List<SyncAction> actions = planExportActions(
      candidates: candidates,
      staleInstances: stale,
    );
    final Map<String, GoogleSyncState> instanceUpdates =
        <String, GoogleSyncState>{};
    for (final SyncAction action in actions) {
      final _PushOutcome outcome = await _applyExportAction(action);
      if (outcome != null) {
        instanceUpdates[outcome.occurrenceKey] = outcome.state;
      }
    }
    await _repository.updateSyncState(
      event.id,
      googleSync: event.googleSync.copyWith(dirty: false, lastSyncedAt: _now()),
      googleInstanceSync: instanceUpdates,
    );
  }

  ExportCandidate _candidateFor(
    Event event,
    EventOccurrence occurrence,
    Map<String, GoogleSyncState> ownExportsLookup,
    Set<String> currentKeys,
  ) {
    final String key = occurrenceKeyFor(occurrence.occurrenceDate);
    currentKeys.add(key);
    final GoogleSyncState? known =
        event.googleInstanceSync[key] ?? ownExportsLookup['${event.id}|$key'];
    return ExportCandidate(
      event: event,
      occurrenceDate: occurrence.occurrenceDate,
      occurrenceKey: key,
      knownState: known,
    );
  }

  Future<_PushOutcome> _applyExportAction(SyncAction action) async {
    switch (action) {
      case final CreateRemoteAction a:
        final GoogleEventWrite write = buildGoogleEventWrite(
          event: a.event,
          occurrenceDate: a.occurrenceDate,
          engine: _engine,
        );
        final RemoteEventSnapshot snapshot = await _api.insertEvent(write);
        return (occurrenceKey: a.occurrenceKey, state: _syncedState(snapshot));
      case final UpdateRemoteAction a:
        try {
          final GoogleEventWrite write = buildGoogleEventWrite(
            event: a.event,
            occurrenceDate: a.occurrenceDate,
            engine: _engine,
          );
          final RemoteEventSnapshot snapshot = await _api.patchEvent(
            googleEventId: a.googleEventId,
            etag: a.etag,
            event: write,
          );
          return (
            occurrenceKey: a.occurrenceKey,
            state: _syncedState(snapshot),
          );
        } on GoogleEtagMismatchException {
          return _retryAfterConflict(a);
        }
      case final DeleteRemoteAction a:
        await _api.deleteEvent(googleEventId: a.googleEventId, etag: a.etag);
        return null;
      case final SkipAction _:
        return null;
      // Import-side actions never appear in export planning output.
      case final CreateLocalAction _:
      case final UpdateLocalAction _:
      case final DeleteLocalAction _:
        return null;
    }
  }

  /// Re-resolves the conflict after a 412 (ARCHITECTURE.md §5): re-fetches
  /// the current remote state and re-applies last-write-wins.
  Future<_PushOutcome> _retryAfterConflict(UpdateRemoteAction action) async {
    final RemoteEventSnapshot remote = await _api.getEvent(
      action.googleEventId,
    );
    final SyncAction resolved = resolveConflict(
      local: action.event,
      remote: remote,
      occurrenceDate: action.occurrenceDate,
      occurrenceKey: action.occurrenceKey,
    );
    switch (resolved) {
      case final UpdateLocalAction a:
        // Remote won: overwrite the local copy: no push-side state to
        // record for a dirty flag that no longer applies.
        await _repository.upsertFromGoogle(
          a.remote,
          existingEventId: a.existingEventId,
        );
        return null;
      case final DeleteLocalAction a:
        await _repository.applyRemoteDelete(a.existingEventId);
        return null;
      case final UpdateRemoteAction a:
        final GoogleEventWrite write = buildGoogleEventWrite(
          event: a.event,
          occurrenceDate: a.occurrenceDate,
          engine: _engine,
        );
        final RemoteEventSnapshot snapshot = await _api.patchEvent(
          googleEventId: a.googleEventId,
          etag: a.etag,
          event: write,
        );
        return (occurrenceKey: a.occurrenceKey, state: _syncedState(snapshot));
      default:
        return null;
    }
  }

  GoogleSyncState _syncedState(RemoteEventSnapshot snapshot) => GoogleSyncState(
    googleEventId: snapshot.googleEventId,
    etag: snapshot.etag,
    lastSyncedAt: _now(),
  );
}
