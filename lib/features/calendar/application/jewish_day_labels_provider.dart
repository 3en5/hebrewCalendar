import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../domain/hebrew_date/jewish_day_info.dart';
import 'hebrew_date_engine_provider.dart';

const String _kInIsraelPrefsKey = 'calendar_in_israel_v1';

/// Whether holidays and the parsha follow the Israel calendar (default) or
/// the diaspora one (M8). A per-device preference in `SharedPreferences`:
/// it describes where the user is, not their data, so it isn't synced.
class InIsraelNotifier extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_load());
    return true;
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool? stored = prefs.getBool(_kInIsraelPrefsKey);
      if (stored != null) {
        state = stored;
      }
    } catch (_) {
      // No platform channel (e.g. under `flutter test`): keep the default.
    }
  }

  Future<void> set(bool inIsrael) async {
    state = inIsrael;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kInIsraelPrefsKey, inIsrael);
    } catch (_) {
      // Best effort: the in-memory value still applies for this session.
    }
  }
}

final NotifierProvider<InIsraelNotifier, bool> inIsraelProvider =
    NotifierProvider<InIsraelNotifier, bool>(InIsraelNotifier.new);

final Provider<JewishDayInfo> jewishDayInfoProvider = Provider<JewishDayInfo>(
  (Ref ref) => JewishDayInfo(ref.watch(hebrewDateEngineProvider)),
);

/// Holiday/parsha labels for every day of a Hebrew month, keyed by day of
/// month (days with no labels are absent). Pass the month's first day as
/// the key (`day: 1`) so all pages of the same month share one entry.
/// Computed locally — no network, no user data.
final ProviderFamily<Map<int, List<JewishDayLabel>>, HebrewDate>
monthDayLabelsProvider = Provider.autoDispose
    .family<Map<int, List<JewishDayLabel>>, HebrewDate>((
      Ref ref,
      HebrewDate month,
    ) {
      final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
      final JewishDayInfo info = ref.watch(jewishDayInfoProvider);
      final bool inIsrael = ref.watch(inIsraelProvider);
      final Map<int, List<JewishDayLabel>> labels =
          <int, List<JewishDayLabel>>{};
      final int days = engine.daysInMonth(month.year, month.month);
      for (int day = 1; day <= days; day++) {
        final List<JewishDayLabel> dayLabels = info.labelsFor(
          HebrewDate(year: month.year, month: month.month, day: day),
          inIsrael: inIsrael,
        );
        if (dayLabels.isNotEmpty) {
          labels[day] = dayLabels;
        }
      }
      return labels;
    });
