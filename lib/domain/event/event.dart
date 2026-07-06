import '../hebrew_date/hebrew_date.dart';
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
        other.reminderMinutesBefore.length != reminderMinutesBefore.length) {
      return false;
    }
    for (int i = 0; i < reminderMinutesBefore.length; i++) {
      if (other.reminderMinutesBefore[i] != reminderMinutesBefore[i]) {
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
    Object.hashAll(reminderMinutesBefore),
  );

  @override
  String toString() =>
      'Event(id: $id, title: $title, hebrewDate: $hebrewDate, allDay: $allDay)';
}
