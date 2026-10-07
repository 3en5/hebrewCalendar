import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrewcalendar/settings/app_settings.dart';
import 'package:hebrewcalendar/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults', () async {
    final c = await _container();
    expect(c.read(settingsProvider), const AppSettings());
  });

  test('changes are persisted and reloaded', () async {
    final c = await _container();
    final controller = c.read(settingsProvider.notifier);
    await controller.setLanguage('en');
    await controller.setThemeMode(ThemeMode.dark);
    await controller.setInIsrael(false);
    await controller.setZmanimOpinion(ZmanimOpinion.mga);
    await controller.setCandleLightingMinutes(40);

    final prefs = c.read(sharedPreferencesProvider);
    final reloaded = await _container({
      for (final k in prefs.getKeys()) k: prefs.get(k)!,
    });
    expect(
      reloaded.read(settingsProvider),
      const AppSettings(
        languageCode: 'en',
        themeMode: ThemeMode.dark,
        inIsrael: false,
        zmanimOpinion: ZmanimOpinion.mga,
        candleLightingMinutes: 40,
      ),
    );
  });

  test('language can be reset to device default', () async {
    final c = await _container({'settings.language': 'en'});
    await c.read(settingsProvider.notifier).setLanguage(null);
    expect(c.read(settingsProvider).languageCode, isNull);
    expect(
      c.read(sharedPreferencesProvider).getString('settings.language'),
      isNull,
    );
  });

  test('unknown stored enum values fall back to defaults', () async {
    final c = await _container({
      'settings.theme': 'purple',
      'settings.zmanimOpinion': 'nope',
    });
    expect(c.read(settingsProvider).themeMode, ThemeMode.system);
    expect(c.read(settingsProvider).zmanimOpinion, ZmanimOpinion.gra);
  });
}
