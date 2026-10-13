// M21: the times of day computed with kosher_dart. Times are compared in UTC
// so the test does not depend on the machine's time zone.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/zmanim/zmanim.dart';
import 'package:hebrew_calendar/domain/zmanim/zmanim_location.dart';

void main() {
  final ZmanimLocation jerusalem = zmanimCityById('jerusalem');
  // Friday 23 Oct 2026 (12 Cheshvan 5787) and the next day.
  final DateTime friday = DateTime(2026, 10, 23);
  final DateTime saturday = DateTime(2026, 10, 24);

  ZmanimDay at(
    DateTime day, {
    HavdalahMethod h = HavdalahMethod.degrees8Point5,
  }) => computeZmanim(
    day: day,
    location: jerusalem,
    candleLightingMinutes: jerusalem.candleLightingMinutes,
    havdalah: h,
  );

  test('Jerusalem sunset and midday match the published times', () {
    final ZmanimDay day = at(friday);
    final DateTime sunset = day.times[Zman.sunset]!.toUtc();
    final DateTime chatzos = day.times[Zman.chatzos]!.toUtc();
    // 18:02 and 12:23 Israel summer time (UTC+3).
    expect(
      sunset.difference(DateTime.utc(2026, 10, 23, 15, 2)).inMinutes.abs(),
      lessThanOrEqualTo(2),
    );
    expect(
      chatzos.difference(DateTime.utc(2026, 10, 23, 9, 23)).inMinutes.abs(),
      lessThanOrEqualTo(2),
    );
  });

  test('every time is computed and they come in order', () {
    final ZmanimDay day = at(friday);
    final List<DateTime> times = <DateTime>[
      for (final Zman zman in Zman.values) day.times[zman]!,
    ];
    for (int i = 1; i < times.length; i++) {
      expect(
        times[i].isAfter(times[i - 1]),
        isTrue,
        reason: Zman.values[i].name,
      );
    }
  });

  test('candle lighting only on Friday, the city custom before sunset', () {
    final ZmanimDay fri = at(friday);
    final DateTime candles = fri.candleLighting!;
    final int before = fri.times[Zman.sunset]!.difference(candles).inMinutes;
    // Candle lighting is from sea-level sunset; Jerusalem's elevated sunset
    // is a few minutes later.
    expect(before, inInclusiveRange(39, 45));
    expect(fri.havdalah, isNull);
    expect(at(DateTime(2026, 10, 22)).candleLighting, isNull);
  });

  test('end of Shabbat only on Saturday, by the chosen method', () {
    final ZmanimDay degrees = at(saturday);
    final ZmanimDay rt = at(saturday, h: HavdalahMethod.minutes72);
    expect(degrees.candleLighting, isNull);
    expect(degrees.havdalah!.isAfter(degrees.times[Zman.sunset]!), isTrue);
    expect(rt.havdalah!.isAfter(degrees.havdalah!), isTrue);
    expect(at(friday).havdalah, isNull);
  });
}
