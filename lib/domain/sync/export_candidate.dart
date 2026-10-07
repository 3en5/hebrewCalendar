import '../event/event.dart';
import '../hebrew_date/hebrew_date.dart';
import 'sync_state.dart';

/// One occurrence eligible for export, fed to
/// `sync_planner.dart`'s `planExportActions`.
///
/// For a non-recurring [event] there is exactly one [ExportCandidate] (its
/// own [Event.hebrewDate]); for a recurring [event] there is one per
/// occurrence `recurrence_expander.dart` computes within the rolling export
/// window (ARCHITECTURE.md §5 — "individual materialized instances").
class ExportCandidate {
  const ExportCandidate({
    required this.event,
    required this.occurrenceDate,
    required this.occurrenceKey,
    this.knownState,
  });

  final Event event;
  final HebrewDate occurrenceDate;
  final String occurrenceKey;

  /// The last known Google sync state for this specific occurrence
  /// (`Event.googleSync` for a non-recurring event, or the matching
  /// `Event.googleInstanceSync[occurrenceKey]` entry for a recurring one),
  /// or null if never synced and not discovered via dedup-by-extendedProperties.
  final GoogleSyncState? knownState;
}

/// A previously-exported instance that no longer has a matching
/// [ExportCandidate] this pass (its occurrence fell out of the export
/// window, was added to `RecurrenceRule.exceptions`, or the whole event was
/// deleted) — the planner turns these into [DeleteRemoteAction]s.
class StaleExportInstance {
  const StaleExportInstance({
    required this.eventId,
    required this.occurrenceKey,
    required this.state,
  });

  final String eventId;
  final String occurrenceKey;
  final GoogleSyncState state;
}

/// A local event that was deleted while it still had exported remote
/// counterpart(s) — queued by the repository (RULES.md §6: kept in the
/// repository layer) for the sync engine to clean up on its next push.
class PendingGoogleDeletion {
  const PendingGoogleDeletion({
    required this.eventId,
    required this.remoteInstances,
  });

  final String eventId;

  /// Every remote instance that needs deleting: for a non-recurring event,
  /// a single entry (from `Event.googleSync`); for a recurring event, one
  /// per `Event.googleInstanceSync` entry.
  final List<GoogleSyncState> remoteInstances;
}
