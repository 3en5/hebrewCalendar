// Unit tests for HebrewDateEngine: round-trip conversion, leap years,
// Adar I/Adar II, Cheshvan/Kislev length variation, year-boundary crossing
// and month navigation. docs/TESTING_AND_DEPLOY.md requires these edge
// cases explicitly for the Hebrew date engine.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';

void main() {
  const HebrewDateEngine engine = HebrewDateEngine();

  group('known anchor dates (cross-checked against kosher_dart\'s own '
      'test suite)', () {
    test('1 Tishrei 5771 == 9 September 2010 (Rosh Hashana)', () {
      const HebrewDate roshHashana = HebrewDate(
        year: 5771,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      expect(engine.toGregorian(roshHashana), DateTime(2010, 9, 9));
      expect(engine.fromGregorian(DateTime(2010, 9, 9)), roshHashana);
    });

    test('1 Nisan 5771 == 5 April 2011', () {
      const HebrewDate nisan1 = HebrewDate(
        year: 5771,
        month: HebrewMonth.nisan,
        day: 1,
      );
      expect(engine.toGregorian(nisan1), DateTime(2011, 4, 5));
      expect(engine.fromGregorian(DateTime(2011, 4, 5)), nisan1);
    });
  });

  group('leap years', () {
    test('5784 is a leap year; 5786 is not', () {
      expect(engine.isLeapYear(5784), isTrue);
      expect(engine.isLeapYear(5786), isFalse);
    });

    test('leap year months include adarI and adarII, never plain adar', () {
      final List<HebrewMonth> months = engine.monthsInYear(5784);
      expect(months, contains(HebrewMonth.adarI));
      expect(months, contains(HebrewMonth.adarII));
      expect(months, isNot(contains(HebrewMonth.adar)));
      expect(months.length, 13);
      // adarI must directly precede adarII, which must directly precede
      // nisan — the Jewish calendar's actual month order.
      final int adarIIndex = months.indexOf(HebrewMonth.adarI);
      expect(months[adarIIndex + 1], HebrewMonth.adarII);
      expect(months[adarIIndex + 2], HebrewMonth.nisan);
    });

    test('non-leap year months include plain adar, never adarI/adarII', () {
      final List<HebrewMonth> months = engine.monthsInYear(5786);
      expect(months, contains(HebrewMonth.adar));
      expect(months, isNot(contains(HebrewMonth.adarI)));
      expect(months, isNot(contains(HebrewMonth.adarII)));
      expect(months.length, 12);
    });

    test('Adar I always has 30 days, Adar II always has 29 (5784)', () {
      expect(engine.daysInMonth(5784, HebrewMonth.adarI), 30);
      expect(engine.daysInMonth(5784, HebrewMonth.adarII), 29);
    });

    test('round-trips through Adar I and Adar II of a leap year', () {
      const HebrewDate adarI30 = HebrewDate(
        year: 5784,
        month: HebrewMonth.adarI,
        day: 30,
      );
      const HebrewDate adarII1 = HebrewDate(
        year: 5784,
        month: HebrewMonth.adarII,
        day: 1,
      );
      expect(engine.fromGregorian(engine.toGregorian(adarI30)), adarI30);
      expect(engine.fromGregorian(engine.toGregorian(adarII1)), adarII1);
      // Adar I 30 is the day immediately before Adar II 1.
      expect(
        engine.toGregorian(adarI30).add(const Duration(days: 1)),
        engine.toGregorian(adarII1),
      );
    });

    test('using adar in a leap year, or adarI/adarII in a non-leap year, '
        'throws', () {
      expect(
        () => engine.daysInMonth(5784, HebrewMonth.adar),
        throwsArgumentError,
      );
      expect(
        () => engine.daysInMonth(5786, HebrewMonth.adarI),
        throwsArgumentError,
      );
      expect(
        () => engine.daysInMonth(5786, HebrewMonth.adarII),
        throwsArgumentError,
      );
    });
  });

  group('Cheshvan / Kislev length varies by year type', () {
    test('both 29-day and 30-day variants occur, and every last day of '
        'month round-trips correctly', () {
      final Set<int> cheshvanLengths = <int>{};
      final Set<int> kislevLengths = <int>{};

      for (int year = 5770; year <= 5800; year++) {
        for (final HebrewMonth month in <HebrewMonth>[
          HebrewMonth.cheshvan,
          HebrewMonth.kislev,
        ]) {
          final int days = engine.daysInMonth(year, month);
          expect(days, anyOf(29, 30));
          if (month == HebrewMonth.cheshvan) {
            cheshvanLengths.add(days);
          } else {
            kislevLengths.add(days);
          }

          final HebrewDate lastDay = HebrewDate(
            year: year,
            month: month,
            day: days,
          );
          expect(
            engine.fromGregorian(engine.toGregorian(lastDay)),
            lastDay,
            reason: 'round-trip failed for $lastDay',
          );
        }
      }

      // Both a "long" (30-day) and a "short" (29-day) Cheshvan/Kislev
      // must occur somewhere in a 30-year span (chaserim/kesidran/shelaimim
      // year types all appear).
      expect(cheshvanLengths, containsAll(<int>[29, 30]));
      expect(kislevLengths, containsAll(<int>[29, 30]));
    });
  });

  group('year boundary', () {
    test('29 Elul rolls over to 1 Tishrei of the following year', () {
      const int year = 5785;
      final int elulDays = engine.daysInMonth(year, HebrewMonth.elul);
      final HebrewDate lastDayOfYear = HebrewDate(
        year: year,
        month: HebrewMonth.elul,
        day: elulDays,
      );
      final DateTime nextGregorianDay = engine
          .toGregorian(lastDayOfYear)
          .add(const Duration(days: 1));
      final HebrewDate roshHashana = engine.fromGregorian(nextGregorianDay);
      expect(
        roshHashana,
        HebrewDate(year: year + 1, month: HebrewMonth.tishrei, day: 1),
      );
    });
  });

  group('addMonths navigation', () {
    test('nextMonth/previousMonth are exact inverses across a leap-year '
        'boundary', () {
      const HebrewDate start = HebrewDate(
        year: 5783,
        month: HebrewMonth.elul,
        day: 1,
      );
      HebrewDate cursor = start;
      for (int i = 0; i < 20; i++) {
        cursor = engine.nextMonth(cursor);
      }
      for (int i = 0; i < 20; i++) {
        cursor = engine.previousMonth(cursor);
      }
      expect(cursor, start);
    });

    test('stepping month-by-month is strictly chronologically increasing '
        'across leap and non-leap years', () {
      HebrewDate cursor = const HebrewDate(
        year: 5783,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      for (int i = 0; i < 60; i++) {
        final HebrewDate next = engine.nextMonth(cursor);
        expect(engine.toGregorian(next), isAfter(engine.toGregorian(cursor)));
        cursor = next;
      }
    });

    test('addMonths crosses from a non-leap year Adar straight to Nisan '
        '(no Adar II)', () {
      const HebrewDate adar1 = HebrewDate(
        year: 5786,
        month: HebrewMonth.adar,
        day: 1,
      );
      final HebrewDate result = engine.addMonths(adar1, 1);
      expect(result.month, HebrewMonth.nisan);
      expect(result.year, 5786);
    });

    test('addMonths crosses from a leap year Adar I to Adar II, not Nisan', () {
      const HebrewDate adarI1 = HebrewDate(
        year: 5784,
        month: HebrewMonth.adarI,
        day: 1,
      );
      final HebrewDate result = engine.addMonths(adarI1, 1);
      expect(result.month, HebrewMonth.adarII);
      expect(result.year, 5784);
    });

    test('addMonths clamps day 30 down when the target month is shorter', () {
      // Kislev is always followed by Tevet, which never has 30 days, so a
      // 30 Kislev + 1 month always exercises the clamping behavior.
      int yearWithLongKislev = 5770;
      for (int year = 5770; year <= 5800; year++) {
        if (engine.daysInMonth(year, HebrewMonth.kislev) == 30) {
          yearWithLongKislev = year;
          break;
        }
      }
      final HebrewDate kislev30 = HebrewDate(
        year: yearWithLongKislev,
        month: HebrewMonth.kislev,
        day: 30,
      );
      final HebrewDate result = engine.addMonths(kislev30, 1);
      expect(result.month, HebrewMonth.tevet);
      expect(result.day, engine.daysInMonth(result.year, HebrewMonth.tevet));
      expect(result.day, lessThan(30));
    });

    test('addMonths(date, 0) returns the same date', () {
      const HebrewDate date = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 10,
      );
      expect(engine.addMonths(date, 0), date);
    });
  });

  group('weekdayIndex', () {
    test('Rosh Hashana 5771 (9 Sept 2010) was a Thursday (index 4)', () {
      const HebrewDate roshHashana = HebrewDate(
        year: 5771,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      expect(engine.weekdayIndex(roshHashana), 4);
    });
  });

  group('addDays (M3b — week/day view paging)', () {
    test('addDays(date, 0) returns the same date', () {
      const HebrewDate date = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 10,
      );
      expect(engine.addDays(date, 0), date);
    });

    test('adding 1 day crosses a Hebrew month boundary', () {
      final int elulDays = engine.daysInMonth(5785, HebrewMonth.elul);
      final HebrewDate lastDayOfYear = HebrewDate(
        year: 5785,
        month: HebrewMonth.elul,
        day: elulDays,
      );
      expect(
        engine.addDays(lastDayOfYear, 1),
        const HebrewDate(year: 5786, month: HebrewMonth.tishrei, day: 1),
      );
    });

    test('addDays and subtracting the same amount are exact inverses', () {
      const HebrewDate date = HebrewDate(
        year: 5786,
        month: HebrewMonth.shvat,
        day: 5,
      );
      expect(engine.addDays(engine.addDays(date, 40), -40), date);
    });

    test('adding 7 days always lands on the same weekday', () {
      const HebrewDate date = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      final HebrewDate nextWeek = engine.addDays(date, 7);
      expect(engine.weekdayIndex(nextWeek), engine.weekdayIndex(date));
    });
  });

  group('startOfWeek (M3b — week view boundaries)', () {
    test('a Sunday is its own start of week', () {
      const HebrewDate roshHashana = HebrewDate(
        // 1 Tishrei 5771 is a Thursday per the anchor-date test above, so
        // step forward to a known Sunday instead.
        year: 5771,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      final HebrewDate sunday = engine.addDays(
        roshHashana,
        7 - engine.weekdayIndex(roshHashana),
      );
      expect(engine.weekdayIndex(sunday), 0);
      expect(engine.startOfWeek(sunday), sunday);
    });

    test('any day in the week maps to the same Sunday', () {
      const HebrewDate date = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 15,
      );
      final HebrewDate sunday = engine.startOfWeek(date);
      expect(engine.weekdayIndex(sunday), 0);
      for (int offset = 0; offset < 7; offset++) {
        expect(engine.startOfWeek(engine.addDays(sunday, offset)), sunday);
      }
    });
  });

  group('monthName', () {
    test('returns the expected Hebrew names, including Adar variants', () {
      expect(engine.monthName(HebrewMonth.tishrei), 'תשרי');
      expect(engine.monthName(HebrewMonth.cheshvan), 'חשוון');
      expect(engine.monthName(HebrewMonth.kislev), 'כסלו');
      expect(engine.monthName(HebrewMonth.tevet), 'טבת');
      expect(engine.monthName(HebrewMonth.shvat), 'שבט');
      expect(engine.monthName(HebrewMonth.adar), 'אדר');
      expect(engine.monthName(HebrewMonth.adarI), 'אדר א׳');
      expect(engine.monthName(HebrewMonth.adarII), 'אדר ב׳');
      expect(engine.monthName(HebrewMonth.nisan), 'ניסן');
      expect(engine.monthName(HebrewMonth.iyar), 'אייר');
      expect(engine.monthName(HebrewMonth.sivan), 'סיוון');
      expect(engine.monthName(HebrewMonth.tammuz), 'תמוז');
      expect(engine.monthName(HebrewMonth.av), 'אב');
      expect(engine.monthName(HebrewMonth.elul), 'אלול');
    });
  });
}

/// Matcher: the actual [DateTime] is after the expected one.
Matcher isAfter(DateTime expected) => predicate<DateTime>(
  (DateTime actual) => actual.isAfter(expected),
  'is after $expected',
);
