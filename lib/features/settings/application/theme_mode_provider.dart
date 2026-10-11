import 'dart:async' show unawaited;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeModePrefsKey = 'app_theme_mode_v1';

/// The app's light/dark choice (the "מצב כהה" switch, as in PowerWatch).
/// Follows the system until the user flips the switch; then the choice is
/// kept per device in `SharedPreferences` (a display preference, not user
/// data, so it isn't synced).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    unawaited(_load());
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_kThemeModePrefsKey);
      for (final ThemeMode mode in ThemeMode.values) {
        if (mode.name == stored) {
          state = mode;
        }
      }
    } catch (_) {
      // No platform channel (e.g. under `flutter test`): follow the system.
    }
  }

  /// Switches dark mode on or off explicitly.
  Future<void> setDark(bool dark) async {
    final ThemeMode mode = dark ? ThemeMode.dark : ThemeMode.light;
    state = mode;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeModePrefsKey, mode.name);
    } catch (_) {
      // Best effort: the in-memory value still applies for this session.
    }
  }
}

final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
