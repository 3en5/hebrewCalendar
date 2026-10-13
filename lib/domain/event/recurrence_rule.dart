import '../hebrew_date/hebrew_date.dart';

/// How an [Event] repeats. Expansion into concrete occurrences (and
/// exception handling) is M3 scope (ARCHITECTURE.md §9) — this type only
/// models the data shape so the `events` schema doesn't churn once
/// recurrence logic lands.
enum RecurrenceType {
  /// Does not repeat. The only value exercised before M3.
  none,

  /// Repeats every Hebrew year on the same Hebrew month/day.
  hebrewYearly,

  /// Repeats every Gregorian year on the same Gregorian month/day (M22,
  /// owner decision 2026-10-13). 29 February falls on 28 February in a
  /// non-leap year.
  gregorianYearly,

  /// Repeats every Hebrew month on the same day-of-month.
  hebrewMonthly,

  /// Repeats every Gregorian month on the same day-of-month (M22). A day
  /// the month lacks (31, or 29-31 in February) falls on its last day.
  gregorianMonthly,

  /// Repeats every week on the same weekday.
  weekly,

  /// Repeats every day.
  daily,
}

/// Which Adar a yearly event anchored in Adar recurs in during a leap year
/// (M15, owner decision 2026-10-12). In a non-leap year it is always the
/// single plain Adar.
enum LeapAdarPolicy {
  /// Adar I only (e.g. a yahrzeit, by Ashkenazi custom).
  adarI,

  /// Adar II only (birthdays, bar mitzvah, Sephardi yahrzeit custom).
  adarII,

  /// Both Adar I and Adar II.
  both,
}

/// Where a yearly event anchored on day 30 falls in a year whose month has
/// only 29 days (30 Cheshvan/Kislev, or 30 Adar I in a non-leap year).
enum ShortMonthPolicy {
  /// On the month's last day (the 29th).
  lastDay,

  /// On the 1st of the following month (the owner's chosen default).
  nextMonthFirst,
}

/// An immutable recurrence rule: a [type], an optional [until] date the
/// series stops at, and [exceptions] — specific occurrences skipped.
///
/// Mirrors the `recurrence` map in ARCHITECTURE.md §4. Only [none] is
/// exercised in M2a; the expansion algorithm for the other types is M3.
class RecurrenceRule {
  const RecurrenceRule({
    this.type = RecurrenceType.none,
    this.until,
    this.exceptions = const <HebrewDate>[],
    this.leapAdar,
    this.shortMonth,
  });

  final RecurrenceType type;
  final HebrewDate? until;
  final List<HebrewDate> exceptions;

  /// The user's leap-year Adar choice for a yearly event anchored in Adar;
  /// null = the default, see [effectiveLeapAdar].
  final LeapAdarPolicy? leapAdar;

  /// The user's choice for a yearly event anchored on day 30; null = the
  /// default, see [effectiveShortMonth].
  final ShortMonthPolicy? shortMonth;

  /// [leapAdar], or the default: an event anchored in Adar I stays in
  /// Adar I, any other Adar anchor goes to Adar II (owner decision).
  LeapAdarPolicy effectiveLeapAdar(HebrewMonth anchorMonth) =>
      leapAdar ??
      (anchorMonth == HebrewMonth.adarI
          ? LeapAdarPolicy.adarI
          : LeapAdarPolicy.adarII);

  /// [shortMonth], or the default: the 1st of the following month.
  ShortMonthPolicy get effectiveShortMonth =>
      shortMonth ?? ShortMonthPolicy.nextMonthFirst;

  /// Returns a copy with the given fields replaced. Pass [clearUntil] to
  /// explicitly set [until] back to null (a plain `until: null` argument is
  /// indistinguishable from "leave unchanged").
  RecurrenceRule copyWith({
    RecurrenceType? type,
    HebrewDate? until,
    bool clearUntil = false,
    List<HebrewDate>? exceptions,
    LeapAdarPolicy? leapAdar,
    ShortMonthPolicy? shortMonth,
  }) => RecurrenceRule(
    type: type ?? this.type,
    until: clearUntil ? null : (until ?? this.until),
    exceptions: exceptions ?? this.exceptions,
    leapAdar: leapAdar ?? this.leapAdar,
    shortMonth: shortMonth ?? this.shortMonth,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! RecurrenceRule ||
        other.type != type ||
        other.until != until ||
        other.leapAdar != leapAdar ||
        other.shortMonth != shortMonth ||
        other.exceptions.length != exceptions.length) {
      return false;
    }
    for (int i = 0; i < exceptions.length; i++) {
      if (other.exceptions[i] != exceptions[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    type,
    until,
    Object.hashAll(exceptions),
    leapAdar,
    shortMonth,
  );

  @override
  String toString() =>
      'RecurrenceRule(type: $type, until: $until, exceptions: $exceptions, '
      'leapAdar: $leapAdar, shortMonth: $shortMonth)';
}
