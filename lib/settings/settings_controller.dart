import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Overridden in `main()` with an instance loaded before the first frame.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  static const _kLanguage = 'settings.language';
  static const _kTheme = 'settings.theme';
  static const _kInIsrael = 'settings.inIsrael';
  static const _kZmanimOpinion = 'settings.zmanimOpinion';
  static const _kCandleLighting = 'settings.candleLightingMinutes';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      languageCode: prefs.getString(_kLanguage),
      themeMode: _byName(
        ThemeMode.values,
        prefs.getString(_kTheme),
        ThemeMode.system,
      ),
      inIsrael: prefs.getBool(_kInIsrael) ?? true,
      zmanimOpinion: _byName(
        ZmanimOpinion.values,
        prefs.getString(_kZmanimOpinion),
        ZmanimOpinion.gra,
      ),
      candleLightingMinutes:
          prefs.getInt(_kCandleLighting) ??
          AppSettings.defaultCandleLightingMinutes,
    );
  }

  Future<void> setLanguage(String? code) async {
    state = state.copyWith(languageCode: () => code);
    if (code == null) {
      await _prefs.remove(_kLanguage);
    } else {
      await _prefs.setString(_kLanguage, code);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_kTheme, mode.name);
  }

  Future<void> setInIsrael(bool value) async {
    state = state.copyWith(inIsrael: value);
    await _prefs.setBool(_kInIsrael, value);
  }

  Future<void> setZmanimOpinion(ZmanimOpinion value) async {
    state = state.copyWith(zmanimOpinion: value);
    await _prefs.setString(_kZmanimOpinion, value.name);
  }

  Future<void> setCandleLightingMinutes(int value) async {
    state = state.copyWith(candleLightingMinutes: value);
    await _prefs.setInt(_kCandleLighting, value);
  }

  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
