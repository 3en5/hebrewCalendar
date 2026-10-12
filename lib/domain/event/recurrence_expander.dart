/// Pure expansion of a [RecurrenceRule] into concrete [EventOccurrence]s.
///
/// Per ARCHITECTURE.md §4's "materialize nothing, expand at runtime"
/// principle, recurring events are stored as a single [Event] document; this
/// file is the only place that turns the rule back into actual dates. Two
/// non-obvious policies (see ARCHITECTURE.md §4 "מדיניות חזרתיות" for the
/// user-facing summary) apply to [RecurrenceType.hebrewYearly] and
/// [RecurrenceType.hebrewMonthly]:
///
/// 1. **Adar mapping policy** ([RecurrenceType.hebrewYearly] only): a leap
///    Hebrew year has both Adar I and Adar II where a non-leap year has a
///    single plain Adar. A yearly event anchored in any Adar recurs in plain
///    Adar in non-leap years, and in leap years per
///    [RecurrenceRule.effectiveLeapAdar] (M15): Adar I, Adar II, or both.
///    The default is Adar II, except for an anchor in Adar I, which stays
///    in Adar I.
/// 2. **Day-30 policy**: Cheshvan and Kislev alternate between 29 and 30
///    days, and Adar I (30 days) maps to a 29-day Adar in non-leap years.
///    A [RecurrenceType.hebrewYearly] event anchored on day 30 follows
///    [RecurrenceRule.effectiveShortMonth] (M15) in a year where the month
///    is short: the 1st of the next month (default) or the 29th.
///    A [RecurrenceType.hebrewMonthly] event anchored on day 30 always
///    falls on the month's last day (29) in a short month, so it fires
///    exactly once per Hebrew month.
///
/// [RecurrenceType.weekly] and [RecurrenceType.daily] have no such
/// Hebrew-calendar ambiguity: they step by a fixed number of Gregorian days
/// from the anchor date (computed via [HebrewDateEngine] round-trips, to
/// avoid any accumulated drift from repeated Hebrew-side arithmetic), then
/// convert each step back to a [HebrewDate].
///
/// All recurrence types share three rules: no occurrence before
/// [Event.hebrewDate] (the anchor/base date itself is the first occurrence),
/// [RecurrenceRule.until] is an inclusive upper bound, and any date in
/// [RecurrenceRule.exceptions] is skipped.
library;

import '../hebrew_date/hebrew_date.dart';
import '../hebrew_date/hebrew_date_engine.dart';
import 'event.dart';
import 'event_occurrence.dart';
import 'recurrence_rule.dart';

/// Returns every [HebrewDate] on which [event] occurs within the given
/// Hebrew [year]/[month] (both boundaries inclusive — an entire Hebrew
/// month), wrapped as [EventOccurrence]s pairing the date with [event].
///
/// This is the primary entry point repositories use to answer "what occurs
/// in this displayed month" — it handles every [RecurrenceType] uniformly,
/// including [RecurrenceType.none] (which yields at most the single
/// occurrence on [Event.hebrewDate] itself, if that falls in the month).
///
/// A thin wrapper over [occurrencesForEventInRange] for a single-month
/// window; see that function for the general case (M3b — week/day/agenda
/// views need an arbitrary date range, not just a month).
List<EventOccurrence> occurrencesInHebrewMonth({
  required Event event,
  required int year,
  required HebrewMonth month,
  required HebrewDateEngine engine,
}) {
  final HebrewDate from = HebrewDate(year: year, month: month, day: 1);
  final HebrewDate to = HebrewDate(
    year: year,
    month: month,
    day: engine.daysInMonth(year, month),
  );
  return occurrencesForEventInRange(
    event: event,
    from: from,
    to: to,
    engine: engine,
  );
}

/// Returns every [EventOccurrence] of [event] within `[from, to]` (both
/// boundaries inclusive) — the same expansion [occurrencesInHebrewMonth]
/// uses for a single Hebrew month, generalized to an arbitrary Hebrew-date
/// range. Shared by every [EventRepository] implementation's
/// `watchOccurrencesInRange` (M3b) so the "expand a rule into occurrences,
/// then wrap each as an [EventOccurrence]" logic lives in exactly one place.
List<EventOccurrence> occurrencesForEventInRange({
  required Event event,
  required HebrewDate from,
  required HebrewDate to,
  required HebrewDateEngine engine,
}) {
  final List<HebrewDate> dates = occurrencesInRange(
    base: event.hebrewDate,
    rule: event.recurrence,
    from: from,
    to: to,
    engine: engine,
  );
  return <EventOccurrence>[
    for (final HebrewDate date in dates)
      EventOccurrence(event: event, occurrenceDate: date),
  ];
}

