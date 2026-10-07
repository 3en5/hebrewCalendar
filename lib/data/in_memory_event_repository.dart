import 'dart:async';

import '../domain/event/default_calendar_id.dart';
import '../domain/event/event.dart';
import '../domain/event/event_occurrence.dart';
import '../domain/event/event_repository.dart';
import '../domain/event/event_source.dart';
import '../domain/event/recurrence_expander.dart';
import '../domain/hebrew_date/hebrew_date.dart';
import '../domain/hebrew_date/hebrew_date_engine.dart';
import '../domain/sync/export_candidate.dart';
import '../domain/sync/remote_event_snapshot.dart';
import '../domain/sync/sync_state.dart';

/// In-memory [EventRepository]: the only implementation until Firebase
/// wiring lands in M2b, and the permanent implementation used by widget
/// tests afterwards (task brief M2a §3).
///
/// [idGenerator] and [now] are injectable so tests get deterministic ids
/// and timestamps instead of depending on a shared static counter or the
/// wall clock. Recurring events are expanded into [EventOccurrence]s on
/// every read via `recurrence_expander.dart` (M3a) — the exact same
/// expansion logic `FirestoreEventRepository` uses, so behavior doesn't
/// diverge between the two [EventRepository] implementations.
class InMemoryEventRepository implements EventRepository {
  InMemoryEventRepository({
    String Function()? idGenerator,
    DateTime Function()? now,
    HebrewDateEngine engine = const HebrewDateEngine(),
  }) : _idGenerator = idGenerator ?? _defaultIdGenerator,
       _now = now ?? DateTime.now,
       _engine = engine;

  final String Function() _idGenerator;
  final DateTime Function() _now;
  final HebrewDateEngine _engine;
  final Map<String, Event> _events = <String, Event>{};

  /// Deletions queued for the M5a sync engine to clean up remotely — see
  /// [delete]/[takePendingGoogleDeletions].
  final List<PendingGoogleDeletion> _pendingDeletions =
      <PendingGoogleDeletion>[];

  /// Broadcasts a signal (no payload) whenever [_events] changes; each
  /// [watchEventsForHebrewMonth] subscription recomputes its own filtered
  /// snapshot from [_events] in response, rather than the change event
  /// carrying data itself.
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static int _idCounter = 0;

  static String _defaultIdGenerator() => 'event-${_idCounter++}';

  @override
  Stream<List<EventOccurrence>> watchEventsForHebrewMonth(
    int year,
    HebrewMonth month,
  ) {
    final HebrewDate from = HebrewDate(year: year, month: month, day: 1);
    final HebrewDate to = HebrewDate(
      year: year,
      month: month,
      day: _engine.daysInMonth(year, month),
    );
    return watchOccurrencesInRange(from, to);
  }

