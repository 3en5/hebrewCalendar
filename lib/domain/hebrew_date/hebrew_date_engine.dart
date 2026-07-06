import 'package:kosher_dart/kosher_dart.dart' as kosher;

import 'hebrew_date.dart';

/// Wraps `kosher_dart` behind our own interface.
///
/// This is the ONLY file in the project allowed to import `kosher_dart`
/// (ARCHITECTURE.md §3 / the M1 task brief). Everything else — domain,
/// data and features — talks to [HebrewDate] and [HebrewMonth] only, never
/// to `kosher_dart` types directly.
///
/// See docs/LESSONS.md for two `kosher_dart` API quirks this class works
/// around: `JewishDate.getGregorianMonth()` is documented as 0-based (like
/// `java.util.Calendar`) but actually returns a 1-based month in this port,
/// and `JewishDate.initDate`'s `minute` parameter is silently ignored due
/// to a `_minute = _minute` self-assignment bug in the package.
class HebrewDateEngine {
  const HebrewDateEngine();

  /// Converts [date] to its Gregorian equivalent.
  DateTime toGregorian(HebrewDate date) {
    final kosher.JewishDate jewishDate = _toJewishDate(date);
    return DateTime(
      jewishDate.getGregorianYear(),
      jewishDate.getGregorianMonth(),
      jewishDate.getGregorianDayOfMonth(),
    );
  }

  /// Converts a Gregorian [dateTime] (time-of-day is ignored) to its Hebrew
  /// equivalent.
  HebrewDate fromGregorian(DateTime dateTime) {
    final kosher.JewishDate jewishDate = kosher.JewishDate.fromDateTime(
      DateTime(dateTime.year, dateTime.month, dateTime.day),
    );
    return HebrewDate(
      year: jewishDate.getJewishYear(),
      month: _monthFromKosher(
        jewishDate.getJewishMonth(),
        jewishDate.isJewishLeapYear(),
      ),
      day: jewishDate.getJewishDayOfMonth(),
    );
  }

  /// Whether [year] is a Hebrew leap year (has Adar I and Adar II).
  bool isLeapYear(int year) {
    final kosher.JewishDate jewishDate = kosher.JewishDate();
    jewishDate.setJewishYear(year);
    return jewishDate.isJewishLeapYear();
  }

  /// The months of [year] in chronological order (Tishrei..Elul): 12
  /// entries in a regular year, 13 in a leap year (Adar split into I/II).
  List<HebrewMonth> monthsInYear(int year) {
    final bool leap = isLeapYear(year);
    return <HebrewMonth>[
      HebrewMonth.tishrei,
      HebrewMonth.cheshvan,
      HebrewMonth.kislev,
      HebrewMonth.tevet,
      HebrewMonth.shvat,
      if (leap) HebrewMonth.adarI else HebrewMonth.adar,
      if (leap) HebrewMonth.adarII,
      HebrewMonth.nisan,
      HebrewMonth.iyar,
      HebrewMonth.sivan,
      HebrewMonth.tammuz,
      HebrewMonth.av,
      HebrewMonth.elul,
    ];
  }

  /// The number of days in [month] of [year] (29 or 30).
  int daysInMonth(int year, HebrewMonth month) {
    final kosher.JewishDate jewishDate = kosher.JewishDate.initDate(
      jewishYear: year,
      jewishMonth: _monthToKosher(month, year),
      jewishDayOfMonth: 1,
    );
    return jewishDate.getDaysInJewishMonth();
  }

  /// The Hebrew display name for [month], e.g. תשרי, אדר א׳.
  String monthName(HebrewMonth month) => _monthNames[month]!;

  /// The Sunday-first weekday index of [date]: 0 = Sunday, ..., 6 = Saturday.
  int weekdayIndex(HebrewDate date) => toGregorian(date).weekday % 7;

  /// Returns the [HebrewDate] that is [amount] Hebrew months after (or, if
  /// negative, before) [date], preserving the day of month when possible
  /// and clamping it to the target month's length otherwise (e.g. the 30th
  /// of a 30-day month rolled into a 29-day month becomes the 29th).
  HebrewDate addMonths(HebrewDate date, int amount) {
    if (amount == 0) {
      return date;
    }

    List<HebrewMonth> sequence = monthsInYear(date.year);
    final int index = sequence.indexOf(date.month);
    int year = date.year;
    int newIndex = index + amount;

    while (newIndex >= sequence.length) {
      newIndex -= sequence.length;
      year++;
      sequence = monthsInYear(year);
    }
    while (newIndex < 0) {
      year--;
      sequence = monthsInYear(year);
      newIndex += sequence.length;
    }

    final HebrewMonth newMonth = sequence[newIndex];
    final int maxDay = daysInMonth(year, newMonth);
    return HebrewDate(
      year: year,
      month: newMonth,
      day: date.day > maxDay ? maxDay : date.day,
    );
  }

