// M21: the times-of-day preferences, kept per device, and the Shabbat time
// shown in the month view.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/zmanim/zmanim.dart';
import 'package:hebrew_calendar/features/zmanim/application/zmanim_settings.dart';
import 'package:hebrew_calendar/features/zmanim/presentation/shabbat_times.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults: Jerusalem, its 40 minutes, 8.5 degrees', () {
    const ZmanimSettings s = ZmanimSettings();
    expect(s.enabled, isTrue);
    expect(s.city.id, 'jerusalem');
    expect(s.effectiveCandleLightingMinutes, 40);
    expect(s.havdalah, HavdalahMethod.degrees8Point5);
    expect(s.location.latitude, s.city.latitude);
  });

  test('choices are stored and restored on the next start', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer first = ProviderContainer();
    first.read(zmanimSettingsProvider);
    await Future<void>.delayed(Duration.zero);
    final ZmanimSettingsNotifier n = first.read(
      zmanimSettingsProvider.notifier,
    );
    await n.setCity('haifa');
    await n.setCandleLightingMinutes(18);
    await n.setHavdalah(HavdalahMethod.minutes72);
    first.dispose();

    final ProviderContainer second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(zmanimSettingsProvider);
    await Future<void>.delayed(Duration.zero);
    final ZmanimSettings s = second.read(zmanimSettingsProvider);
    expect(s.cityId, 'haifa');
    expect(s.effectiveCandleLightingMinutes, 18);
    expect(s.havdalah, HavdalahMethod.minutes72);
  });

  test('picking a city returns candle lighting to its custom', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(zmanimSettingsProvider);
    await Future<void>.delayed(Duration.zero);
    final ZmanimSettingsNotifier n = c.read(zmanimSettingsProvider.notifier);
    await n.setCandleLightingMinutes(18);
    await n.setCity('jerusalem');
    expect(c.read(zmanimSettingsProvider).candleLightingMinutes, isNull);
    expect(c.read(zmanimSettingsProvider).effectiveCandleLightingMinutes, 40);
  });

  test('the phone position is used only when chosen and known', () {
    const ZmanimSettings s = ZmanimSettings(
      deviceLatitude: 31.9,
      deviceLongitude: 35.0,
    );
    expect(s.location.latitude, s.city.latitude);
    expect(s.copyWith(useDevicePosition: true).location.latitude, 31.9);
  });

  test('Shabbat time: candles on Friday, havdalah on Saturday, else none', () {
    const ZmanimSettings s = ZmanimSettings();
    expect(shabbatTimeFor(s, DateTime(2026, 10, 23))!.isCandleLighting, isTrue);
    expect(
      shabbatTimeFor(s, DateTime(2026, 10, 24))!.isCandleLighting,
      isFalse,
    );
    expect(shabbatTimeFor(s, DateTime(2026, 10, 22)), isNull);
    expect(
      shabbatTimeFor(s.copyWith(enabled: false), DateTime(2026, 10, 23)),
      isNull,
    );
  });
}
