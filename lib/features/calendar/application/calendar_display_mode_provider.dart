import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which calendar the views are laid out by (M23, owner request
/// 2026-10-13). Only the presentation changes: events, holidays and times
/// of day are the same in both, and the focused day is kept when switching.
enum CalendarDisplayMode {
  /// Hebrew months, the Hebrew date first (the default).
  hebrew,

  /// Gregorian months, the Gregorian date first and the Hebrew date small.
  gregorian,
}

const String _kDisplayModePrefsKey = 'calendar_display_mode_v1';

/// The stored choice, read once before the first frame by
/// [preloadCalendarDisplayMode] so the app opens straight in the last
/// display, without a flash of the Hebrew grid. Null until preloaded.
CalendarDisplayMode? _preloaded;

/// Reads the last display choice before `runApp` (main.dart). Bounded and
/// best effort: on any failure the provider's own async load still runs.
Future<void> preloadCalendarDisplayMode() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 2));
    final String? stored = prefs.getString(_kDisplayModePrefsKey);
    _preloaded = CalendarDisplayMode.values
        .where((CalendarDisplayMode m) => m.name == stored)
        .firstOrNull;
  } catch (_) {
    // Keep null: the notifier falls back to its async load.
  }
}

/// The display choice, kept per device (a view preference, not user data)
/// and restored on every start: the app always opens in the last display.
class CalendarDisplayModeNotifier extends Notifier<CalendarDisplayMode> {
  bool _changed = false;

  @override
  CalendarDisplayMode build() {
    final CalendarDisplayMode? preloaded = _preloaded;
    if (preloaded != null) {
      return preloaded;
    }
    unawaited(_load());
    return CalendarDisplayMode.hebrew;
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_kDisplayModePrefsKey);
      // A choice made before the load finished wins.
      if (_changed) {
        return;
      }
      for (final CalendarDisplayMode mode in CalendarDisplayMode.values) {
        if (mode.name == stored) {
          state = mode;
        }
      }
    } catch (_) {
      // No platform channel (e.g. under `flutter test`): keep the default.
    }
  }

  Future<void> set(CalendarDisplayMode mode) async {
    _changed = true;
    _preloaded = mode;
    state = mode;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDisplayModePrefsKey, mode.name);
    } catch (_) {
      // Best effort: the in-memory value still applies for this session.
    }
  }
}

final NotifierProvider<CalendarDisplayModeNotifier, CalendarDisplayMode>
calendarDisplayModeProvider =
    NotifierProvider<CalendarDisplayModeNotifier, CalendarDisplayMode>(
      CalendarDisplayModeNotifier.new,
    );
