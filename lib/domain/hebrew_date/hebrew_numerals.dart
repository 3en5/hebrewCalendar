/// Formats numbers as Hebrew gematria (letter) numerals — the traditional
/// way Hebrew calendar days and years are displayed. User-facing numerals
/// in this app are always Hebrew letters, never Arabic digits (RULES.md
/// §3.4 — Hebrew is the primary presentation, not just a translation).
///
/// This is a small, self-contained algorithm with no dependency on
/// `kosher_dart` (unlike `hebrew_date_engine.dart`), so it can be unit
/// tested in complete isolation.
library;

const String _geresh = '׳';
const String _gershayim = '״';

const List<String> _hundreds = <String>[
  '',
  'ק',
  'ר',
  'ש',
  'ת',
  'תק',
  'תר',
  'תש',
  'תת',
  'תתק',
];

const List<String> _tens = <String>[
  '',
  'י',
  'כ',
  'ל',
  'מ',
  'נ',
  'ס',
  'ע',
  'פ',
  'צ',
];

const List<String> _ones = <String>[
  '',
  'א',
  'ב',
  'ג',
  'ד',
  'ה',
  'ו',
  'ז',
  'ח',
  'ט',
];

/// The single-letter gematria value for each thousand (used only for
/// round-thousand years, e.g. 5000 -> ה׳ אלפים).
const List<String> _thousands = <String>[
  '',
  'א',
  'ב',
  'ג',
  'ד',
  'ה',
  'ו',
  'ז',
  'ח',
  'ט',
];

/// Formats [number] (0-999) as Hebrew letters with geresh/gershayim
/// punctuation, e.g. 1 -> א׳, 20 -> כ׳, 21 -> כ״א, 786 -> תשפ״ו.
///
/// Special-cases 15 and 16 as ט״ו and ט״ז (never יה/יו, which would spell
/// out a Divine name) — the one irregularity in an otherwise mechanical
/// place-value system.
String formatHebrewNumeral(int number) {
  if (number < 0 || number > 999) {
    throw ArgumentError.value(number, 'number', 'must be between 0 and 999');
  }
  if (number == 0) {
    return '';
  }

  final int hundreds = number ~/ 100;
  final int remainder = number % 100;

  final StringBuffer buffer = StringBuffer(_hundreds[hundreds]);

  if (remainder == 15) {
    buffer.write('טו');
  } else if (remainder == 16) {
    buffer.write('טז');
  } else {
    final int tens = remainder ~/ 10;
    final int ones = remainder % 10;
    buffer.write(_tens[tens]);
    buffer.write(_ones[ones]);
  }

  return _withGereshim(buffer.toString());
}

/// Inserts a geresh after a single letter, or a gershayim before the last
/// letter of a multi-letter numeral — the standard Hebrew numeral
/// punctuation convention.
String _withGereshim(String letters) {
  if (letters.length <= 1) {
    return '$letters$_geresh';
  }
  final String allButLast = letters.substring(0, letters.length - 1);
  final String last = letters.substring(letters.length - 1);
  return '$allButLast$_gershayim$last';
}

/// Formats a Hebrew day-of-month (1-30) as gematria: 1 -> א׳, 15 -> ט״ו,
/// 16 -> ט״ז, 20 -> כ׳, 30 -> ל׳.
String hebrewDayNumeral(int day) {
  if (day < 1 || day > 30) {
    throw ArgumentError.value(day, 'day', 'must be between 1 and 30');
  }
  return formatHebrewNumeral(day);
}

/// Formats a full Hebrew year as gematria, dropping the millennium digit
/// per convention: 5786 -> תשפ״ו (not ה׳תשפ״ו). A round-thousand year
/// (e.g. 5000) falls back to the "X thousands" form, e.g. ה׳ אלפים.
String hebrewYearNumeral(int year) {
  if (year <= 0) {
    throw ArgumentError.value(year, 'year', 'must be positive');
  }
  final int shortYear = year % 1000;
  if (shortYear == 0) {
    final int thousands = year ~/ 1000;
    return '${_thousands[thousands]}$_geresh אלפים';
  }
  return formatHebrewNumeral(shortYear);
}
