import '../hebrew_date/hebrew_date.dart';
import '../sync/sync_state.dart';
import 'event_source.dart';
import 'event_time_of_day.dart';
import 'recurrence_rule.dart';

/// An immutable calendar event, mirroring the `events/{eventId}` document
/// shape in ARCHITECTURE.md §4.
///
/// [hebrewDate] is the source of truth for when the event happens — any
/// Gregorian projection is derived at read time via `HebrewDateEngine`, not
/// stored here (the domain layer has no notion of "derived for querying";
/// that is a data/sync-layer concern once M2b/M5 land).
class Event {
  const Event({
    required this.id,
    required this.ownerUid,
    required this.calendarId,
    required this.title,
    this.description = '',
    this.location = '',
    required this.hebrewDate,
    this.allDay = true,
    this.startTime,
    this.endTime,
    this.reminderMinutesBefore = const <int>[],
    this.recurrence = const RecurrenceRule(),
    required this.createdAt,
    required this.updatedAt,
    this.source = EventSource.app,
    this.googleSync = const GoogleSyncState(),
    this.googleInstanceSync = const <String, GoogleSyncState>{},
    this.colorId,
  });

  /// Repository-assigned identifier. Empty for an event not yet persisted.
  final String id;

  /// The uid of the user who owns this event (participant sharing is M6).
  final String ownerUid;

  /// Which of the owner's calendars this event belongs to.
  final String calendarId;

  final String title;
  final String description;

  /// Free-text location for M2a; structured lat/lng is deferred (M6).
  final String location;

  /// The Hebrew calendar date this event occurs on — the source of truth.
  final HebrewDate hebrewDate;

  /// Whether this is an all-day event (no [startTime]/[endTime]).
  final bool allDay;

  final EventTimeOfDay? startTime;
  final EventTimeOfDay? endTime;

  /// Minutes-before-event reminder offsets, e.g. `[10]` for "10 minutes
  /// before". Empty means no reminders.
  final List<int> reminderMinutesBefore;

  /// How this event repeats. Only [RecurrenceType.none] is exercised
  /// before M3.
  final RecurrenceRule recurrence;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Where this event originated (M5a — ARCHITECTURE.md §5): [EventSource.app]
  /// for events created in this app, [EventSource.google] for events
  /// imported from Google Calendar sync.
  final EventSource source;

  /// Google Calendar sync bookkeeping for this event's *single* remote
  /// counterpart (M5a — ARCHITECTURE.md §4 `googleSync`). Meaningful as the
  /// 1:1 mapping for a non-recurring event; for a recurring event
  /// (`recurrence.type != RecurrenceType.none`) its `googleEventId`/`etag`
  /// stay null (there is no single remote counterpart — see
  /// [googleInstanceSync]) while its `dirty`/`lastSyncedAt` still apply to
  /// the series as a whole ("this series has a pending edit to push").
  final GoogleSyncState googleSync;

  /// Per-materialized-instance Google Calendar sync bookkeeping for a
  /// recurring event, keyed by `occurrence_key.dart`'s `occurrenceKeyFor`
  /// (M5a — ARCHITECTURE.md §5 "individual materialized instances"). Empty
  /// for a non-recurring event, which uses [googleSync] directly instead.
  final Map<String, GoogleSyncState> googleInstanceSync;

  /// M10: the event's color as a Google Calendar color id ("1".."11", see
  /// `core/theme/event_colors.dart`), or null for the default color.
  final String? colorId;

  /// Returns a copy with the given fields replaced. Pass [clearStartTime]
  /// / [clearEndTime] to explicitly null out a time (a plain `startTime:
  /// null` argument is indistinguishable from "leave unchanged").
  Event copyWith({
    String? id,
    String? ownerUid,
    String? calendarId,
    String? title,
    String? description,
    String? location,
    HebrewDate? hebrewDate,
    bool? allDay,
    EventTimeOfDay? startTime,
    bool clearStartTime = false,
    EventTimeOfDay? endTime,
    bool clearEndTime = false,
    List<int>? reminderMinutesBefore,
    RecurrenceRule? recurrence,
    DateTime? createdAt,
    DateTime? updatedAt,
    EventSource? source,
    GoogleSyncState? googleSync,
    Map<String, GoogleSyncState>? googleInstanceSync,
    String? colorId,
    bool clearColorId = false,
  }) => Event(
    id: id ?? this.id,
    ownerUid: ownerUid ?? this.ownerUid,
    calendarId: calendarId ?? this.calendarId,
    title: title ?? this.title,
    description: description ?? this.description,
    location: location ?? this.location,
    hebrewDate: hebrewDate ?? this.hebrewDate,
    allDay: allDay ?? this.allDay,
    startTime: clearStartTime ? null : (startTime ?? this.startTime),
    endTime: clearEndTime ? null : (endTime ?? this.endTime),
    reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
    recurrence: recurrence ?? this.recurrence,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    source: source ?? this.source,
    googleSync: googleSync ?? this.googleSync,
    googleInstanceSync: googleInstanceSync ?? this.googleInstanceSync,
    colorId: clearColorId ? null : (colorId ?? this.colorId),
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Event ||
        other.id != id ||
        other.ownerUid != ownerUid ||
        other.calendarId != calendarId ||
        other.title != title ||
        other.description != description ||
        other.location != location ||
        other.hebrewDate != hebrewDate ||
        other.allDay != allDay ||
        other.startTime != startTime ||
        other.endTime != endTime ||
        other.recurrence != recurrence ||
        other.createdAt != createdAt ||
        other.updatedAt != updatedAt ||
        other.source != source ||
        other.googleSync != googleSync ||
        other.colorId != colorId ||
        other.reminderMinutesBefore.length != reminderMinutesBefore.length ||
        other.googleInstanceSync.length != googleInstanceSync.length) {
      return false;
    }
    for (int i = 0; i < reminderMinutesBefore.length; i++) {
      if (other.reminderMinutesBefore[i] != reminderMinutesBefore[i]) {
        return false;
      }
    }
    for (final MapEntry<String, GoogleSyncState> entry
        in googleInstanceSync.entries) {
      if (other.googleInstanceSync[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerUid,
    calendarId,
    title,
    description,
    location,
    hebrewDate,
    allDay,
    startTime,
    endTime,
    recurrence,
    createdAt,
    updatedAt,
    source,
    googleSync,
    colorId,
    Object.hashAll(reminderMinutesBefore),
    Object.hashAllUnordered(
      googleInstanceSync.entries.map(
        (MapEntry<String, GoogleSyncState> e) => Object.hash(e.key, e.value),
      ),
    ),
  );

  @override
  String toString() =>
      'Event(id: $id, title: $title, hebrewDate: $hebrewDate, allDay: $allDay)';
}
