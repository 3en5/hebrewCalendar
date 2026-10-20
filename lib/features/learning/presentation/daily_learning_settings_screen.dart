import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/application/jewish_day_labels_provider.dart';
import '../../halacha/application/daily_halacha_providers.dart';
import '../../halacha/presentation/daily_halacha_settings_section.dart';
import '../application/daily_parsha_providers.dart';
import 'daily_learning_dialog.dart';
import 'daily_learning_launcher.dart';

/// Settings row "לימוד יומי ›" (M26, sketch 68), with what is on.
class DailyLearningTile extends ConsumerWidget {
  const DailyLearningTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool halacha = ref.watch(dailyHalachaSettingsProvider).enabled;
    final DailyParshaSettings parsha = ref.watch(dailyParshaSettingsProvider);
    final double? share = ref.watch(dailyHalachaShareProvider).value;
    unawaited(ref.read(dailyParshaSettingsProvider.notifier).ready);
    final List<String> on = <String>[
      if (halacha) l10n.dailyHalachaTitle,
      if (parsha.enabled)
        l10n.dailyLearningSummaryParsha(_modeShort(l10n, parsha.mode)),
    ];
    return ListTile(
      key: const ValueKey<String>('daily-learning-tile'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(l10n.dailyLearningTitle),
      // Owner request 2026-10-20: the share of learners under the row.
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(on.isEmpty ? l10n.dailyLearningOff : on.join(', ')),
          if (share != null)
            Text(
              l10n.dailyHalachaSettingShare((share * 100).round().toString()),
              key: const ValueKey<String>('daily-learning-tile-share'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const DailyLearningSettingsScreen(),
          ),
        ),
      ),
    );
  }
}

String _modeShort(AppLocalizations l10n, ParshaStudyMode mode) =>
    switch (mode) {
      ParshaStudyMode.targum => l10n.parshaTargumTag,
      ParshaStudyMode.targumRashi =>
        '${l10n.parshaTargumTag}, ${l10n.parshaRashiTag}',
      ParshaStudyMode.chumashRashi => l10n.parshaModeChumashRashi,
    };

/// The daily learning page (M26, sketch 68): the daily halacha as before,
/// and the weekly portion with its three study modes.
class DailyLearningSettingsScreen extends ConsumerWidget {
  const DailyLearningSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final DailyParshaSettings parsha = ref.watch(dailyParshaSettingsProvider);
    final DailyParshaSettingsNotifier notifier = ref.read(
      dailyParshaSettingsProvider.notifier,
    );
    final bool inIsrael = ref.watch(inIsraelProvider);
    final double? share = ref.watch(dailyHalachaShareProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dailyLearningTitle)),
      body: ListView(
        padding: EdgeInsets.all(
          spacingMd,
        ).copyWith(bottom: spacingMd + MediaQuery.paddingOf(context).bottom),
        children: <Widget>[
          Text(
            l10n.dailyLearningIntro,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (share != null) ...<Widget>[
            SizedBox(height: spacingXs),
            Text(
              l10n.dailyHalachaSettingShare((share * 100).round().toString()),
              key: const ValueKey<String>('daily-learning-share'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
          SizedBox(height: spacingMd),
          const DailyHalachaSettingsSection(),
          const Divider(),
          SizedBox(height: spacingSm),
          Text(
            l10n.parshaSection,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SwitchListTile(
            key: const ValueKey<String>('daily-parsha-switch'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.auto_stories_outlined),
            title: Text(l10n.parshaSwitch),
            subtitle: Text(l10n.parshaSwitchHint),
            value: parsha.enabled,
            onChanged: (bool v) => unawaited(
              notifier
                  .setEnabled(v)
                  .then((_) => ref.invalidate(dailyHalachaShareProvider)),
            ),
          ),
          for (final ParshaStudyMode mode in ParshaStudyMode.values)
            RadioListTile<ParshaStudyMode>(
              key: ValueKey<String>('daily-parsha-mode-${mode.name}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: mode,
              groupValue: parsha.mode,
              // Off: the modes are shown but can't be picked.
              onChanged: parsha.enabled
                  ? (ParshaStudyMode? m) {
                      if (m != null) {
                        unawaited(notifier.setMode(m));
                      }
                    }
                  : null,
              title: Text(_modeTitle(l10n, mode)),
              subtitle: Text(_modeHint(l10n, mode)),
            ),
          Text(
            inIsrael ? l10n.parshaCalendarIsrael : l10n.parshaCalendarDiaspora,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          ListTile(
            key: const ValueKey<String>('daily-parsha-open'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chrome_reader_mode_outlined),
            title: Text(l10n.parshaOpenToday),
            onTap: () => unawaited(
              openDailyLearning(
                context,
                ref,
                auto: false,
                only: LearningTrack.parsha,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _modeTitle(AppLocalizations l10n, ParshaStudyMode mode) =>
    switch (mode) {
      ParshaStudyMode.targum => l10n.parshaModeTargum,
      ParshaStudyMode.targumRashi => l10n.parshaModeTargumRashi,
      ParshaStudyMode.chumashRashi => l10n.parshaModeChumashRashi,
    };

String _modeHint(AppLocalizations l10n, ParshaStudyMode mode) => switch (mode) {
  ParshaStudyMode.targum => l10n.parshaModeTargumHint,
  ParshaStudyMode.targumRashi => l10n.parshaModeTargumRashiHint,
  ParshaStudyMode.chumashRashi => l10n.parshaModeChumashRashiHint,
};
