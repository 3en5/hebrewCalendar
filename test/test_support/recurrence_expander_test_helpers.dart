// Shared fixtures for the recurrence_expander_*_test.dart files: building a
// minimal recurring [Event] and reading back just its occurrence dates for
// a given Hebrew month, so each test file doesn't repeat this boilerplate.

import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_occurrence.dart';
import 'package:hebrew_calendar/domain/event/recurrence_expander.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';

const HebrewDateEngine recurrenceTestEngine = HebrewDateEngine();

/// A minimal event anchored at [hebrewDate] with the given [recurrence].
Event buildRecurringEvent(HebrewDate hebrewDate, RecurrenceRule recurrence) {
  final DateTime now = DateTime(2026, 1, 1);
  return Event(
    id: 'event-1',
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: 'אירוע',
    hebrewDate: hebrewDate,
    recurrence: recurrence,
    createdAt: now,
    updatedAt: now,
  );
}

/// The occurrence dates of [event] within Hebrew [year]/[month], via
/// [occurrencesInHebrewMonth] — the same entry point repositories use.
List<HebrewDate> monthOccurrenceDates(
  Event event,
  int year,
  HebrewMonth month,
) => occurrencesInHebrewMonth(
  event: event,
  year: year,
  month: month,
  engine: recurrenceTestEngine,
).map((EventOccurrence occurrence) => occurrence.occurrenceDate).toList();