/// Returns every [HebrewDate] on which a series anchored at [base] with
/// recurrence [rule] falls within `[from, to]` (both boundaries inclusive).
///
/// Reused directly by [occurrencesInHebrewMonth] for a single-month window,
/// and intended for the wider rolling window Google Calendar sync will need
/// in M5 (a multi-month/year range) — nothing here is month-shaped, it
/// operates on an arbitrary Hebrew date range.
List<HebrewDate> occurrencesInRange({
  required HebrewDate base,
  required RecurrenceRule rule,
  required HebrewDate from,
  required HebrewDate to,
  required HebrewDateEngine engine,
}) {
  if (to < from) {
    return const <HebrewDate>[];
  }
  switch (rule.type) {
    case RecurrenceType.none:
      return _noneOccurrence(base, rule, from, to);
    case RecurrenceType.hebrewYearly:
      return _yearlyOccurrences(base, rule, from, to, engine);
    case RecurrenceType.hebrewMonthly:
      return _monthlyOccurrences(base, rule, from, to, engine);
    case RecurrenceType.weekly:
      return _stepOccurrences(base, rule, from, to, engine, 7);
    case RecurrenceType.daily:
      return _stepOccurrences(base, rule, from, to, engine, 1);
  }
}

List<HebrewDate> _noneOccurrence(
  HebrewDate base,
  RecurrenceRule rule,
  HebrewDate from,
  HebrewDate to,
) {
  if (base >= from && base <= to && !rule.exceptions.contains(base)) {
    return <HebrewDate>[base];
  }
  return const <HebrewDate>[];
}

List<HebrewDate> _yearlyOccurrences(
  HebrewDate base,
  RecurrenceRule rule,
  HebrewDate from,
  HebrewDate to,
  HebrewDateEngine engine,
) {
  final List<HebrewDate> results = <HebrewDate>[];
  for (int year = from.year; year <= to.year; year++) {
    for (final HebrewMonth month in _yearlyEffectiveMonths(
      base.month,
      rule,
      year,
      engine,
    )) {
      final HebrewDate occurrence = _yearlyDay(base, rule, year, month, engine);
      if (_isEligible(occurrence, base, rule, from, to)) {
        results.add(occurrence);
      }
    }
  }
  return results;
}

/// Implements the Adar mapping policy documented on this library: the
/// month(s) a yearly event anchored in [baseMonth] falls in during [year].
List<HebrewMonth> _yearlyEffectiveMonths(
  HebrewMonth baseMonth,
  RecurrenceRule rule,
  int year,
  HebrewDateEngine engine,
) {
  if (baseMonth != HebrewMonth.adar &&
      baseMonth != HebrewMonth.adarI &&
      baseMonth != HebrewMonth.adarII) {
    return <HebrewMonth>[baseMonth];
  }
  if (!engine.isLeapYear(year)) {
    return const <HebrewMonth>[HebrewMonth.adar];
  }
  switch (rule.effectiveLeapAdar(baseMonth)) {
    case LeapAdarPolicy.adarI:
      return const <HebrewMonth>[HebrewMonth.adarI];
    case LeapAdarPolicy.adarII:
      return const <HebrewMonth>[HebrewMonth.adarII];
    case LeapAdarPolicy.both:
      return const <HebrewMonth>[HebrewMonth.adarI, HebrewMonth.adarII];
  }
}

/// The day-30 policy for a yearly occurrence in [month] of [year].
HebrewDate _yearlyDay(
  HebrewDate base,
  RecurrenceRule rule,
  int year,
  HebrewMonth month,
  HebrewDateEngine engine,
) {
  final int lastDay = engine.daysInMonth(year, month);
  if (base.day <= lastDay) {
    return HebrewDate(year: year, month: month, day: base.day);
  }
  switch (rule.effectiveShortMonth) {
    case ShortMonthPolicy.lastDay:
      return HebrewDate(year: year, month: month, day: lastDay);
    case ShortMonthPolicy.nextMonthFirst:
      return engine.nextMonth(HebrewDate(year: year, month: month, day: 1));
  }
}

