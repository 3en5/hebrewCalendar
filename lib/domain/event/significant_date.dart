import '../hebrew_date/hebrew_date.dart';
import '../hebrew_date/hebrew_date_engine.dart';
import 'default_calendar_id.dart';
import 'event.dart';
import 'recurrence_expander.dart';
import 'recurrence_rule.dart';

/// M24 (owner decision 2026-10-14): the kinds of "significant date" the
/// dedicated tool turns into a yearly Hebrew-date event.
enum SignificantDateKind { birthday, yahrzeit, anniversary, other }

/// The Hebrew date of the Gregorian [day], given whether the moment was
/// after sunset (the Hebrew day starts at sunset, so after sunset is the
/// next Hebrew day). Unknown is treated as before sunset.
HebrewDate significantHebrewDate({
  required HebrewDateEngine engine,
  required DateTime day,
  required bool afterSunset,
}) {
  final HebrewDate before = engine.fromGregorian(day);
  return afterSunset ? engine.addDays(before, 1) : before;
}

/// The yearly Hebrew rule for [kind] anchored at [anchor]. A yahrzeit from
/// a plain (non-leap) Adar falls in Adar I in a leap year, by the common
/// custom; every other case keeps the app's default (an Adar I anchor stays
/// in Adar I, any other Adar goes to Adar II).
RecurrenceRule significantDateRule(
  SignificantDateKind kind,
  HebrewDate anchor,
) => RecurrenceRule(
  type: RecurrenceType.hebrewYearly,
  leapAdar:
      kind == SignificantDateKind.yahrzeit && anchor.month == HebrewMonth.adar
      ? LeapAdarPolicy.adarI
      : null,
);

/// The first occurrence of a yearly series anchored at [anchor] with
/// [rule] on or after [today], or null if none within two years.
HebrewDate? nextSignificantOccurrence({
  required HebrewDateEngine engine,
  required HebrewDate anchor,
  required RecurrenceRule rule,
  required HebrewDate today,
}) {
  final List<HebrewDate> dates = occurrencesInRange(
    base: anchor,
    rule: rule,
    from: today,
    to: engine.addDays(today, 800),
    engine: engine,
  );
  return dates.isEmpty ? null : dates.first;
}

/// The events the tool creates: a yearly Hebrew-date event titled
/// [hebrewTitle], plus, when [gregorianTitle] is given, a companion yearly
/// event on the Gregorian [day]. Both are all-day.
List<Event> buildSignificantDateEvents({
  required HebrewDateEngine engine,
  required SignificantDateKind kind,
  required DateTime day,
  required bool afterSunset,
  required String hebrewTitle,
  required String? gregorianTitle,
  required String ownerUid,
  required DateTime now,
  String? colorId,
}) {
  final HebrewDate anchor = significantHebrewDate(
    engine: engine,
    day: day,
    afterSunset: afterSunset,
  );
  Event event(String title, HebrewDate date, RecurrenceRule rule) => Event(
    id: '',
    ownerUid: ownerUid,
    calendarId: kDefaultCalendarId,
    title: title,
    hebrewDate: date,
    recurrence: rule,
    colorId: colorId,
    createdAt: now,
    updatedAt: now,
  );
  return <Event>[
    event(hebrewTitle, anchor, significantDateRule(kind, anchor)),
    if (gregorianTitle != null)
      event(
        gregorianTitle,
        // The Gregorian series is anchored on the civil day itself.
        engine.fromGregorian(day),
        const RecurrenceRule(type: RecurrenceType.gregorianYearly),
      ),
  ];
}
