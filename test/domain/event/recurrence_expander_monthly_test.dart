// Unit tests for recurrence_expander.dart: RecurrenceType.hebrewMonthly,
// including the day-30 policy documented on recurrence_expander.dart /
// ARCHITECTURE.md §4 (a base anchored on day 30 must not double-fire in a
// short month).

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';

import '../../test_support/recurrence_expander_test_helpers.dart';

void main() {
  group('RecurrenceType.hebrewMonthly', () {
    test('day-30 policy across a Kislev (30 days) -> Tevet (always 29 days) '
        'transition does not double-fire', () {
      // 5786 has a 30-day Kislev; Tevet always has 29 days.
      expect(recurrenceTestEngine.daysInMonth(5786, HebrewMonth.kislev), 30);
      expect(recurrenceTestEngine.daysInMonth(5786, HebrewMonth.tevet), 29);

      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.kislev,
        day: 30,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.hebrewMonthly),
      );

      expect(
        monthOccurrenceDates(event, 5786, HebrewMonth.kislev),
        <HebrewDate>[base],
      );
      final List<HebrewDate> tevetOccurrences = monthOccurrenceDates(
        event,
        5786,
        HebrewMonth.tevet,
      );
      expect(
        tevetOccurrences,
        <HebrewDate>[
          const HebrewDate(year: 5786, month: HebrewMonth.tevet, day: 29),
        ],
        reason: 'exactly one clamped occurrence, not a double-fire',
      );
    });

    test('recurs across every month of the year, one occurrence per month', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 10,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.hebrewMonthly),
      );
      final List<HebrewMonth> months = recurrenceTestEngine.monthsInYear(5786);
      for (final HebrewMonth month in months) {
        final List<HebrewDate> occurrences = monthOccurrenceDates(
          event,
          5786,
          month,
        );
        expect(occurrences, hasLength(1), reason: month.name);
        expect(occurrences.single.day, 10);
      }
    });

    test('no occurrence before the base date', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 10,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.hebrewMonthly),
      );
      final HebrewDate previousMonth = recurrenceTestEngine.previousMonth(base);
      expect(
        monthOccurrenceDates(event, previousMonth.year, previousMonth.month),
        isEmpty,
      );
    });
  });
}
