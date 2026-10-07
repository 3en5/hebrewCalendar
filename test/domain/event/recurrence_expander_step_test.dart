// Unit tests for recurrence_expander.dart: RecurrenceType.weekly and
// RecurrenceType.daily, which step by a fixed number of Gregorian days
// (no Adar/day-30 ambiguity, unlike the Hebrew-calendar-shaped types).

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/recurrence_expander.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';

import '../../test_support/recurrence_expander_test_helpers.dart';

void main() {
  group('RecurrenceType.weekly', () {
    test('every occurrence is exactly 7 Gregorian days after the last', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 5,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.weekly),
      );
      final HebrewDate rangeEnd = HebrewDate(
        year: 5787,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      final List<HebrewDate> occurrences = occurrencesInRange(
        base: base,
        rule: event.recurrence,
        from: base,
        to: rangeEnd,
        engine: recurrenceTestEngine,
      );
      expect(occurrences.first, base);
      for (int i = 1; i < occurrences.length; i++) {
        final Duration gap = recurrenceTestEngine
            .toGregorian(occurrences[i])
            .difference(recurrenceTestEngine.toGregorian(occurrences[i - 1]));
        expect(gap, const Duration(days: 7), reason: 'index $i');
      }
      expect(
        occurrences.any((HebrewDate d) => d.month == HebrewMonth.cheshvan),
        isTrue,
        reason: 'crosses the Tishrei -> Cheshvan month boundary',
      );
    });

    test('crosses the Elul -> Tishrei Hebrew year boundary', () {
      final int elulDays = recurrenceTestEngine.daysInMonth(
        5786,
        HebrewMonth.elul,
      );
      final HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.elul,
        day: elulDays - 5,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.weekly),
      );
      final List<HebrewDate> elulOccurrences = monthOccurrenceDates(
        event,
        5786,
        HebrewMonth.elul,
      );
      final List<HebrewDate> tishreiOccurrences = monthOccurrenceDates(
        event,
        5787,
        HebrewMonth.tishrei,
      );
      expect(elulOccurrences, isNotEmpty);
      expect(
        tishreiOccurrences,
        isNotEmpty,
        reason: 'weekly stepping must roll from Elul into next year Tishrei',
      );
      for (final HebrewDate occurrence in <HebrewDate>[
        ...elulOccurrences,
        ...tishreiOccurrences,
      ]) {
        final int daysSinceBase = recurrenceTestEngine
            .toGregorian(occurrence)
            .difference(recurrenceTestEngine.toGregorian(base))
            .inDays;
        expect(daysSinceBase % 7, 0, reason: '$occurrence');
      }
    });

    test("crosses from Shevat into a leap year's Adar I", () {
      expect(recurrenceTestEngine.isLeapYear(5787), isTrue);
      final int shevatDays = recurrenceTestEngine.daysInMonth(
        5787,
        HebrewMonth.shvat,
      );
      final HebrewDate base = HebrewDate(
        year: 5787,
        month: HebrewMonth.shvat,
        day: shevatDays - 5,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.weekly),
      );
      final List<HebrewDate> adarIOccurrences = monthOccurrenceDates(
        event,
        5787,
        HebrewMonth.adarI,
      );
      expect(
        adarIOccurrences,
        isNotEmpty,
        reason: 'weekly stepping must roll from Shevat into Adar I',
      );
      for (final HebrewDate occurrence in adarIOccurrences) {
        final int daysSinceBase = recurrenceTestEngine
            .toGregorian(occurrence)
            .difference(recurrenceTestEngine.toGregorian(base))
            .inDays;
        expect(daysSinceBase % 7, 0);
        expect(daysSinceBase, greaterThan(0));
      }
    });

    test('no occurrence before the base date', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 15,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.weekly),
      );
      // Elul of 5785 comes chronologically *before* Tishrei of 5786 (a
      // Hebrew year runs Tishrei..Elul), unlike Elul of 5786 itself, which
      // comes nearly a year *after* this base date.
      expect(monthOccurrenceDates(event, 5785, HebrewMonth.elul), isEmpty);
    });
  });

  group('RecurrenceType.daily', () {
    test('crosses Elul (29/30 days) into 1 Tishrei of the next year', () {
      final int elulDays = recurrenceTestEngine.daysInMonth(
        5786,
        HebrewMonth.elul,
      );
      final HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.elul,
        day: elulDays - 2,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.daily),
      );
      final List<HebrewDate> elulOccurrences = monthOccurrenceDates(
        event,
        5786,
        HebrewMonth.elul,
      );
      final List<HebrewDate> tishreiOccurrences = monthOccurrenceDates(
        event,
        5787,
        HebrewMonth.tishrei,
      );
      expect(elulOccurrences, <HebrewDate>[
        HebrewDate(year: 5786, month: HebrewMonth.elul, day: elulDays - 2),
        HebrewDate(year: 5786, month: HebrewMonth.elul, day: elulDays - 1),
        HebrewDate(year: 5786, month: HebrewMonth.elul, day: elulDays),
      ]);
      expect(
        tishreiOccurrences.first,
        const HebrewDate(year: 5787, month: HebrewMonth.tishrei, day: 1),
      );
    });

    test('every occurrence is exactly 1 Gregorian day after the last', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.daily),
      );
      final List<HebrewDate> occurrences = monthOccurrenceDates(
        event,
        5786,
        HebrewMonth.tishrei,
      );
      expect(
        occurrences,
        hasLength(recurrenceTestEngine.daysInMonth(5786, HebrewMonth.tishrei)),
      );
      for (int i = 1; i < occurrences.length; i++) {
        expect(occurrences[i].day, occurrences[i - 1].day + 1);
      }
    });

    test('no occurrence before the base date', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 15,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.daily),
      );
      final List<HebrewDate> occurrences = monthOccurrenceDates(
        event,
        5786,
        HebrewMonth.tishrei,
      );
      expect(occurrences.every((HebrewDate d) => d.day >= 15), isTrue);
    });
  });
}
