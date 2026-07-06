import '../event/event.dart';
import '../hebrew_date/hebrew_date.dart';
import 'remote_event_snapshot.dart';

/// A single decision `sync_planner.dart` makes for one local event/occurrence
/// or one remote event: what `sync_engine.dart` should actually do about it.
///
/// A sealed class (not an enum) because each action carries the payload the
/// engine needs to execute it — the planner is the only place this decision
/// is made (ARCHITECTURE.md §5 "conflicts" — this is where conflict
/// resolution lives), the engine just executes it.
sealed class SyncAction {
  const SyncAction();
}

/// Create a new Google Calendar event for [event]'s occurrence at
/// [occurrenceDate] (identified by [occurrenceKey] — see
/// `occurrence_key.dart`). No remote counterpart is known to exist yet.
class CreateRemoteAction extends SyncAction {
  const CreateRemoteAction({
    required this.event,
    required this.occurrenceDate,
    required this.occurrenceKey,
  });

  final Event event;
  final HebrewDate occurrenceDate;
  final String occurrenceKey;
}

/// Update the existing Google Calendar event [googleEventId] (with
/// precondition [etag], if known) for [event]'s occurrence at
/// [occurrenceDate].
class UpdateRemoteAction extends SyncAction {
  const UpdateRemoteAction({
    required this.event,
    required this.occurrenceDate,
    required this.occurrenceKey,
    required this.googleEventId,
    this.etag,
  });

  final Event event;
  final HebrewDate occurrenceDate;
  final String occurrenceKey;
  final String googleEventId;
  final String? etag;
}

/// Delete the Google Calendar event [googleEventId] — the local event (or
/// this specific occurrence of it) no longer exists/no longer occurs.
class DeleteRemoteAction extends SyncAction {
  const DeleteRemoteAction({
    required this.eventId,
    required this.occurrenceKey,
    required this.googleEventId,
    this.etag,
  });

  final String eventId;
  final String occurrenceKey;
  final String googleEventId;
  final String? etag;
}

/// Create a new local event sourced from [remote] — it has no known local
/// counterpart.
class CreateLocalAction extends SyncAction {
  const CreateLocalAction({required this.remote});

  final RemoteEventSnapshot remote;
}

/// Overwrite the local event [existingEventId] with the newer [remote]
/// snapshot (last-write-wins: remote is newer — ARCHITECTURE.md §5).
class UpdateLocalAction extends SyncAction {
  const UpdateLocalAction({
    required this.existingEventId,
    required this.remote,
  });

  final String existingEventId;
  final RemoteEventSnapshot remote;
}

/// Remove the local event [existingEventId] — Google Calendar reports its
/// counterpart as deleted.
class DeleteLocalAction extends SyncAction {
  const DeleteLocalAction({required this.existingEventId});

  final String existingEventId;
}

/// Do nothing for this item this pass, for [reason].
class SkipAction extends SyncAction {
  const SkipAction(this.reason);

  final SkipReason reason;
}

/// Why a [SkipAction] was chosen — kept typed (not a free-text string) so
/// tests can assert on the exact reason without string-matching.
enum SkipReason {
  /// The remote event carries our own `hebcalEventId`/`hebcalOccurrence`
  /// extended properties — it is one of our own exports being echoed back
  /// by the sync feed, not an external change to import.
  ownExportEcho,

  /// Local and remote are already in sync (no local edit pending, remote
  /// `updated` no newer than our last known sync).
  upToDate,

  /// A cancelled/deleted remote event that has no known local counterpart
  /// — nothing to delete locally.
  deletedWithNoLocalMatch,

  /// A local last-write-wins comparison found the *local* copy to be the
  /// newer one; the export/push side (not the import side) is responsible
  /// for pushing it, so the import decision for this item is a no-op.
  localIsNewer,
}
