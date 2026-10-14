// M24: the significant-date tool's domain logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/recurrence_expander.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/event/significant_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

List<Event> _build(
  SignificantDateKind kind, {
  bool afterSunset = false,
  bool alsoGregorian = false,
}) => buildSignificantDateEvents(
  engine: _engine,
  kind: kind,
  day: DateTime(1985, 3, 15),
  afterSunset: afterSunset,
  hebrewTitle: 'hebrew',
  gregorianTitle: alsoGregorian ? 'gregorian' : null,
  ownerUid: 'uid',
  now: DateTime(2026, 10, 14),
);

void main() {
  test('15 March 1985 is 22 Adar 5745; after sunset is the 23rd', () {
    expect(
      _build(SignificantDateKind.birthday).single.hebrewDate,
      const HebrewDate(year: 5745, month: HebrewMonth.adar, day: 22),
    );
    expect(
      _build(SignificantDateKind.birthday, afterSunset: true).single.hebrewDate,
      const HebrewDate(year: 5745, month: HebrewMonth.adar, day: 23),
    );
  });

  test('a yearly Hebrew all-day event; a birthday keeps the default Adar', () {
    final Event event = _build(SignificantDateKind.birthday).single;
    expect(event.allDay, isTrue);
    expect(event.title, 'hebrew');
    expect(event.recurrence.type, RecurrenceType.hebrewYearly);
    expect(event.recurrence.leapAdar, isNull);
  });

  test('a yahrzeit from plain Adar falls in Adar I in a leap year', () {
    final Event event = _build(SignificantDateKind.yahrzeit).single;
    expect(event.recurrence.leapAdar, LeapAdarPolicy.adarI);
    // 5787 is a leap year.
    final List<HebrewDate> dates = occurrencesInRange(
      base: event.hebrewDate,
      rule: event.recurrence,
      from: const HebrewDate(year: 5787, month: HebrewMonth.tishrei, day: 1),
      to: const HebrewDate(year: 5787, month: HebrewMonth.elul, day: 29),
      engine: _engine,
    );
    expect(dates, <HebrewDate>[
      const HebrewDate(year: 5787, month: HebrewMonth.adarI, day: 22),
    ]);
  });

  test('a yahrzeit from Adar II keeps the default', () {
    // 8 March 2008 was 1 Adar II 5768.
    final HebrewDate anchor = _engine.fromGregorian(DateTime(2008, 3, 8));
    expect(anchor.month, HebrewMonth.adarII);
    expect(
      significantDateRule(SignificantDateKind.yahrzeit, anchor).leapAdar,
      isNull,
    );
  });

  test('the Gregorian companion repeats on the civil day', () {
    final List<Event> events = _build(
      SignificantDateKind.birthday,
      afterSunset: true,
      alsoGregorian: true,
    );
    expect(events, hasLength(2));
    final Event gregorian = events[1];
    expect(gregorian.title, 'gregorian');
    expect(gregorian.recurrence.type, RecurrenceType.gregorianYearly);
    expect(_engine.toGregorian(gregorian.hebrewDate), DateTime(1985, 3, 15));
  });

  test('the next occurrence is on or after today', () {
    final Event event = _build(SignificantDateKind.birthday).single;
    final HebrewDate today = _engine.fromGregorian(DateTime(2026, 10, 14));
    expect(
      nextSignificantOccurrence(
        engine: _engine,
        anchor: event.hebrewDate,
        rule: event.recurrence,
        today: today,
      ),
      const HebrewDate(year: 5787, month: HebrewMonth.adarII, day: 22),
    );
  });
}
