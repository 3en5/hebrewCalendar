// Unit tests for the pure RecurrenceRule value type: equality and
// copyWith. Expansion logic (materializing occurrences) is M3 scope — only
// the data shape is exercised here.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';

void main() {
  group('RecurrenceRule equality', () {
    test('defaults to type none, no until, no exceptions', () {
      const RecurrenceRule rule = RecurrenceRule();
      expect(rule.type, RecurrenceType.none);
      expect(rule.until, isNull);
      expect(rule.exceptions, isEmpty);
    });

    test('two rules with identical fields are equal', () {
      const RecurrenceRule a = RecurrenceRule(
        type: RecurrenceType.hebrewYearly,
        until: HebrewDate(year: 5790, month: HebrewMonth.elul, day: 1),
        exceptions: <HebrewDate>[
          HebrewDate(year: 5787, month: HebrewMonth.tevet, day: 10),
        ],
      );
      const RecurrenceRule b = RecurrenceRule(
        type: RecurrenceType.hebrewYearly,
        until: HebrewDate(year: 5790, month: HebrewMonth.elul, day: 1),
        exceptions: <HebrewDate>[
          HebrewDate(year: 5787, month: HebrewMonth.tevet, day: 10),
        ],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing type makes rules unequal', () {
      expect(
        const RecurrenceRule(type: RecurrenceType.daily),
        isNot(const RecurrenceRule(type: RecurrenceType.weekly)),
      );
    });

    test('differing exceptions list makes rules unequal', () {
      const HebrewDate exceptionDay = HebrewDate(
        year: 5787,
        month: HebrewMonth.tevet,
        day: 10,
      );
      expect(
        const RecurrenceRule(exceptions: <HebrewDate>[exceptionDay]),
        isNot(const RecurrenceRule(exceptions: <HebrewDate>[])),
      );
    });

    test('exception list order matters (matches List equality semantics)', () {
      const HebrewDate a = HebrewDate(
        year: 5787,
        month: HebrewMonth.tevet,
        day: 1,
      );
      const HebrewDate b = HebrewDate(
        year: 5787,
        month: HebrewMonth.tevet,
        day: 2,
      );
      expect(
        const RecurrenceRule(exceptions: <HebrewDate>[a, b]),
        isNot(const RecurrenceRule(exceptions: <HebrewDate>[b, a])),
      );
    });
  });

  group('RecurrenceRule copyWith', () {
    test('leaves fields unchanged when no argument given', () {
      const RecurrenceRule original = RecurrenceRule(
        type: RecurrenceType.hebrewMonthly,
      );
      expect(original.copyWith(), original);
    });

    test('clearUntil nulls out until', () {
      const RecurrenceRule withUntil = RecurrenceRule(
        until: HebrewDate(year: 5790, month: HebrewMonth.elul, day: 1),
      );
      final RecurrenceRule cleared = withUntil.copyWith(clearUntil: true);
      expect(cleared.until, isNull);
    });

    test('passing a new until without clearUntil updates it', () {
      const RecurrenceRule original = RecurrenceRule(
        until: HebrewDate(year: 5790, month: HebrewMonth.elul, day: 1),
      );
      const HebrewDate newUntil = HebrewDate(
        year: 5795,
        month: HebrewMonth.elul,
        day: 1,
      );
      final RecurrenceRule updated = original.copyWith(until: newUntil);
      expect(updated.until, newUntil);
    });
  });
}
