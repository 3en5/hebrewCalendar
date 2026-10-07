// Unit tests for the pure HebrewDate value object: equality, ordering and
// copyWith — no kosher_dart, no Flutter.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';

void main() {
  group('HebrewDate equality', () {
    test('two dates with identical fields are equal', () {
      const HebrewDate a = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      const HebrewDate b = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('dates differing by any field are not equal', () {
      const HebrewDate base = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      expect(base, isNot(base.copyWith(year: 5787)));
      expect(base, isNot(base.copyWith(month: HebrewMonth.cheshvan)));
      expect(base, isNot(base.copyWith(day: 2)));
    });
  });

  group('HebrewDate ordering', () {
    test('compares by year first', () {
      const HebrewDate earlier = HebrewDate(
        year: 5785,
        month: HebrewMonth.elul,
        day: 29,
      );
      const HebrewDate later = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      expect(earlier < later, isTrue);
      expect(later > earlier, isTrue);
      expect(earlier.compareTo(later), lessThan(0));
    });

    test('compares by month within the same leap year without mixing '
        'adar/adarI/adarII', () {
      const HebrewDate shvat = HebrewDate(
        year: 5784,
        month: HebrewMonth.shvat,
        day: 30,
      );
      const HebrewDate adarI = HebrewDate(
        year: 5784,
        month: HebrewMonth.adarI,
        day: 1,
      );
      const HebrewDate adarII = HebrewDate(
        year: 5784,
        month: HebrewMonth.adarII,
        day: 1,
      );
      const HebrewDate nisan = HebrewDate(
        year: 5784,
        month: HebrewMonth.nisan,
        day: 1,
      );
      expect(shvat < adarI, isTrue);
      expect(adarI < adarII, isTrue);
      expect(adarII < nisan, isTrue);
    });

    test('compares by day within the same month', () {
      const HebrewDate day1 = HebrewDate(
        year: 5786,
        month: HebrewMonth.nisan,
        day: 1,
      );
      const HebrewDate day2 = HebrewDate(
        year: 5786,
        month: HebrewMonth.nisan,
        day: 2,
      );
      expect(day1 <= day2, isTrue);
      expect(day2 >= day1, isTrue);
    });
  });

  group('HebrewDate.copyWith', () {
    test('replaces only the given fields', () {
      const HebrewDate original = HebrewDate(
        year: 5786,
        month: HebrewMonth.tishrei,
        day: 1,
      );
      final HebrewDate copy = original.copyWith(day: 15);
      expect(copy.year, original.year);
      expect(copy.month, original.month);
      expect(copy.day, 15);
    });
  });
}
