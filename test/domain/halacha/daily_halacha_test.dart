import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/halacha/daily_halacha.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';

void main() {
  HebrewDate d(HebrewMonth m, int day) =>
      HebrewDate(year: 5787, month: m, day: day);

  test('the file key is month and day', () {
    expect(dailyHalachaKey(d(HebrewMonth.tishrei, 24)), 'tishrei-24');
    expect(dailyHalachaKey(d(HebrewMonth.iyar, 3)), 'iyar-3');
  });

  test('Adar I shares the plain Adar track; Adar II has its own', () {
    expect(dailyHalachaKey(d(HebrewMonth.adar, 5)), 'adar-5');
    expect(dailyHalachaKey(d(HebrewMonth.adarI, 5)), 'adar-5');
    expect(dailyHalachaKey(d(HebrewMonth.adarII, 5)), 'adarII-5');
  });

  test('days without a reading', () {
    expect(dailyHalachaKey(d(HebrewMonth.cheshvan, 30)), isNull);
    expect(dailyHalachaKey(d(HebrewMonth.adarI, 30)), isNull);
    expect(dailyHalachaKey(d(HebrewMonth.elul, 15)), isNull);
  });

  test('parses a day file and rejects a broken one', () {
    final DailyHalacha? h = DailyHalacha.fromJson(<String, Object?>{
      'title': 'סימן א׳',
      'sections': <Object?>[
        <String, Object?>{'siman': 1, 'seif': 1, 'text': 'שויתי'},
      ],
    });
    expect(h?.sections.single.text, 'שויתי');
    expect(DailyHalacha.fromJson(<String, Object?>{'title': 'x'}), isNull);
    expect(DailyHalacha.fromJson('nope'), isNull);
  });

  test('dedication day keys are yyyy-MM-dd', () {
    expect(dedicationDayKey(DateTime(2026, 3, 7)), '2026-03-07');
  });
}
