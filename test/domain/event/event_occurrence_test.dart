// Unit tests for EventOccurrence: equality/hashCode, isRecurring, and the
// shared compareEventOccurrences ordering used by every EventOccurrence
// producing repository.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_occurrence.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';

const HebrewDate _date = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 5,
);

Event _event({
  String title = 'אירוע',
  bool allDay = true,
  EventTimeOfDay? startTime,
  RecurrenceRule recurrence = const RecurrenceRule(),
}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Event(
    id: 'event-1',
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: title,
    hebrewDate: _date,
    allDay: allDay,
    startTime: startTime,
    recurrence: recurrence,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('equality', () {
    test('two occurrences with the same event and date are equal', () {
      final Event event = _event();
      final EventOccurrence a = EventOccurrence(
        event: event,
        occurrenceDate: _date,
      );
      final EventOccurrence b = EventOccurrence(
        event: event,
        occurrenceDate: _date,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing occurrenceDate makes them unequal', () {
      final Event event = _event();
      final EventOccurrence a = EventOccurrence(
        event: event,
        occurrenceDate: _date,
      );
      final EventOccurrence b = EventOccurrence(
        event: event,
        occurrenceDate: _date.copyWith(day: 6),
      );
      expect(a, isNot(b));
    });

    test('differing event makes them unequal', () {
      final EventOccurrence a = EventOccurrence(
        event: _event(title: 'א'),
        occurrenceDate: _date,
      );
      final EventOccurrence b = EventOccurrence(
        event: _event(title: 'ב'),
        occurrenceDate: _date,
      );
      expect(a, isNot(b));
    });
  });

  test('isRecurring reflects the event\'s recurrence type', () {
    final EventOccurrence none = EventOccurrence(
      event: _event(),
      occurrenceDate: _date,
    );
    final EventOccurrence recurring = EventOccurrence(
      event: _event(
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
      ),
      occurrenceDate: _date,
    );
    expect(none.isRecurring, isFalse);
    expect(recurring.isRecurring, isTrue);
  });

  test('toString includes the event id and occurrence date', () {
    final EventOccurrence occurrence = EventOccurrence(
      event: _event(),
      occurrenceDate: _date,
    );
    expect(occurrence.toString(), contains('event-1'));
    expect(occurrence.toString(), contains(_date.toString()));
  });

  group('compareEventOccurrences', () {
    test('orders by occurrenceDate first', () {
      final EventOccurrence earlier = EventOccurrence(
        event: _event(),
        occurrenceDate: _date,
      );
      final EventOccurrence later = EventOccurrence(
        event: _event(),
        occurrenceDate: _date.copyWith(day: 10),
      );
      expect(compareEventOccurrences(earlier, later), lessThan(0));
      expect(compareEventOccurrences(later, earlier), greaterThan(0));
    });

    test('on the same date, all-day events sort before timed ones', () {
      final EventOccurrence allDay = EventOccurrence(
        event: _event(allDay: true),
        occurrenceDate: _date,
      );
      final EventOccurrence timed = EventOccurrence(
        event: _event(
          allDay: false,
          startTime: const EventTimeOfDay(hour: 9, minute: 0),
        ),
        occurrenceDate: _date,
      );
      expect(compareEventOccurrences(allDay, timed), lessThan(0));
    });

    test(
      'on the same date and all-day-ness, earlier start time sorts first',
      () {
        final EventOccurrence early = EventOccurrence(
          event: _event(
            allDay: false,
            startTime: const EventTimeOfDay(hour: 8, minute: 0),
          ),
          occurrenceDate: _date,
        );
        final EventOccurrence late = EventOccurrence(
          event: _event(
            allDay: false,
            startTime: const EventTimeOfDay(hour: 14, minute: 0),
          ),
          occurrenceDate: _date,
        );
        expect(compareEventOccurrences(early, late), lessThan(0));
      },
    );

    test('falls back to title order when date/allDay/time are identical', () {
      final EventOccurrence a = EventOccurrence(
        event: _event(title: 'א'),
        occurrenceDate: _date,
      );
      final EventOccurrence b = EventOccurrence(
        event: _event(title: 'ב'),
        occurrenceDate: _date,
      );
      expect(compareEventOccurrences(a, b), lessThan(0));
    });

    test('equal occurrences compare as 0', () {
      final Event event = _event();
      final EventOccurrence a = EventOccurrence(
        event: event,
        occurrenceDate: _date,
      );
      final EventOccurrence b = EventOccurrence(
        event: event,
        occurrenceDate: _date,
      );
      expect(compareEventOccurrences(a, b), 0);
    });
  });
}