  /// The Hebrew month following [date]'s month (same day-of-month, clamped).
  HebrewDate nextMonth(HebrewDate date) => addMonths(date, 1);

  /// The Hebrew month preceding [date]'s month (same day-of-month, clamped).
  HebrewDate previousMonth(HebrewDate date) => addMonths(date, -1);

  kosher.JewishDate _toJewishDate(HebrewDate date) {
    return kosher.JewishDate.initDate(
      jewishYear: date.year,
      jewishMonth: _monthToKosher(date.month, date.year),
      jewishDayOfMonth: date.day,
    );
  }

  static const Map<HebrewMonth, String> _monthNames = <HebrewMonth, String>{
    HebrewMonth.tishrei: 'תשרי',
    HebrewMonth.cheshvan: 'חשוון',
    HebrewMonth.kislev: 'כסלו',
    HebrewMonth.tevet: 'טבת',
    HebrewMonth.shvat: 'שבט',
    HebrewMonth.adar: 'אדר',
    HebrewMonth.adarI: 'אדר א׳',
    HebrewMonth.adarII: 'אדר ב׳',
    HebrewMonth.nisan: 'ניסן',
    HebrewMonth.iyar: 'אייר',
    HebrewMonth.sivan: 'סיוון',
    HebrewMonth.tammuz: 'תמוז',
    HebrewMonth.av: 'אב',
    HebrewMonth.elul: 'אלול',
  };

  int _monthToKosher(HebrewMonth month, int year) {
    final bool leap = isLeapYear(year);
    switch (month) {
      case HebrewMonth.nisan:
        return kosher.JewishDate.NISSAN;
      case HebrewMonth.iyar:
        return kosher.JewishDate.IYAR;
      case HebrewMonth.sivan:
        return kosher.JewishDate.SIVAN;
      case HebrewMonth.tammuz:
        return kosher.JewishDate.TAMMUZ;
      case HebrewMonth.av:
        return kosher.JewishDate.AV;
      case HebrewMonth.elul:
        return kosher.JewishDate.ELUL;
      case HebrewMonth.tishrei:
        return kosher.JewishDate.TISHREI;
      case HebrewMonth.cheshvan:
        return kosher.JewishDate.CHESHVAN;
      case HebrewMonth.kislev:
        return kosher.JewishDate.KISLEV;
      case HebrewMonth.tevet:
        return kosher.JewishDate.TEVES;
      case HebrewMonth.shvat:
        return kosher.JewishDate.SHEVAT;
      case HebrewMonth.adar:
        if (leap) {
          throw ArgumentError(
            'Year $year is a leap year; use adarI/adarII, not adar.',
          );
        }
        return kosher.JewishDate.ADAR;
      case HebrewMonth.adarI:
        if (!leap) {
          throw ArgumentError(
            'Year $year is not a leap year; use adar, not adarI.',
          );
        }
        return kosher.JewishDate.ADAR;
      case HebrewMonth.adarII:
        if (!leap) {
          throw ArgumentError(
            'Year $year is not a leap year; use adar, not adarII.',
          );
        }
        return kosher.JewishDate.ADAR_II;
    }
  }

  HebrewMonth _monthFromKosher(int kosherMonth, bool leap) {
    switch (kosherMonth) {
      case 1:
        return HebrewMonth.nisan;
      case 2:
        return HebrewMonth.iyar;
      case 3:
        return HebrewMonth.sivan;
      case 4:
        return HebrewMonth.tammuz;
      case 5:
        return HebrewMonth.av;
      case 6:
        return HebrewMonth.elul;
      case 7:
        return HebrewMonth.tishrei;
      case 8:
        return HebrewMonth.cheshvan;
      case 9:
        return HebrewMonth.kislev;
      case 10:
        return HebrewMonth.tevet;
      case 11:
        return HebrewMonth.shvat;
      case 12:
        return leap ? HebrewMonth.adarI : HebrewMonth.adar;
      case 13:
        return HebrewMonth.adarII;
      default:
        throw ArgumentError('Unknown kosher_dart month: $kosherMonth');
    }
  }
}
