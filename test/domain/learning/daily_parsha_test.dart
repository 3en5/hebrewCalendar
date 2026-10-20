// M26: which aliyah of which parsha is studied on a day, and the files the
// app reads (site/learning/parsha/, built by tool/learning/build_parsha.py).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/learning/daily_parsha.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

({String parshaName, int aliyah, String key})? _on(
  int y,
  int m,
  int d, {
  bool inIsrael = true,
}) => dailyParshaFor(
  _engine,
  _engine.fromGregorian(DateTime(y, m, d)),
  inIsrael: inIsrael,
);

void main() {
  test('one aliyah a day, Sunday first, of the coming Shabbat', () {
    // Week of Lech Lecha 5787 (Shabbat 24 October 2026).
    expect(_on(2026, 10, 18)?.key, 'lech_lecha-1');
    expect(_on(2026, 10, 19)?.key, 'lech_lecha-2');
    expect(_on(2026, 10, 24)?.key, 'lech_lecha-7');
    expect(_on(2026, 10, 19)?.parshaName, 'לך לך');
    expect(_on(2026, 10, 25)?.key, 'vayera-1');
  });

  test('a festival Shabbat moves on to the next weekly reading', () {
    // Shabbat 26 September 2026 is Sukkot and 3 October Shemini Atzeret
    // (in Israel): the week studies Bereshit.
    expect(_on(2026, 9, 23)?.key, 'bereshis-4');
  });

  test('every day of two years has its file, in Israel and abroad', () {
    final Directory dir = Directory('site/learning/parsha');
    final Set<String> files = dir
        .listSync()
        .map((FileSystemEntity f) => f.uri.pathSegments.last)
        .toSet();
    HebrewDate day = _engine.fromGregorian(DateTime(2026, 9, 1));
    for (int i = 0; i < 730; i++) {
      for (final bool inIsrael in <bool>[true, false]) {
        final String? key = dailyParshaFor(
          _engine,
          day,
          inIsrael: inIsrael,
        )?.key;
        expect(key, isNotNull, reason: '$day');
        expect(files, contains('$key.json'), reason: '$day $inIsrael');
      }
      day = _engine.addDays(day, 1);
    }
  });

  test('a day file parses: verses, Onkelos, Rashi and section breaks', () {
    final DailyParsha? parsha = DailyParsha.fromJson(
      jsonDecode(
        File('site/learning/parsha/lech_lecha-2.json').readAsStringSync(),
      ),
    );
    expect(parsha, isNotNull);
    final ParshaPortion part = parsha!.parts.single;
    expect(part.book, 'בראשית');
    expect(part.verses, hasLength(11));
    expect(part.verses.first.chapter, 12);
    expect(part.verses.first.verse, 14);
    expect(part.verses.last.chapter, 13);
    expect(part.verses.last.verse, 4);
    expect(part.verses.first.mikra, contains('וַיְהִ֕י'));
    expect(part.verses.first.targum, startsWith('וַהֲוָה'));
    expect(part.verses.first.rashi.first.head, startsWith('ויהי כבוא'));
    expect(part.verses.any((ParshaVerse v) => v.rashi.isEmpty), isTrue);
  });

  test('a combined week without its own division has two parts', () {
    final DailyParsha? parsha = DailyParsha.fromJson(
      jsonDecode(
        File(
          'site/learning/parsha/nitzavim_vayeilech-1.json',
        ).readAsStringSync(),
      ),
    );
    expect(parsha?.parts, hasLength(2));
  });

  test('a broken file is rejected', () {
    expect(DailyParsha.fromJson(null), isNull);
    expect(DailyParsha.fromJson(<String, Object?>{'parts': 3}), isNull);
    expect(
      DailyParsha.fromJson(<String, Object?>{
        'parts': <Object?>[
          <String, Object?>{'book': 'בראשית', 'verses': <Object?>[]},
        ],
      }),
      isNull,
    );
  });
}
