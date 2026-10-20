import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/halacha/halacha_cloud.dart';
import '../../../domain/halacha/daily_halacha.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../domain/learning/daily_parsha.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/application/hebrew_date_engine_provider.dart';
import '../../calendar/application/jewish_day_labels_provider.dart';
import '../../halacha/application/daily_halacha_providers.dart';
import '../../halacha/presentation/daily_halacha_launcher.dart';
import '../application/daily_parsha_providers.dart';
import 'daily_learning_dialog.dart';

/// [now]'s portion in the chosen mode, from the cache or downloaded; null
/// when there is none or it can't be reached.
Future<ParshaOfDay?> loadParshaOfDay(WidgetRef ref, DateTime now) async {
  final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
  final ({String parshaName, int aliyah, String key})? day = dailyParshaFor(
    engine,
    engine.fromGregorian(now),
    inIsrael: ref.read(inIsraelProvider),
  );
  if (day == null) {
    return null;
  }
  final DailyParsha? parsha = await ref
      .read(dailyParshaSourceProvider)
      .load(day.key);
  if (parsha == null) {
    return null;
  }
  return ParshaOfDay(
    parsha: parsha,
    parshaName: day.parshaName,
    aliyah: day.aliyah,
    mode: ref.read(dailyParshaSettingsProvider).mode,
  );
}

/// The coming week's portion files, for the prefetch.
List<String> dailyParshaKeysAhead(
  HebrewDateEngine engine,
  HebrewDate today, {
  required bool inIsrael,
  required int days,
}) => <String>[
  for (int i = 0; i < days; i++)
    ?dailyParshaFor(engine, engine.addDays(today, i), inIsrael: inIsrael)?.key,
];

/// M26: opens the morning window. Without the weekly portion it is the
/// daily halacha exactly as before ([openDailyHalacha]); with it, the
/// window has a tab for each study that is on. [auto] is the once-a-day
/// opening; [only] opens a single study, from the daily learning page.
Future<void> openDailyLearning(
  BuildContext context,
  WidgetRef ref, {
  required bool auto,
  LearningTrack? only,
}) async {
  final DailyParshaSettingsNotifier parshaNotifier = ref.read(
    dailyParshaSettingsProvider.notifier,
  );
  await parshaNotifier.ready;
  if (!context.mounted) {
    return;
  }
  final bool parshaOn = ref.read(dailyParshaSettingsProvider).enabled;
  if (only == LearningTrack.halacha || (only == null && !parshaOn)) {
    return openDailyHalacha(context, ref, auto: auto);
  }
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final AppLocalizations l10n = AppLocalizations.of(context);
  final DateTime now = DateTime.now();
  final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
  final HebrewDate today = engine.fromGregorian(now);
  final DailyHalachaSettings halachaSettings = ref.read(
    dailyHalachaSettingsProvider,
  );
  final String? halachaKey = dailyHalachaKey(today);
  final DailyHalacha? halacha =
      only == null && halachaSettings.enabled && halachaKey != null
      ? await ref.read(dailyHalachaSourceProvider).load(halachaKey)
      : null;
  final ParshaOfDay? parsha = await loadParshaOfDay(ref, now);
  if (!context.mounted) {
    return;
  }
  if (parsha == null) {
    if (only == null && halacha != null) {
      // The portion can't be reached: the halacha alone, as before.
      return openDailyHalacha(context, ref, auto: auto);
    }
    if (!auto) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.parshaUnavailable)));
    }
    return;
  }
  final HalachaCloud cloud = ref.read(halachaCloudProvider);
  final String? dedication = await cloud.dedicationFor(now);
  if (auto) {
    await ref.read(dailyHalachaSettingsProvider.notifier).markShown(now);
  }
  if (!context.mounted) {
    return;
  }
  final String todayKey = dedicationDayKey(now);
  final DailyParshaSettings progress = ref.read(dailyParshaSettingsProvider);
  await showDailyLearningDialog(
    context,
    halacha: halacha,
    parsha: parsha,
    dedication: dedication,
    dateLabel:
        '${hebrewDayNumeral(today.day)} ${engine.monthName(today.month)}',
    done: <LearningTrack>{
      if (progress.halachaDoneDay == todayKey) LearningTrack.halacha,
      if (progress.parshaDoneDay == todayKey) LearningTrack.parsha,
    },
    onDone: (LearningTrack track) async {
      // One "learned" a day per device, whichever study it was.
      if (!learnedOn(ref.read(dailyParshaSettingsProvider), todayKey)) {
        unawaited(cloud.recordLearned(now));
      }
      switch (track) {
        case LearningTrack.halacha:
          await parshaNotifier.markHalachaDone(now);
          if (ref.read(dailyHalachaSettingsProvider).mode ==
              DailyHalachaMode.undecided) {
            await ref
                .read(dailyHalachaSettingsProvider.notifier)
                .setEnabled(true);
          }
        case LearningTrack.parsha:
          await parshaNotifier.markParshaDone(now);
      }
    },
  );
}
