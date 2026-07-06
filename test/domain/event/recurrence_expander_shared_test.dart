// Unit tests for recurrence_expander.dart's cross-cutting rules that apply
// to every RecurrenceType: `until` is an inclusive upper bound, dates in
// `exceptions` are skipped, and occurrencesInHebrewMonth correctly wraps
// each date as an EventOccurrence.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_occurrence.dart';
import 'package:hebrew_calendar/domain/event/recurrence_expander.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';

import '../../test_support/recurrence_expander_test_helpers.dart';

void main() {
  group('until (inclusive boundary)', () {
    test('an occurrence exactly on `until` is included; the next is not', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      const HebrewDate until = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 15,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.daily, until: until),
      );
      final List<HebrewDate> occurrences = monthOccurrenceDates(
        event,
        5786,
        HebrewMonth.tishrei,
      );
      expect(occurrences.last, until);
      expect(occurrences.any((HebrewDate d) => d.day == 16), isFalse);
    });

    test('applies to hebrewYearly recurrence too', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.nisan,
        day: 15,
      );
      const HebrewDate until = HebrewDate(
        year: 5787,
        month: HebrewMonth.nisan,
        day: 15,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.hebrewYearly, until: until),
      );
      expect(monthOccurrenceDates(event, 5787, HebrewMonth.nisan), <HebrewDate>[
        until,
      ]);
      expect(monthOccurrenceDates(event, 5788, HebrewMonth.nisan), isEmpty);
    });
  });

  group('exceptions', () {
    test('skip exactly the excepted occurrence, no others', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      const HebrewDate excepted = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 3,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(
          type: RecurrenceType.daily,
          exceptions: <HebrewDate>[excepted],
        ),
      );
      final List<HebrewDate> occurrences = monthOccurrenceDates(
        event,
        5786,
        HebrewMonth.tishrei,
      );
      expect(occurrences, isNot(contains(excepted)));
      expect(
        occurrences,
        contains(
          const HebrewDate(year: 5786, month: HebrewMonth.tishrei, day: 2),
        ),
      );
      expect(
        occurrences,
        contains(
          const HebrewDate(year: 5786, month: HebrewMonth.tishrei, day: 4),
        ),
      );
    });

    test('applies to hebrewMonthly recurrence too', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 10,
      );
      const HebrewDate excepted = HebrewDate(
        year: 5786,
        month: HebrewMonth.cheshvan,
        day: 10,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(
          type: RecurrenceType.hebrewMonthly,
          exceptions: <HebrewDate>[excepted],
        ),
      );
      expect(
        monthOccurrenceDates(event, 5786, HebrewMonth.tishrei),
        <HebrewDate>[base],
      );
      expect(monthOccurrenceDates(event, 5786, HebrewMonth.cheshvan), isEmpty);
      expect(
        monthOccurrenceDates(event, 5786, HebrewMonth.kislev),
        <HebrewDate>[
          const HebrewDate(year: 5786, month: HebrewMonth.kislev, day: 10),
        ],
      );
    });
  });

  group('occurrencesInHebrewMonth wraps EventOccurrence correctly', () {
    test('each occurrence carries the original event and its own date', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.daily),
      );
      final List<EventOccurrence> occurrences = occurrencesInHebrewMonth(
        event: event,
        year: 5786,
        month: HebrewMonth.tishrei,
        engine: recurrenceTestEngine,
      );
      expect(occurrences, isNotEmpty);
      for (final EventOccurrence occurrence in occurrences) {
        expect(occurrence.event, event);
        expect(occurrence.isRecurring, isTrue);
      }
    });
  });
}
