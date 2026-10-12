// Unit tests for recurrence_expander.dart: RecurrenceType.none and
// RecurrenceType.hebrewYearly, including the Adar mapping and day-30
// policies documented on recurrence_expander.dart / ARCHITECTURE.md §4.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';

import '../../test_support/recurrence_expander_test_helpers.dart';

void main() {
  group('RecurrenceType.none', () {
    test('produces exactly one occurrence, on the base date only', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 10,
      );
      final Event event = buildRecurringEvent(base, const RecurrenceRule());
      expect(
        monthOccurrenceDates(event, 5786, HebrewMonth.tishrei),
        <HebrewDate>[base],
      );
      expect(monthOccurrenceDates(event, 5786, HebrewMonth.cheshvan), isEmpty);
      expect(monthOccurrenceDates(event, 5785, HebrewMonth.tishrei), isEmpty);
    });
  });

  group('RecurrenceType.hebrewYearly', () {
    test('15 Nisan recurs on 15 Nisan for 3 consecutive years', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.nisan,
        day: 15,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.hebrewYearly),
      );
      for (int year = 5786; year <= 5788; year++) {
        expect(
          monthOccurrenceDates(event, year, HebrewMonth.nisan),
          <HebrewDate>[
            HebrewDate(year: year, month: HebrewMonth.nisan, day: 15),
          ],
          reason: 'year $year',
        );
      }
    });

    test('day-30 policy (M15 default): 30 Cheshvan moves to 1 Kislev in a '
        'short Cheshvan year, and stays on 30 in a long Cheshvan year', () {
      // 5780 has a 30-day Cheshvan (anchor year); 5781 has a 29-day
      // Cheshvan; 5783 has a 30-day Cheshvan again (see
      // hebrew_date_engine_test.dart-style cross-checks).
      expect(recurrenceTestEngine.daysInMonth(5780, HebrewMonth.cheshvan), 30);
      expect(recurrenceTestEngine.daysInMonth(5781, HebrewMonth.cheshvan), 29);
      expect(recurrenceTestEngine.daysInMonth(5783, HebrewMonth.cheshvan), 30);

      const HebrewDate base = HebrewDate(
        year: 5780,
        month: HebrewMonth.cheshvan,
        day: 30,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.hebrewYearly),
      );

      expect(
        monthOccurrenceDates(event, 5780, HebrewMonth.cheshvan),
        <HebrewDate>[base],
      );
      expect(monthOccurrenceDates(event, 5781, HebrewMonth.cheshvan), isEmpty);
      expect(
        monthOccurrenceDates(event, 5781, HebrewMonth.kislev),
        <HebrewDate>[
          const HebrewDate(year: 5781, month: HebrewMonth.kislev, day: 1),
        ],
        reason: 'short Cheshvan: the 1st of the next month',
      );
      expect(
        monthOccurrenceDates(event, 5783, HebrewMonth.cheshvan),
        <HebrewDate>[
          const HebrewDate(year: 5783, month: HebrewMonth.cheshvan, day: 30),
        ],
        reason: 'long Cheshvan keeps day 30',
      );
    });

    test('day-30 policy, lastDay chosen: 30 Cheshvan falls on 29 in a short '
        'Cheshvan year', () {
      const HebrewDate base = HebrewDate(
        year: 5780,
        month: HebrewMonth.cheshvan,
        day: 30,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(
          type: RecurrenceType.hebrewYearly,
          shortMonth: ShortMonthPolicy.lastDay,
        ),
      );
      expect(
        monthOccurrenceDates(event, 5781, HebrewMonth.cheshvan),
        <HebrewDate>[
          const HebrewDate(year: 5781, month: HebrewMonth.cheshvan, day: 29),
        ],
      );
      expect(monthOccurrenceDates(event, 5781, HebrewMonth.kislev), isEmpty);
    });

    test('30 Adar I in a non-leap year moves to 1 Nisan by default', () {
      expect(recurrenceTestEngine.isLeapYear(5784), isTrue);
      expect(recurrenceTestEngine.isLeapYear(5785), isFalse);
      const HebrewDate base = HebrewDate(
        year: 5784,
        month: HebrewMonth.adarI,
        day: 30,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.hebrewYearly),
      );
      expect(monthOccurrenceDates(event, 5785, HebrewMonth.nisan), <HebrewDate>[
        const HebrewDate(year: 5785, month: HebrewMonth.nisan, day: 1),
      ]);
    });

    test('Adar mapping (M15 default): base in plain Adar (non-leap) recurs '
        'in Adar II in a leap year and plain Adar in a non-leap year', () {
      expect(recurrenceTestEngine.isLeapYear(5786), isFalse);
      expect(recurrenceTestEngine.isLeapYear(5787), isTrue);
      expect(recurrenceTestEngine.isLeapYear(5788), isFalse);

      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.adar,
        day: 10,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.hebrewYearly),
      );

      expect(monthOccurrenceDates(event, 5786, HebrewMonth.adar), <HebrewDate>[
        base,
      ]);
      expect(
        monthOccurrenceDates(event, 5787, HebrewMonth.adarII),
        <HebrewDate>[
          const HebrewDate(year: 5787, month: HebrewMonth.adarII, day: 10),
        ],
        reason: 'leap year: recurs in Adar II',
      );
      expect(monthOccurrenceDates(event, 5787, HebrewMonth.adarI), isEmpty);
      expect(
        monthOccurrenceDates(event, 5788, HebrewMonth.adar),
        <HebrewDate>[
          const HebrewDate(year: 5788, month: HebrewMonth.adar, day: 10),
        ],
        reason: 'non-leap year: recurs in plain Adar again',
      );
    });

    test('Adar mapping: base in Adar II recurs in Adar II in a leap year and '
        'plain Adar in a non-leap year', () {
      expect(recurrenceTestEngine.isLeapYear(5784), isTrue);
      expect(recurrenceTestEngine.isLeapYear(5786), isFalse);
      expect(recurrenceTestEngine.isLeapYear(5787), isTrue);

      const HebrewDate base = HebrewDate(
        year: 5784,
        month: HebrewMonth.adarII,
        day: 10,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.hebrewYearly),
      );

      expect(
        monthOccurrenceDates(event, 5784, HebrewMonth.adarII),
        <HebrewDate>[base],
      );
      expect(
        monthOccurrenceDates(event, 5786, HebrewMonth.adar),
        <HebrewDate>[
          const HebrewDate(year: 5786, month: HebrewMonth.adar, day: 10),
        ],
        reason: 'non-leap year: recurs in plain Adar',
      );
      expect(
        monthOccurrenceDates(event, 5787, HebrewMonth.adarII),
        <HebrewDate>[
          const HebrewDate(year: 5787, month: HebrewMonth.adarII, day: 10),
        ],
        reason: 'leap year again: recurs in Adar II, not Adar I',
      );
      expect(monthOccurrenceDates(event, 5787, HebrewMonth.adarI), isEmpty);
    });

    test('no occurrence before the base date (an earlier year is empty)', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.nisan,
        day: 15,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.hebrewYearly),
      );
      expect(monthOccurrenceDates(event, 5785, HebrewMonth.nisan), isEmpty);
    });

    test('Adar mapping: a base in Adar I stays in Adar I by default', () {
      const HebrewDate base = HebrewDate(
        year: 5784,
        month: HebrewMonth.adarI,
        day: 10,
      );
      final Event event = buildRecurringEvent(
        base,
        const RecurrenceRule(type: RecurrenceType.hebrewYearly),
      );
      expect(monthOccurrenceDates(event, 5787, HebrewMonth.adarI), <HebrewDate>[
        const HebrewDate(year: 5787, month: HebrewMonth.adarI, day: 10),
      ]);
      expect(monthOccurrenceDates(event, 5787, HebrewMonth.adarII), isEmpty);
      expect(
        monthOccurrenceDates(event, 5786, HebrewMonth.adar),
        <HebrewDate>[
          const HebrewDate(year: 5786, month: HebrewMonth.adar, day: 10),
        ],
        reason: 'Adar I in a year with a single Adar: plain Adar',
      );
    });

    test('Adar mapping: an explicit Adar I choice and "both"', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.adar,
        day: 10,
      );
      final Event adarI = buildRecurringEvent(
        base,
        const RecurrenceRule(
          type: RecurrenceType.hebrewYearly,
          leapAdar: LeapAdarPolicy.adarI,
        ),
      );
      expect(
        monthOccurrenceDates(adarI, 5787, HebrewMonth.adarI),
        hasLength(1),
      );
      expect(monthOccurrenceDates(adarI, 5787, HebrewMonth.adarII), isEmpty);

      final Event both = buildRecurringEvent(
        base,
        const RecurrenceRule(
          type: RecurrenceType.hebrewYearly,
          leapAdar: LeapAdarPolicy.both,
        ),
      );
      expect(monthOccurrenceDates(both, 5787, HebrewMonth.adarI), hasLength(1));
      expect(
        monthOccurrenceDates(both, 5787, HebrewMonth.adarII),
        hasLength(1),
      );
      expect(monthOccurrenceDates(both, 5788, HebrewMonth.adar), hasLength(1));
    });
  });
}
