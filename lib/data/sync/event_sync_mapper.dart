/// Pure(-ish; needs [HebrewDateEngine] for Hebrew<->Gregorian conversion,
/// hence "data" not "domain") mapping between the app's [Event]/[HebrewDate]
/// types and the Google Calendar-facing [GoogleEventWrite] DTO
/// (ARCHITECTURE.md §5). Kept separate from `sync_engine.dart` so the
/// "what does one exported instance look like" question is answered in
/// exactly one place, mirroring `event_firestore_mapper.dart`'s role for
/// Firestore.
library;

import '../../domain/event/event.dart';
import '../../domain/event/event_time_of_day.dart';
import '../../domain/hebrew_date/hebrew_date.dart';
import '../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../domain/sync/occurrence_key.dart';
import 'google_calendar_api.dart';

/// Builds the [GoogleEventWrite] for exporting [event]'s occurrence at
/// [occurrenceDate] — for a non-recurring event, [occurrenceDate] is just
/// `event.hebrewDate`; for a recurring event it is one of the dates
/// `recurrence_expander.dart` computed for the rolling export window
/// (ARCHITECTURE.md §5 — "individual materialized instances").
GoogleEventWrite buildGoogleEventWrite({
  required Event event,
  required HebrewDate occurrenceDate,
  required HebrewDateEngine engine,
}) {
  final DateTime day = engine.toGregorian(occurrenceDate);
  final DateTime start = _start(event, day);
  final DateTime end = _end(event, day, start);
  return GoogleEventWrite(
    summary: event.title,
    description: event.description,
    location: event.location,
    isAllDay: event.allDay,
    start: start,
    end: end,
    hebcalEventId: event.id,
    hebcalOccurrence: occurrenceKeyFor(occurrenceDate),
  );
}

DateTime _start(Event event, DateTime day) {
  final EventTimeOfDay? startTime = event.startTime;
  if (event.allDay || startTime == null) {
    return day;
  }
  return DateTime(
    day.year,
    day.month,
    day.day,
    startTime.hour,
    startTime.minute,
  );
}

DateTime _end(Event event, DateTime day, DateTime start) {
  final EventTimeOfDay? endTime = event.endTime;
  if (endTime != null) {
    return DateTime(day.year, day.month, day.day, endTime.hour, endTime.minute);
  }
  // All-day events use an exclusive end boundary one day after the start,
  // matching Google Calendar's own all-day event convention (and
  // `event_firestore_mapper.dart`'s `_gregorianEnd`).
  return event.allDay ? start.add(const Duration(days: 1)) : start;
}
