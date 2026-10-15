import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/halacha/daily_halacha_source.dart';
import '../../../data/halacha/halacha_cloud.dart';
import '../../../domain/halacha/daily_halacha.dart';
import '../../auth/application/auth_providers.dart';

/// Downloads and caches the daily files. Overridden in tests.
final Provider<DailyHalachaSource> dailyHalachaSourceProvider =
    Provider<DailyHalachaSource>((Ref ref) {
      final DailyHalachaSource source = DailyHalachaSource();
      ref.onDispose(source.dispose);
      return source;
    });

/// Dedications and counters: Firestore once signed in, none otherwise
/// (demo mode). Overridden in tests.
final Provider<HalachaCloud> halachaCloudProvider = Provider<HalachaCloud>((
  Ref ref,
) {
  if (ref.watch(currentUserProvider) == null) {
    return const OfflineHalachaCloud();
  }
  return FirestoreHalachaCloud();
});

/// Whether the daily halacha opens on the day's first visit.
enum DailyHalachaMode {
  /// Never chosen: it opens, and asks "keep showing / don't show again".
  undecided,
  on,
  off,
}

const String _kModeKey = 'daily_halacha_mode_v1';
const String _kLastShownKey = 'daily_halacha_last_shown_v1';

class DailyHalachaSettings {
  const DailyHalachaSettings({required this.mode, this.lastShownDay});

  final DailyHalachaMode mode;

  /// "yyyy-MM-dd" of the last day it opened by itself.
  final String? lastShownDay;

  bool get enabled => mode != DailyHalachaMode.off;
}

/// The device's daily halacha choice (owner decision 2026-10-15: on at
/// first, with "keep showing" / "don't show again" on the first visit).
class DailyHalachaSettingsNotifier extends Notifier<DailyHalachaSettings> {
  bool _loaded = false;

  @override
  DailyHalachaSettings build() {
    unawaited(_load());
    return const DailyHalachaSettings(mode: DailyHalachaMode.undecided);
  }

  /// Completes once the stored choice is read.
  Future<void> get ready async {
    if (!_loaded) {
      await _load();
    }
  }

  Future<void> _load() async {
    if (_loaded) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_loaded) {
        return;
      }
      final String? stored = prefs.getString(_kModeKey);
      state = DailyHalachaSettings(
        mode:
            DailyHalachaMode.values
                .where((DailyHalachaMode m) => m.name == stored)
                .firstOrNull ??
            DailyHalachaMode.undecided,
        lastShownDay: prefs.getString(_kLastShownKey),
      );
    } catch (_) {
      // No platform channel: keep the defaults.
    }
    _loaded = true;
  }

  /// Turns it on or off, from the dialog or settings, and moves this
  /// device's vote in the anonymous counters.
  Future<void> setEnabled(bool enabled) async {
    final bool? before = switch (state.mode) {
      DailyHalachaMode.undecided => null,
      DailyHalachaMode.on => true,
      DailyHalachaMode.off => false,
    };
    _loaded = true;
    state = DailyHalachaSettings(
      mode: enabled ? DailyHalachaMode.on : DailyHalachaMode.off,
      lastShownDay: state.lastShownDay,
    );
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kModeKey, state.mode.name);
    } catch (_) {
      // Best effort.
    }
    await ref
        .read(halachaCloudProvider)
        .recordChoice(from: before, to: enabled);
  }

  /// Marks [day] as shown, so it opens by itself once a day.
  Future<void> markShown(DateTime day) async {
    _loaded = true;
    state = DailyHalachaSettings(
      mode: state.mode,
      lastShownDay: dedicationDayKey(day),
    );
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastShownKey, state.lastShownDay!);
    } catch (_) {
      // Best effort.
    }
  }
}

final NotifierProvider<DailyHalachaSettingsNotifier, DailyHalachaSettings>
dailyHalachaSettingsProvider =
    NotifierProvider<DailyHalachaSettingsNotifier, DailyHalachaSettings>(
      DailyHalachaSettingsNotifier.new,
    );

/// The share of users who keep it on, for the settings subtitle.
final FutureProvider<double?> dailyHalachaShareProvider =
    FutureProvider<double?>(
      (Ref ref) => ref.watch(halachaCloudProvider).enabledShare(),
    );
