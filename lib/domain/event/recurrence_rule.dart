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

  /// Repeats every Hebrew month on the same day-of-month.
  hebrewMonthly,

  /// Repeats every week on the same weekday.
  weekly,

  /// Repeats every day.
  daily,
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
  });

  final RecurrenceType type;
  final HebrewDate? until;
  final List<HebrewDate> exceptions;

  /// Returns a copy with the given fields replaced. Pass [clearUntil] to
  /// explicitly set [until] back to null (a plain `until: null` argument is
  /// indistinguishable from "leave unchanged").
  RecurrenceRule copyWith({
    RecurrenceType? type,
    HebrewDate? until,
    bool clearUntil = false,
    List<HebrewDate>? exceptions,
  }) => RecurrenceRule(
    type: type ?? this.type,
    until: clearUntil ? null : (until ?? this.until),
    exceptions: exceptions ?? this.exceptions,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! RecurrenceRule ||
        other.type != type ||
        other.until != until ||
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
  int get hashCode => Object.hash(type, until, Object.hashAll(exceptions));

  @override
  String toString() =>
      'RecurrenceRule(type: $type, until: $until, exceptions: $exceptions)';
}