List<HebrewDate> _monthlyOccurrences(
  HebrewDate base,
  RecurrenceRule rule,
  HebrewDate from,
  HebrewDate to,
  HebrewDateEngine engine,
) {
  final List<HebrewDate> results = <HebrewDate>[];
  HebrewDate cursor = HebrewDate(year: from.year, month: from.month, day: 1);
  final HebrewDate lastMonth = HebrewDate(
    year: to.year,
    month: to.month,
    day: 1,
  );
  while (cursor <= lastMonth) {
    final int lastDay = engine.daysInMonth(cursor.year, cursor.month);
    final int day = base.day > lastDay ? lastDay : base.day;
    final HebrewDate occurrence = HebrewDate(
      year: cursor.year,
      month: cursor.month,
      day: day,
    );
    if (_isEligible(occurrence, base, rule, from, to)) {
      results.add(occurrence);
    }
    cursor = engine.nextMonth(cursor);
  }
  return results;
}

List<HebrewDate> _stepOccurrences(
  HebrewDate base,
  RecurrenceRule rule,
  HebrewDate from,
  HebrewDate to,
  HebrewDateEngine engine,
  int stepDays,
) {
  final DateTime baseUtc = _toUtcDate(base, engine);
  final DateTime fromUtc = _toUtcDate(from, engine);
  final DateTime toUtc = _toUtcDate(to, engine);
  if (toUtc.isBefore(baseUtc)) {
    return const <HebrewDate>[];
  }

  // Jump directly to the first step at or after `from` instead of iterating
  // one step at a time from the (possibly years-distant) base date.
  final int diffDays = fromUtc.difference(baseUtc).inDays;
  final int firstStep = diffDays <= 0
      ? 0
      : (diffDays + stepDays - 1) ~/ stepDays;

  final List<HebrewDate> results = <HebrewDate>[];
  DateTime candidateUtc = baseUtc.add(Duration(days: firstStep * stepDays));
  while (!candidateUtc.isAfter(toUtc)) {
    if (!candidateUtc.isBefore(fromUtc)) {
      final HebrewDate occurrence = engine.fromGregorian(candidateUtc);
      if (_isEligible(occurrence, base, rule, from, to)) {
        results.add(occurrence);
      }
    }
    candidateUtc = candidateUtc.add(Duration(days: stepDays));
  }
  return results;
}

/// Shared "is this candidate date a real, un-skipped occurrence" check: not
/// before [base], within `[from, to]`, at or before [RecurrenceRule.until]
/// (when set), and not listed in [RecurrenceRule.exceptions].
bool _isEligible(
  HebrewDate occurrence,
  HebrewDate base,
  RecurrenceRule rule,
  HebrewDate from,
  HebrewDate to,
) {
  if (occurrence < base || occurrence < from || occurrence > to) {
    return false;
  }
  final HebrewDate? until = rule.until;
  if (until != null && occurrence > until) {
    return false;
  }
  return !rule.exceptions.contains(occurrence);
}

/// Converts [date] to a UTC-normalized [DateTime] (midnight UTC on the
/// corresponding Gregorian calendar day) via [engine]. Arithmetic on
/// Gregorian dates for [RecurrenceType.weekly]/[RecurrenceType.daily] is
/// done entirely in UTC rather than on the local [DateTime]s
/// [HebrewDateEngine.toGregorian] returns, because local-time [DateTime]
/// subtraction/`Duration` arithmetic can be off by a day around a
/// daylight-saving transition; UTC has no such transitions. Only the
/// calendar (year/month/day) fields ever matter here — [HebrewDateEngine]
/// never looks at time-of-day or the UTC/local flag — so normalizing to UTC
/// for the arithmetic and reading fields back off it is always safe.
DateTime _toUtcDate(HebrewDate date, HebrewDateEngine engine) {
  final DateTime local = engine.toGregorian(date);
  return DateTime.utc(local.year, local.month, local.day);
}