  @override
  Stream<List<EventOccurrence>> watchOccurrencesInRange(
    HebrewDate from,
    HebrewDate to,
  ) {
    // Built by hand (rather than an `async*` generator that `yield`s the
    // initial snapshot then `yield*`s a mapped `_changes.stream`) because
    // that two-step shape has a subscription-timing race: a broadcast
    // stream drops `add()` calls made before a listener attaches, and the
    // generator only subscribes to `_changes` *after* delivering its first
    // value — so a mutation made synchronously right after subscribing
    // (e.g. a widget that watches and immediately creates an event, or a
    // test asserting on emissions) could be silently missed. Subscribing
    // to `_changes` and emitting the initial snapshot together inside
    // `onListen` closes that gap.
    late final StreamController<List<EventOccurrence>> controller;
    StreamSubscription<void>? changesSubscription;
    controller = StreamController<List<EventOccurrence>>.broadcast(
      onListen: () {
        changesSubscription = _changes.stream.listen(
          (_) => controller.add(_occurrencesForRange(from, to)),
        );
        controller.add(_occurrencesForRange(from, to));
      },
      onCancel: () {
        unawaited(changesSubscription?.cancel());
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }

  @override
  Future<Event?> getById(String id) async => _events[id];

  @override
  Future<Event> create(Event event) async {
    final DateTime timestamp = _now();
    // A newly-created event always needs exporting (M5a: repository update
    // hook, RULES.md §6 — kept here, not in UI callers).
    final Event created = event.copyWith(
      id: _idGenerator(),
      createdAt: timestamp,
      updatedAt: timestamp,
      googleSync: event.googleSync.copyWith(dirty: true),
    );
    _events[created.id] = created;
    _notify();
    return created;
  }

  @override
  Future<Event> update(Event event) async {
    final Event? existing = _events[event.id];
    if (existing == null) {
      throw StateError('No event with id "${event.id}" exists.');
    }
    // Every local edit marks the event dirty again (M5a repository hook),
    // regardless of which sync state the caller passed in — only
    // `updateSyncState` (used exclusively by the sync engine) is allowed to
    // leave `dirty` alone.
    final Event updated = event.copyWith(
      createdAt: existing.createdAt,
      updatedAt: _now(),
      googleSync: event.googleSync.copyWith(dirty: true),
    );
    _events[updated.id] = updated;
    _notify();
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    final Event? existing = _events.remove(id);
    if (existing == null) {
      return;
    }
    _enqueuePendingDeletionIfSynced(existing);
    _notify();
  }

  @override
  Future<List<Event>> getAllForSync() async => _events.values.toList();

  @override
  Future<Event?> getByGoogleEventId(String googleEventId) async {
    for (final Event event in _events.values) {
      if (event.googleSync.googleEventId == googleEventId) {
        return event;
      }
    }
    return null;
  }

  @override
  Future<void> updateSyncState(
    String eventId, {
    GoogleSyncState? googleSync,
    Map<String, GoogleSyncState>? googleInstanceSync,
  }) async {
    final Event? existing = _events[eventId];
    if (existing == null) {
      return;
    }
    final Map<String, GoogleSyncState> mergedInstances =
        <String, GoogleSyncState>{
          ...existing.googleInstanceSync,
          ...?googleInstanceSync,
        };
    _events[eventId] = existing.copyWith(
      googleSync: googleSync ?? existing.googleSync,
      googleInstanceSync: mergedInstances,
    );
    _notify();
  }

  @override
  Future<List<PendingGoogleDeletion>> takePendingGoogleDeletions() async {
    final List<PendingGoogleDeletion> drained = List<PendingGoogleDeletion>.of(
      _pendingDeletions,
    );
    _pendingDeletions.clear();
    return drained;
  }

  @override
  Future<Event> upsertFromGoogle(
    RemoteEventSnapshot snapshot, {
    String? existingEventId,
  }) async {
    final DateTime start = snapshot.start ?? _now();
    final HebrewDate hebrewDate = _engine.fromGregorian(start);
    final GoogleSyncState syncState = GoogleSyncState(
      googleEventId: snapshot.googleEventId,
      etag: snapshot.etag,
      lastSyncedAt: _now(),
    );
    final Event? existing = existingEventId == null
        ? null
        : _events[existingEventId];
    final Event upserted =
        (existing ??
                Event(
                  id: _idGenerator(),
                  ownerUid: '',
                  calendarId: kDefaultCalendarId,
                  title: snapshot.summary,
                  hebrewDate: hebrewDate,
                  createdAt: _now(),
                  updatedAt: snapshot.updatedAt,
                ))
            .copyWith(
              title: snapshot.summary,
              description: snapshot.description,
              location: snapshot.location,
              hebrewDate: hebrewDate,
              allDay: snapshot.isAllDay,
              updatedAt: snapshot.updatedAt,
              source: EventSource.google,
              googleSync: syncState,
              clearStartTime: snapshot.isAllDay,
              clearEndTime: snapshot.isAllDay,
            );
    _events[upserted.id] = upserted;
    _notify();
    return upserted;
  }

  @override
  Future<void> applyRemoteDelete(String id) async {
    if (_events.remove(id) != null) {
      _notify();
    }
  }

  void _enqueuePendingDeletionIfSynced(Event event) {
    final List<GoogleSyncState> instances = <GoogleSyncState>[
      if (event.googleSync.googleEventId != null) event.googleSync,
      ...event.googleInstanceSync.values.where(
        (GoogleSyncState state) => state.googleEventId != null,
      ),
    ];
    if (instances.isNotEmpty) {
      _pendingDeletions.add(
        PendingGoogleDeletion(eventId: event.id, remoteInstances: instances),
      );
    }
  }

  /// Seeds the repository directly with pre-built events, bypassing
  /// [create]'s id/timestamp assignment (M5c demo mode — the events already
  /// carry their final ids/timestamps, built by
  /// `lib/domain/event/demo_events.dart`). Not part of [EventRepository];
  /// used only by `eventRepositoryProvider` to populate the demo-mode
  /// repository before anything reads from it.
  void seedForDemo(List<Event> events) {
    for (final Event event in events) {
      _events[event.id] = event;
    }
    _notify();
  }

  /// Closes the broadcast change stream. Not part of [EventRepository] —
  /// call it from test teardown for a repository built inside a single
  /// test; the app-wide provider instance intentionally lives for the
  /// whole app session and is never disposed.
  void dispose() {
    unawaited(_changes.close());
  }

  void _notify() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  List<EventOccurrence> _occurrencesForRange(HebrewDate from, HebrewDate to) {
    final List<EventOccurrence> matches = <EventOccurrence>[
      for (final Event event in _events.values)
        ...occurrencesForEventInRange(
          event: event,
          from: from,
          to: to,
          engine: _engine,
        ),
    ];
    matches.sort(compareEventOccurrences);
    return matches;
  }
}
