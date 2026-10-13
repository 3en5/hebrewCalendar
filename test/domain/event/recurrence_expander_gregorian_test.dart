// M22 (owner decision 2026-10-13): yearly and monthly recurrence by the
// Gregorian date. 29 February falls on 28 February in a non-leap year, and
// a monthly day the month lacks falls on its last day.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/recurrence_expander.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

HebrewDate _h(int y, int m, int d) => _engine.fromGregorian(DateTime(y, m, d));

List<DateTime> _gregorian(
  RecurrenceRule rule,
  DateTime base,
  DateTime from,
  DateTime to,
) => <DateTime>[
  for (final HebrewDate d in occurrencesInRange(
    base: _h(base.year, base.month, base.day),
    rule: rule,
    from: _h(from.year, from.month, from.day),
    to: _h(to.year, to.month, to.day),
    engine: _engine,
  ))
    _engine.toGregorian(d),
];

void main() {
  const RecurrenceRule yearly = RecurrenceRule(
    type: RecurrenceType.gregorianYearly,
  );
  const RecurrenceRule monthly = RecurrenceRule(
    type: RecurrenceType.gregorianMonthly,
  );

  test('yearly keeps the Gregorian date while the Hebrew date moves', () {
    final List<DateTime> dates = _gregorian(
      yearly,
      DateTime(2026, 10, 13),
      DateTime(2026, 1, 1),
      DateTime(2029, 12, 31),
    );
    expect(dates, <DateTime>[
      DateTime(2026, 10, 13),
      DateTime(2027, 10, 13),
      DateTime(2028, 10, 13),
      DateTime(2029, 10, 13),
    ]);
    // Not the same Hebrew day every year.
    final HebrewDate a = _h(2026, 10, 13);
    final HebrewDate b = _h(2027, 10, 13);
    expect(a.month == b.month && a.day == b.day, isFalse);
  });

  test('29 February falls on 28 February outside leap years', () {
    final List<DateTime> dates = _gregorian(
      yearly,
      DateTime(2028, 2, 29),
      DateTime(2028, 1, 1),
      DateTime(2032, 12, 31),
    );
    expect(dates, <DateTime>[
      DateTime(2028, 2, 29),
      DateTime(2029, 2, 28),
      DateTime(2030, 2, 28),
      DateTime(2031, 2, 28),
      DateTime(2032, 2, 29),
    ]);
  });

  test('monthly on the 31st falls on each short month\'s last day', () {
    final List<DateTime> dates = _gregorian(
      monthly,
      DateTime(2027, 1, 31),
      DateTime(2027, 1, 1),
      DateTime(2027, 5, 31),
    );
    expect(dates, <DateTime>[
      DateTime(2027, 1, 31),
      DateTime(2027, 2, 28),
      DateTime(2027, 3, 31),
      DateTime(2027, 4, 30),
      DateTime(2027, 5, 31),
    ]);
  });

  test('nothing before the anchor; a window far ahead starts mid-series', () {
    expect(
      _gregorian(
        monthly,
        DateTime(2027, 6, 10),
        DateTime(2027, 1, 1),
        DateTime(2027, 6, 9),
      ),
      isEmpty,
    );
    expect(
      _gregorian(
        monthly,
        DateTime(2027, 6, 10),
        DateTime(2040, 3, 1),
        DateTime(2040, 4, 30),
      ),
      <DateTime>[DateTime(2040, 3, 10), DateTime(2040, 4, 10)],
    );
  });

  test('until and exceptions apply as for every other type', () {
    final HebrewDate skipped = _h(2027, 3, 10);
    final List<DateTime> dates = _gregorian(
      RecurrenceRule(
        type: RecurrenceType.gregorianMonthly,
        until: _h(2027, 4, 10),
        exceptions: <HebrewDate>[skipped],
      ),
      DateTime(2027, 1, 10),
      DateTime(2027, 1, 1),
      DateTime(2027, 12, 31),
    );
    expect(dates, <DateTime>[
      DateTime(2027, 1, 10),
      DateTime(2027, 2, 10),
      DateTime(2027, 4, 10),
    ]);
  });
}
