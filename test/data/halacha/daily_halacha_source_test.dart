import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/halacha/daily_halacha_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _day(String title) => jsonEncode(<String, Object?>{
  'title': title,
  'sections': <Object?>[
    <String, Object?>{'siman': 1, 'seif': 1, 'text': 'טקסט'},
  ],
});

void main() {
  late List<String> requested;
  late DailyHalachaSource source;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_halacha_ksa_old-1': _day('ישן'),
    });
    requested = <String>[];
    source = DailyHalachaSource(
      baseUrl: 'https://example.test/ksa',
      client: MockClient((http.Request r) async {
        requested.add(r.url.path);
        if (r.url.path.endsWith('missing-1.json')) {
          return http.Response('not found', 404);
        }
        return http.Response.bytes(utf8.encode(_day(r.url.path)), 200);
      }),
    );
  });

  test('downloads once, then serves from the cache', () async {
    expect((await source.load('tishrei-24'))?.title, '/ksa/tishrei-24.json');
    expect((await source.load('tishrei-24'))?.title, '/ksa/tishrei-24.json');
    expect(requested, <String>['/ksa/tishrei-24.json']);
  });

  test('a missing day is null and is not cached', () async {
    expect(await source.load('missing-1'), isNull);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('daily_halacha_ksa_missing-1'), isFalse);
  });

  test('keeps exactly the coming days', () async {
    await source.keepOnly(<String>['tishrei-24', 'tishrei-25']);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((String k) => k.startsWith('daily_halacha_ksa_')),
      unorderedEquals(<String>[
        'daily_halacha_ksa_tishrei-24',
        'daily_halacha_ksa_tishrei-25',
      ]),
    );
  });
}
