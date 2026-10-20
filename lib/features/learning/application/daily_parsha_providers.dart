import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/learning/daily_parsha_source.dart';
import '../../../domain/halacha/daily_halacha.dart';
import '../../halacha/application/daily_halacha_providers.dart';

/// Downloads and caches the daily portions. Overridden in tests.
final Provider<DailyParshaSource> dailyParshaSourceProvider =
    Provider<DailyParshaSource>((Ref ref) {
      final DailyParshaSource source = DailyParshaSource();
      ref.onDispose(source.dispose);
      return source;
    });

/// How the weekly portion is studied (owner choice, sketch 68).
enum ParshaStudyMode {
  /// Each verse twice and Targum Onkelos.
  targum,

  /// Each verse twice, Onkelos and Rashi.
  targumRashi,

  /// Each verse once with Rashi, as in Chitas.
  chumashRashi;

  bool get twice => this != chumashRashi;
  bool get targumShown => this != chumashRashi;
  bool get rashiShown => this != targum;
}

const String _kEnabledKey = 'daily_parsha_enabled_v1';
const String _kModeKey = 'daily_parsha_mode_v1';
const String _kParshaDoneKey = 'daily_parsha_done_v1';
const String _kHalachaDoneKey = 'daily_halacha_done_v1';

class DailyParshaSettings {
  const DailyParshaSettings({
    this.enabled = false,
    this.mode = ParshaStudyMode.targum,
    this.parshaDoneDay,
    this.halachaDoneDay,
  });

  /// Off until chosen on the daily learning page.
  final bool enabled;
  final ParshaStudyMode mode;

  /// "yyyy-MM-dd" of the last day "סיימתי" / "שיננתי" was pressed, for the
  /// tabs' ✓ and the tab the window opens on.
  final String? parshaDoneDay;
  final String? halachaDoneDay;

  DailyParshaSettings copyWith({
    bool? enabled,
    ParshaStudyMode? mode,
    String? parshaDoneDay,
    String? halachaDoneDay,
  }) => DailyParshaSettings(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    parshaDoneDay: parshaDoneDay ?? this.parshaDoneDay,
    halachaDoneDay: halachaDoneDay ?? this.halachaDoneDay,
  );
}

/// The device's weekly portion choice (M26), kept like the daily halacha's.
class DailyParshaSettingsNotifier extends Notifier<DailyParshaSettings> {
  bool _loaded = false;

  @override
  DailyParshaSettings build() => const DailyParshaSettings();

  /// Completes once the stored choice is read.
  Future<void> get ready async {
    if (_loaded) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!_loaded) {
        final String? mode = prefs.getString(_kModeKey);
        state = DailyParshaSettings(
          enabled: prefs.getBool(_kEnabledKey) ?? false,
          mode:
              ParshaStudyMode.values
                  .where((ParshaStudyMode m) => m.name == mode)
                  .firstOrNull ??
              ParshaStudyMode.targum,
          parshaDoneDay: prefs.getString(_kParshaDoneKey),
          halachaDoneDay: prefs.getString(_kHalachaDoneKey),
        );
      }
    } catch (_) {
      // No platform channel: keep the defaults.
    }
    _loaded = true;
  }

  Future<void> setEnabled(bool enabled) async {
    await ready;
    final DailyHalachaMode halacha = ref
        .read(dailyHalachaSettingsProvider)
        .mode;
    final bool? before = learningVote(halacha: halacha, parsha: state.enabled);
    state = state.copyWith(enabled: enabled);
    await _save((SharedPreferences p) => p.setBool(_kEnabledKey, enabled));
    await recordLearningVote(
      ref,
      before,
      learningVote(halacha: halacha, parsha: enabled),
    );
  }

  Future<void> setMode(ParshaStudyMode mode) async {
    await ready;
    state = state.copyWith(mode: mode);
    await _save((SharedPreferences p) => p.setString(_kModeKey, mode.name));
  }

  /// "סיימתי" on [day]'s portion.
  Future<void> markParshaDone(DateTime day) async {
    final String key = dedicationDayKey(day);
    state = state.copyWith(parshaDoneDay: key);
    await _save((SharedPreferences p) => p.setString(_kParshaDoneKey, key));
  }

  /// "שיננתי" on [day]'s halacha.
  Future<void> markHalachaDone(DateTime day) async {
    final String key = dedicationDayKey(day);
    state = state.copyWith(halachaDoneDay: key);
    await _save((SharedPreferences p) => p.setString(_kHalachaDoneKey, key));
  }

  Future<void> _save(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // Best effort: the in-memory value still applies for this session.
    }
  }
}

final NotifierProvider<DailyParshaSettingsNotifier, DailyParshaSettings>
dailyParshaSettingsProvider =
    NotifierProvider<DailyParshaSettingsNotifier, DailyParshaSettings>(
      DailyParshaSettingsNotifier.new,
    );

/// This device's vote in the anonymous "how many learn" counters (owner
/// request 2026-10-20): it learns if any daily study is on, the halacha or
/// the weekly portion. Null until something was chosen (the halacha never
/// decided and the portion off).
bool? learningVote({required DailyHalachaMode halacha, required bool parsha}) {
  if (halacha == DailyHalachaMode.undecided && !parsha) {
    return null;
  }
  return halacha == DailyHalachaMode.on || parsha;
}

/// Moves the vote when a switch changed it from [before] to [after].
Future<void> recordLearningVote(Ref ref, bool? before, bool? after) async {
  if (after != null && after != before) {
    await ref.read(halachaCloudProvider).recordChoice(from: before, to: after);
  }
}

/// Whether anything was already finished on [todayKey] ("yyyy-MM-dd"), so
/// the day's "learned" counter counts each device once a day.
bool learnedOn(DailyParshaSettings progress, String todayKey) =>
    progress.halachaDoneDay == todayKey || progress.parshaDoneDay == todayKey;
