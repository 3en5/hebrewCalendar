/// A pure, googleapis-free snapshot of a single Google Calendar event, as
/// returned by `GoogleCalendarApi.listChangedEvents`/`getEvent`
/// (`lib/data/sync/google_calendar_api.dart`) and consumed by
/// `sync_planner.dart`. Deliberately not the googleapis-generated `Event`
/// type — the domain layer may not import `googleapis`
/// (RULES.md/ARCHITECTURE.md §3).
class RemoteEventSnapshot {
  const RemoteEventSnapshot({
    required this.googleEventId,
    required this.etag,
    required this.updatedAt,
    required this.isCancelled,
    this.summary = '',
    this.description = '',
    this.location = '',
    this.colorId,
    this.start,
    this.end,
    this.isAllDay = true,
    this.hebcalEventId,
    this.hebcalOccurrence,
  });

  final String googleEventId;
  final String etag;

  /// The remote `updated` timestamp — the authority for last-write-wins
  /// conflict resolution (ARCHITECTURE.md §5).
  final DateTime updatedAt;

  /// Whether this snapshot represents a deletion (Google Calendar
  /// `status: cancelled`, returned by incremental sync instead of omitting
  /// the event entirely).
  final bool isCancelled;

  final String summary;
  final String description;
  final String location;

  /// M10: Google's `colorId` ("1".."11"), null for the calendar color.
  final String? colorId;

  /// Null only for a cancelled event, where Google Calendar may omit
  /// start/end entirely.
  final DateTime? start;
  final DateTime? end;
  final bool isAllDay;

  /// This event's `extendedProperties.private.hebcalEventId`, if present —
  /// the marker that identifies an event as one of *our own* exports
  /// (ARCHITECTURE.md §5), so the importer can skip it instead of creating
  /// a duplicate local copy (avoiding an import/export echo loop).
  final String? hebcalEventId;

  /// This event's `extendedProperties.private.hebcalOccurrence`, if
  /// present — the occurrence key (`occurrence_key.dart`) of the specific
  /// materialized instance this remote event corresponds to.
  final String? hebcalOccurrence;

  /// Whether this snapshot carries our own export markers (both fields set)
  /// — see [hebcalEventId].
  bool get isOwnExport => hebcalEventId != null && hebcalOccurrence != null;

  @override
  String toString() =>
      'RemoteEventSnapshot(googleEventId: $googleEventId, etag: $etag, '
      'updatedAt: $updatedAt, isCancelled: $isCancelled, '
      'isOwnExport: $isOwnExport)';
}
