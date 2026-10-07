// Unit tests for the gematria formatter: docs/TESTING_AND_DEPLOY.md
// requires explicit coverage of 15/16 (never יה/יו) plus the year example
// from the M1 task brief (5786 -> תשפ״ו).

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_numerals.dart';

void main() {
  group('hebrewDayNumeral', () {
    test('1 -> א׳', () {
      expect(hebrewDayNumeral(1), 'א׳');
    });

    test('15 -> ט״ו (never יה)', () {
      expect(hebrewDayNumeral(15), 'ט״ו');
      expect(hebrewDayNumeral(15), isNot(contains('יה')));
    });

    test('16 -> ט״ז (never יו)', () {
      expect(hebrewDayNumeral(16), 'ט״ז');
      expect(hebrewDayNumeral(16), isNot(contains('יו')));
    });

    test('20 -> כ׳', () {
      expect(hebrewDayNumeral(20), 'כ׳');
    });

    test('30 -> ל׳', () {
      expect(hebrewDayNumeral(30), 'ל׳');
    });

    test('rejects days outside 1-30', () {
      expect(() => hebrewDayNumeral(0), throwsArgumentError);
      expect(() => hebrewDayNumeral(31), throwsArgumentError);
    });
  });

  group('hebrewYearNumeral', () {
    test('5786 -> תשפ״ו', () {
      expect(hebrewYearNumeral(5786), 'תשפ״ו');
    });

    test('5784 -> תשפ״ד', () {
      expect(hebrewYearNumeral(5784), 'תשפ״ד');
    });

    test('5771 -> תשע״א', () {
      expect(hebrewYearNumeral(5771), 'תשע״א');
    });

    test('round-thousand year falls back to the "thousands" form', () {
      expect(hebrewYearNumeral(5000), 'ה׳ אלפים');
    });

    test('rejects non-positive years', () {
      expect(() => hebrewYearNumeral(0), throwsArgumentError);
      expect(() => hebrewYearNumeral(-1), throwsArgumentError);
    });
  });

  group('formatHebrewNumeral', () {
    test('0 formats as an empty string', () {
      expect(formatHebrewNumeral(0), '');
    });

    test('100 -> ק׳ (single letter, geresh)', () {
      expect(formatHebrewNumeral(100), 'ק׳');
    });

    test('500 -> ת״ק (two letters, gershayim before last)', () {
      expect(formatHebrewNumeral(500), 'ת״ק');
    });

    test('rejects numbers outside 0-999', () {
      expect(() => formatHebrewNumeral(-1), throwsArgumentError);
      expect(() => formatHebrewNumeral(1000), throwsArgumentError);
    });
  });
}
