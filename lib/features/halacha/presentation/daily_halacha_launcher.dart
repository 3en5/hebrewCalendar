import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/halacha/daily_halacha_source.dart';
import '../../../data/halacha/halacha_cloud.dart';
import '../../../domain/halacha/daily_halacha.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/application/hebrew_date_engine_provider.dart';
import '../../calendar/application/jewish_day_labels_provider.dart';
import '../../learning/application/daily_parsha_providers.dart';
import '../../learning/presentation/daily_learning_launcher.dart';
import '../application/daily_halacha_providers.dart';
import 'daily_halacha_dialog.dart';

/// How many days ahead the readings are kept (owner request 2026-10-15:
/// a few days' margin, never the whole book).
const int kDailyHalachaDaysAhead = 7;

/// Opens today's halacha. [auto] is the once-a-day opening (marks the day
/// shown and, the first time, asks whether to keep showing it); from
/// settings it just opens, and says so when nothing is available.
Future<void> openDailyHalacha(
  BuildContext context,
  WidgetRef ref, {
  required bool auto,
}) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final AppLocalizations l10n = AppLocalizations.of(context);
  final DateTime now = DateTime.now();
  final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
  final HebrewDate today = engine.fromGregorian(now);
  final String? key = dailyHalachaKey(today);
  final DailyHalacha? halacha = key == null
      ? null
      : await ref.read(dailyHalachaSourceProvider).load(key);
  if (halacha == null) {
    if (!auto) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.dailyHalachaUnavailable)),
      );
    }
    return;
  }
  final HalachaCloud cloud = ref.read(halachaCloudProvider);
  final String? dedication = await cloud.dedicationFor(now);
  final DailyHalachaSettingsNotifier settings = ref.read(
    dailyHalachaSettingsProvider.notifier,
  );
  final bool firstTime =
      auto &&
      ref.read(dailyHalachaSettingsProvider).mode == DailyHalachaMode.undecided;
  if (auto) {
    await settings.markShown(now);
  }
  if (!context.mounted) {
    return;
  }
  final DailyHalachaResult result = await showDailyHalachaDialog(
    context,
    halacha: halacha,
    dedication: dedication,
    dateLabel:
        '${hebrewDayNumeral(today.day)} ${engine.monthName(today.month)}',
    firstTime: firstTime,
  );
  switch (result) {
    case DailyHalachaResult.learned:
      // One "learned" a day per device, whichever study it was (M26).
      if (!learnedOn(
        ref.read(dailyParshaSettingsProvider),
        dedicationDayKey(now),
      )) {
        unawaited(cloud.recordLearned(now));
      }
      unawaited(
        ref.read(dailyParshaSettingsProvider.notifier).markHalachaDone(now),
      );
      if (firstTime) {
        await settings.setEnabled(true);
      }
    case DailyHalachaResult.stopShowing:
      await settings.setEnabled(false);
    case DailyHalachaResult.dismissed:
      break;
  }
}

/// Wraps the calendar home: on the day's first visit (app start or back
/// from the background), opens the daily learning (the halacha and, when
/// on, the weekly portion, M26), and keeps the coming week's readings
/// downloaded.
class DailyHalachaLauncher extends ConsumerStatefulWidget {
  const DailyHalachaLauncher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DailyHalachaLauncher> createState() =>
      _DailyHalachaLauncherState();
}

class _DailyHalachaLauncherState extends ConsumerState<DailyHalachaLauncher>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (_busy || !mounted) {
      return;
    }
    _busy = true;
    try {
      await ref.read(dailyHalachaSettingsProvider.notifier).ready;
      await ref.read(dailyParshaSettingsProvider.notifier).ready;
      final DateTime now = DateTime.now();
      final DailyHalachaSettings settings = ref.read(
        dailyHalachaSettingsProvider,
      );
      final bool parshaOn = ref.read(dailyParshaSettingsProvider).enabled;
      if ((settings.enabled || parshaOn) &&
          settings.lastShownDay != dedicationDayKey(now) &&
          mounted) {
        await openDailyLearning(context, ref, auto: true);
      }
      if (mounted) {
        unawaited(_prefetch(now));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _prefetch(DateTime now) async {
    final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
    final DailyHalachaSource source = ref.read(dailyHalachaSourceProvider);
    final HebrewDate today = engine.fromGregorian(now);
    final bool parshaOn = ref.read(dailyParshaSettingsProvider).enabled;
    final bool inIsrael = ref.read(inIsraelProvider);
    await source.keepOnly(<String>[
      for (int i = 0; i < kDailyHalachaDaysAhead; i++)
        ?dailyHalachaKey(engine.addDays(today, i)),
    ]);
    if (parshaOn) {
      await ref
          .read(dailyParshaSourceProvider)
          .keepOnly(
            dailyParshaKeysAhead(
              engine,
              today,
              inIsrael: inIsrael,
              days: kDailyHalachaDaysAhead,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
