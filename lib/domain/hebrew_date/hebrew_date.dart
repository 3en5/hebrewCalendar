/// Pure-Dart Hebrew calendar month, in chronological order for a Hebrew
/// year that begins at Tishrei (Rosh Hashana) and ends at Elul.
///
/// [adar] only exists in a non-leap year. [adarI] and [adarII] only exist
/// in a leap year — a leap year never has a plain [adar], and a non-leap
/// year never has [adarI]/[adarII]. Callers that need to know which of the
/// three applies for a given year should ask `HebrewDateEngine.isLeapYear`.
/// Declaration order matters: it is relied on for chronological ordering
/// in [HebrewDate.compareTo].
enum HebrewMonth {
  tishrei,
  cheshvan,
  kislev,
  tevet,
  shvat,
  adar,
  adarI,
  adarII,
  nisan,
  iyar,
  sivan,
  tammuz,
  av,
  elul,
}

/// An immutable Hebrew calendar date: a [year] (e.g. 5786), a [month] and a
/// [day] of month (1-30).
///
/// This value object only knows structural equality and chronological
/// ordering; it has no notion of which days/months are valid for a given
/// year (leap years, 29 vs 30 day months) — that calendrical knowledge
/// lives in `HebrewDateEngine`, which is the only place allowed to depend
/// on `kosher_dart` (RULES.md / ARCHITECTURE.md §3).
class HebrewDate implements Comparable<HebrewDate> {
  const HebrewDate({
    required this.year,
    required this.month,
    required this.day,
  });

  /// The Hebrew year, e.g. 5786.
  final int year;

  /// The Hebrew month.
  final HebrewMonth month;

  /// The day of the Hebrew month, 1-30.
  final int day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HebrewDate &&
          other.year == year &&
          other.month == month &&
          other.day == day);

  @override
  int get hashCode => Object.hash(year, month, day);

  /// Chronological comparison: year first, then [month] declaration order
  /// (see [HebrewMonth]), then day. Safe because a single Hebrew year only
  /// ever uses one of {adar} or {adarI, adarII}, never both.
  @override
  int compareTo(HebrewDate other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    if (month != other.month) {
      return month.index.compareTo(other.month.index);
    }
    return day.compareTo(other.day);
  }

  bool operator <(HebrewDate other) => compareTo(other) < 0;

  bool operator <=(HebrewDate other) => compareTo(other) <= 0;

  bool operator >(HebrewDate other) => compareTo(other) > 0;

  bool operator >=(HebrewDate other) => compareTo(other) >= 0;

  /// Returns a copy with the given fields replaced.
  HebrewDate copyWith({int? year, HebrewMonth? month, int? day}) => HebrewDate(
    year: year ?? this.year,
    month: month ?? this.month,
    day: day ?? this.day,
  );

  @override
  String toString() => 'HebrewDate(year: $year, month: $month, day: $day)';
}
