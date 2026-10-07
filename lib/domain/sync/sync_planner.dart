/// Pure decision logic for Google Calendar two-way sync (ARCHITECTURE.md §5,
/// M5a). No Flutter/Firebase/googleapis — every function here takes plain
/// domain values in and returns [SyncAction]s out; `sync_engine.dart` is the
/// only thing that actually calls the Google Calendar API or the event
/// repository. This is where every conflict-resolution decision is made
/// (task brief §1), so it is the most heavily unit-tested file in the
/// milestone.
library;

import '../event/event.dart';
import '../hebrew_date/hebrew_date.dart';
import 'export_candidate.dart';
import 'remote_event_snapshot.dart';
import 'sync_action.dart';

/// Decides what to do, per occurrence, to bring Google Calendar in line with
/// the app's local events (the "push"/export half of sync).
///
/// [candidates] is every occurrence within the rolling export window that
/// should exist on Google Calendar right now (ARCHITECTURE.md §5 — a
/// recurring event contributes one candidate per materialized instance,
/// computed by the caller via `recurrence_expander.dart`). [staleInstances]
/// is every previously-exported instance that is *not* in [candidates] this
/// pass (its occurrence fell out of the window/was excepted, or its event
/// was deleted) and therefore needs deleting remotely.
///
/// Decision per candidate:
/// - no known state, or known state has no `googleEventId` yet -> create.
/// - known state has a `googleEventId` and the event is dirty (a local edit
///   is pending export) -> update, using the known `etag` as the `If-Match`
///   precondition (ARCHITECTURE.md §5 — detected races cause a 412 the
///   engine re-resolves via [resolveConflict]).
/// - known state has a `googleEventId` and the event is not dirty -> already
///   in sync, skip.
List<SyncAction> planExportActions({
  required List<ExportCandidate> candidates,
  required List<StaleExportInstance> staleInstances,
}) {
  final List<SyncAction> actions = <SyncAction>[
    for (final ExportCandidate candidate in candidates)
      _planSingleExport(candidate),
    for (final StaleExportInstance stale in staleInstances)
      DeleteRemoteAction(
        eventId: stale.eventId,
        occurrenceKey: stale.occurrenceKey,
        googleEventId: stale.state.googleEventId!,
        etag: stale.state.etag,
      ),
  ];
  return actions;
}

SyncAction _planSingleExport(ExportCandidate candidate) {
  final String? googleEventId = candidate.knownState?.googleEventId;
  if (googleEventId == null) {
    return CreateRemoteAction(
      event: candidate.event,
      occurrenceDate: candidate.occurrenceDate,
      occurrenceKey: candidate.occurrenceKey,
    );
  }
  if (!candidate.event.googleSync.dirty) {
    return const SkipAction(SkipReason.upToDate);
  }
  return UpdateRemoteAction(
    event: candidate.event,
    occurrenceDate: candidate.occurrenceDate,
    occurrenceKey: candidate.occurrenceKey,
    googleEventId: googleEventId,
    etag: candidate.knownState?.etag,
  );
}

/// Decides what to do, per remote event, to bring the local app data in
/// line with Google Calendar (the "pull"/import half of sync).
///
/// [remoteEvents] is every event `GoogleCalendarApi.listChangedEvents`
/// returned this pass. [localEventsByGoogleId] maps a `googleEventId` to the
/// local [Event] already known to correspond to it (built by the caller from
/// every event's `googleSync`/`googleInstanceSync` state) — used to tell
/// "already-imported, check for changes" apart from "brand new, import it".
///
/// Decision per remote event:
/// - carries our own `hebcalEventId`/`hebcalOccurrence` markers -> skip
///   ([SkipReason.ownExportEcho]): it is one of our own exports, not an
///   external change (ARCHITECTURE.md §5 — this is what prevents an
///   import/export echo loop).
/// - cancelled with no known local match -> skip
///   ([SkipReason.deletedWithNoLocalMatch]).
/// - cancelled with a known local match -> delete the local copy.
/// - no known local match -> create a local copy (`source: google`).
/// - known local match, remote `updated` strictly after the local event's
///   `updatedAt` -> last-write-wins: overwrite the local copy.
/// - known local match, local `updatedAt` at or after remote `updated` ->
///   the local copy is at least as new; nothing to import
///   ([SkipReason.localIsNewer]/[SkipReason.upToDate]) — the export/push
///   side is responsible for pushing the local copy if it's actually dirty.
List<SyncAction> planImportActions({
  required List<RemoteEventSnapshot> remoteEvents,
  required Map<String, Event> localEventsByGoogleId,
}) {
  return <SyncAction>[
    for (final RemoteEventSnapshot remote in remoteEvents)
      _planSingleImport(remote, localEventsByGoogleId[remote.googleEventId]),
  ];
}

SyncAction _planSingleImport(RemoteEventSnapshot remote, Event? local) {
  if (remote.isOwnExport) {
    return const SkipAction(SkipReason.ownExportEcho);
  }
  if (remote.isCancelled) {
    if (local == null) {
      return const SkipAction(SkipReason.deletedWithNoLocalMatch);
    }
    return DeleteLocalAction(existingEventId: local.id);
  }
  if (local == null) {
    return CreateLocalAction(remote: remote);
  }
  if (remote.updatedAt.isAfter(local.updatedAt)) {
    return UpdateLocalAction(existingEventId: local.id, remote: remote);
  }
  return const SkipAction(SkipReason.localIsNewer);
}

/// Re-resolves a single event/occurrence after the engine's push hit a 412
/// (etag precondition failed — someone else changed it since we last read
/// it, ARCHITECTURE.md §5). Re-applies the same last-write-wins rule
/// [planImportActions] uses, but returning the push-side action needed when
/// local wins instead.
///
/// - remote `updated` after [local]'s `updatedAt` -> remote wins: apply it
///   locally (same as an ordinary import).
/// - otherwise -> local wins: retry the push with the freshly-fetched
///   `etag`.
SyncAction resolveConflict({
  required Event local,
  required RemoteEventSnapshot remote,
  required HebrewDate occurrenceDate,
  required String occurrenceKey,
}) {
  if (remote.isCancelled) {
    return DeleteLocalAction(existingEventId: local.id);
  }
  if (remote.updatedAt.isAfter(local.updatedAt)) {
    return UpdateLocalAction(existingEventId: local.id, remote: remote);
  }
  return UpdateRemoteAction(
    event: local,
    occurrenceDate: occurrenceDate,
    occurrenceKey: occurrenceKey,
    googleEventId: remote.googleEventId,
    etag: remote.etag,
  );
}
