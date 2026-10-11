// Tests for JewishDayInfo (M8): holidays, fasts, Rosh Chodesh, Israeli
// national days and the weekly parsha, in Israel and the diaspora.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/hebrew_date/jewish_day_info.dart';

const HebrewDateEngine _engine = HebrewDateEngine();
const JewishDayInfo _info = JewishDayInfo(_engine);

List<JewishDayLabel> _labels(
  int year,
  HebrewMonth month,
  int day, {
  bool inIsrael = true,
}) => _info.labelsFor(
  HebrewDate(year: year, month: month, day: day),
  inIsrael: inIsrael,
);

List<String> _names(
  int year,
  HebrewMonth month,
  int day, {
  bool inIsrael = true,
}) => _labels(
  year,
  month,
  day,
  inIsrael: inIsrael,
).map((JewishDayLabel l) => l.name).toList();

void main() {
  test('a plain weekday has no labels', () {
    // ג׳ חשוון תשפ״ז = Wednesday 14 Oct 2026.
    expect(_labels(5787, HebrewMonth.cheshvan, 3), isEmpty);
  });

  test('major holidays', () {
    expect(_names(5787, HebrewMonth.tishrei, 1), <String>['ראש השנה']);
    expect(_names(5787, HebrewMonth.tishrei, 10), <String>['יום כיפור']);
    expect(
      _labels(5787, HebrewMonth.tishrei, 10).single.kind,
      JewishDayKind.holiday,
    );
    expect(_names(5787, HebrewMonth.nisan, 15), <String>['פסח']);
    expect(_names(5787, HebrewMonth.nisan, 21), <String>['שביעי של פסח']);
    expect(_names(5787, HebrewMonth.sivan, 6), <String>['שבועות']);
  });

  test('fasts are labelled as fasts', () {
    final JewishDayLabel gedalya = _labels(5787, HebrewMonth.tishrei, 3).single;
    expect(gedalya.name, 'צום גדליה');
    expect(gedalya.kind, JewishDayKind.fast);
    expect(_names(5787, HebrewMonth.av, 9), <String>['תשעה באב']);
  });

  test('Rosh Chodesh on day 30 names the next month', () {
    expect(_names(5787, HebrewMonth.cheshvan, 30), <String>['ראש חודש כסלו']);
    expect(_names(5787, HebrewMonth.kislev, 1), <String>['ראש חודש כסלו']);
  });

  test('Chanukah counts candles and combines with Rosh Chodesh and parsha', () {
    // כ״ה כסלו תשפ״ז is Shabbat (5 Dec 2026): first candle + parshat Vayeshev.
    expect(_names(5787, HebrewMonth.kislev, 25), <String>[
      'חנוכה – נר א׳',
      'וישב',
    ]);
    expect(_names(5787, HebrewMonth.tevet, 1), <String>[
      'חנוכה – נר ז׳',
      'ראש חודש טבת',
    ]);
  });

  test('parsha on Shabbat, labelled last, without the "פרשת" prefix', () {
    final List<JewishDayLabel> noach = _labels(5787, HebrewMonth.cheshvan, 6);
    expect(
      noach.single,
      const JewishDayLabel(kind: JewishDayKind.parsha, name: 'נח'),
    );
  });

  test('Purim in a leap year falls in Adar II; Purim Katan in Adar I', () {
    expect(_engine.isLeapYear(5787), isTrue);
    expect(_names(5787, HebrewMonth.adarII, 14), <String>['פורים']);
    expect(_names(5787, HebrewMonth.adarI, 14), <String>['פורים קטן']);
  });

  test('Israeli national days', () {
    final JewishDayLabel atzmaut = _labels(5787, HebrewMonth.iyar, 5).single;
    expect(atzmaut.name, 'יום העצמאות');
    expect(atzmaut.kind, JewishDayKind.national);
    expect(_names(5787, HebrewMonth.iyar, 4), <String>['יום הזיכרון']);
  });

  test('Yom HaAtzmaut is moved earlier when 5 Iyar is a Friday', () {
    // 5782: ה׳ אייר = Friday 6 May 2022, so it moved to Thursday ד׳ אייר
    // (5 May 2022), and Yom HaZikaron to Wednesday ג׳ אייר.
    expect(_names(5782, HebrewMonth.iyar, 5), isEmpty);
    expect(_names(5782, HebrewMonth.iyar, 4), <String>['יום העצמאות']);
    expect(_names(5782, HebrewMonth.iyar, 3), <String>['יום הזיכרון']);
  });

  test('Israel vs diaspora: second Yom Tov day and Simchat Torah', () {
    expect(_names(5787, HebrewMonth.tishrei, 16), <String>['חול המועד סוכות']);
    expect(_names(5787, HebrewMonth.tishrei, 16, inIsrael: false), <String>[
      'סוכות',
    ]);
    expect(_names(5787, HebrewMonth.tishrei, 22), <String>[
      'שמיני עצרת ושמחת תורה',
    ]);
    expect(_names(5787, HebrewMonth.tishrei, 22, inIsrael: false), <String>[
      'שמיני עצרת',
    ]);
    expect(_names(5787, HebrewMonth.tishrei, 23, inIsrael: false), <String>[
      'שמחת תורה',
    ]);
  });

  test(
    'Israel vs diaspora: parsha schedule differs after the 8th of Pesach',
    () {
      // ז׳ סיוון תשפ״ז (Shabbat 12 Jun 2027): Naso in Israel, still the second
      // day of Shavuot (no parsha) in the diaspora.
      expect(_names(5787, HebrewMonth.sivan, 7), <String>['נשא']);
      expect(_names(5787, HebrewMonth.sivan, 7, inIsrael: false), <String>[
        'שבועות',
      ]);
    },
  );

  test('long names have a short form for the month cell', () {
    final JewishDayLabel chanukah = _labels(5787, HebrewMonth.kislev, 27).first;
    expect(chanukah.name, 'חנוכה – נר ג׳');
    expect(chanukah.shortName, 'חנוכה ג׳');
    final JewishDayLabel roshChodesh = _labels(
      5787,
      HebrewMonth.kislev,
      1,
    ).single;
    expect(roshChodesh.shortName, 'ראש חודש');
    // Short names default to the full name.
    expect(_labels(5787, HebrewMonth.tishrei, 1).single.shortName, 'ראש השנה');
  });
}
