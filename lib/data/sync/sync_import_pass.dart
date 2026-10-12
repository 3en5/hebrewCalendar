/// The "pull" half of `sync_engine.dart`'s sync pass (ARCHITECTURE.md §5) —
/// split out from `sync_export_pass.dart`/`sync_engine.dart` (RULES.md §2).
///
/// Fetches changed events since the last sync token (or every event on a
/// first sync/after a 410), separates our own echoed exports (identified by
/// `extendedProperties`) from genuinely external events, and applies
/// `sync_planner.dart`'s import decisions.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../../domain/event/event.dart';
import '../../domain/event/event_repository.dart';
import '../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../domain/sync/remote_event_snapshot.dart';
import '../../domain/sync/sync_action.dart';
import '../../domain/sync/sync_planner.dart';
import '../../domain/sync/sync_state.dart';
import 'google_calendar_api.dart';
import 'own_export_changes.dart';

/// The outcome of one import pass: the sync token to persist for next time,
/// and a lookup of every one of *our own* exports the feed happened to
/// return this pass (only populated on a full listing — an incremental
/// sync only returns recently-changed events, so this is only reliable
/// right after a first sync/410 resync) — handed to `SyncExportPass` so it
/// can dedup-by-extendedProperties instead of creating a duplicate export
/// for a candidate whose local sync state is unknown (ARCHITECTURE.md §5).
class SyncImportPassResult {
  const SyncImportPassResult({
    required this.nextSyncToken,
    required this.ownExportsLookup,
  });

  final String? nextSyncToken;

  /// Keyed by `'$hebcalEventId|$hebcalOccurrence'`.
  final Map<String, GoogleSyncState> ownExportsLookup;
}

class SyncImportPass {
  SyncImportPass({
    required GoogleCalendarApi api,
    required EventRepository repository,
    required HebrewDateEngine engine,
    DateTime Function() now = DateTime.now,
  }) : _api = api,
       _repository = repository,
       _engine = engine,
       _now = now;

  /// How many local writes an import pass runs in parallel.
  static const int _kApplyChunkSize = 20;

  /// Above this many incoming changes, read all local events in one query
  /// instead of one lookup per change.
  static const int _kBulkLookupThreshold = 30;

  final GoogleCalendarApi _api;
  final EventRepository _repository;
  final HebrewDateEngine _engine;
  final DateTime Function() _now;

  Future<SyncImportPassResult> run({required String? syncToken}) async {
    GoogleEventsPage page;
    try {
      page = await _api.listChangedEvents(syncToken: syncToken);
    } on GoogleSyncTokenExpiredException {
      // ARCHITECTURE.md §5: the stored token is no longer valid — drop it
      // and do a full resync instead.
      page = await _api.listChangedEvents(syncToken: null);
    }

    final Map<String, GoogleSyncState> ownExportsLookup =
        <String, GoogleSyncState>{};
    final List<RemoteEventSnapshot> importCandidates = <RemoteEventSnapshot>[];
    for (final RemoteEventSnapshot snapshot in page.events) {
      if (snapshot.isOwnExport && !snapshot.isCancelled) {
        ownExportsLookup['${snapshot.hebcalEventId}|${snapshot.hebcalOccurrence}'] =
            GoogleSyncState(
              googleEventId: snapshot.googleEventId,
              etag: snapshot.etag,
              lastSyncedAt: _now(),
            );
      } else if (!snapshot.isOwnExport) {
        importCandidates.add(snapshot);
      }
    }

    // Device-feedback round #9: one query for all local events instead of
    // one `getByGoogleEventId` query per remote event — a first sync of a
    // long-used Google Calendar has hundreds of events, and hundreds of
    // sequential queries kept the pass running for minutes (the app was
    // closed before it ever finished, so nothing was imported).
    // An incremental sync usually brings a handful of changes: look those
    // up one by one rather than reading every local event.
    // Our own exports are never imported as new events, but changes made
    // to them in Google are applied (M17), and their guests' replies are
    // copied onto the local event (M11).
    final OwnExportChanges ownChanges = OwnExportChanges(
      repository: _repository,
      engine: _engine,
      now: _now,
    );
    for (final RemoteEventSnapshot snapshot in page.events) {
      if (snapshot.isOwnExport) {
        await _guarded(() => ownChanges.applyOwnExport(snapshot));
      }
    }

    final Map<String, Event> localByGoogleId = <String, Event>{};
    if (importCandidates.length > _kBulkLookupThreshold) {
      for (final Event local in await _repository.getAllForSync()) {
        final String? googleId = local.googleSync.googleEventId;
        if (googleId != null) {
          localByGoogleId[googleId] = local;
        }
      }
    } else {
      for (final RemoteEventSnapshot snapshot in importCandidates) {
        final Event? local = await _repository.getByGoogleEventId(
          snapshot.googleEventId,
        );
        if (local != null) {
          localByGoogleId[snapshot.googleEventId] = local;
        }
      }
    }

    // A deletion in Google usually arrives without our markers; one with no
    // matching single event may be an instance of one of our series (M17).
    for (final RemoteEventSnapshot snapshot in importCandidates) {
      if (snapshot.isCancelled &&
          !localByGoogleId.containsKey(snapshot.googleEventId)) {
        await _guarded(() => ownChanges.applyUnmatchedCancellation(snapshot));
      }
    }

    final List<SyncAction> actions = planImportActions(
      remoteEvents: importCandidates,
      localEventsByGoogleId: localByGoogleId,
    );
    // Writes go out a chunk at a time in parallel rather than strictly one
    // by one (each Firestore write waits for the server's acknowledgement).
    for (int i = 0; i < actions.length; i += _kApplyChunkSize) {
      await Future.wait(actions.skip(i).take(_kApplyChunkSize).map(_apply));
    }

    return SyncImportPassResult(
      nextSyncToken: page.nextSyncToken,
      ownExportsLookup: ownExportsLookup,
    );
  }

  /// One Google change that can't be applied must not stop the whole pass
  /// (device report 2026-10-12): it is logged and skipped.
  Future<void> _guarded(Future<Object?> Function() apply) async {
    try {
      await apply();
    } catch (error) {
      debugPrint('[sync] skipped a Google change to an app event: $error');
    }
  }

  Future<void> _apply(SyncAction action) async {
    switch (action) {
      case final CreateLocalAction a:
        await _repository.upsertFromGoogle(a.remote);
      case final UpdateLocalAction a:
        await _repository.upsertFromGoogle(
          a.remote,
          existingEventId: a.existingEventId,
        );
      case final DeleteLocalAction a:
        await _repository.applyRemoteDelete(a.existingEventId);
      case final SkipAction _:
        break;
      // Export-side actions never appear in import planning output.
      case final CreateRemoteAction _:
      case final UpdateRemoteAction _:
      case final DeleteRemoteAction _:
        break;
    }
  }
}
