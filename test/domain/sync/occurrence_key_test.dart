// Unit test for occurrence_key.dart's deterministic key format.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/sync/occurrence_key.dart';

void main() {
  test('occurrenceKeyFor is deterministic and encodes year/month/day', () {
    const HebrewDate date = HebrewDate(
      year: 5786,
      month: HebrewMonth.adarI,
      day: 14,
    );
    expect(occurrenceKeyFor(date), '5786-adarI-14');
    expect(occurrenceKeyFor(date), occurrenceKeyFor(date));
  });

  test('two different dates never produce the same key', () {
    const HebrewDate a = HebrewDate(
      year: 5786,
      month: HebrewMonth.tevet,
      day: 1,
    );
    const HebrewDate b = HebrewDate(
      year: 5786,
      month: HebrewMonth.tevet,
      day: 2,
    );
    expect(occurrenceKeyFor(a), isNot(occurrenceKeyFor(b)));
  });
}
