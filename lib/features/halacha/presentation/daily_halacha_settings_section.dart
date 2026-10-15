import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/daily_halacha_providers.dart';
import 'daily_halacha_launcher.dart';

/// Settings: the daily halacha switch, with the share of users who keep it
/// on (owner request 2026-10-15), and a row that opens today's halacha.
class DailyHalachaSettingsSection extends ConsumerWidget {
  const DailyHalachaSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DailyHalachaSettings settings = ref.watch(
      dailyHalachaSettingsProvider,
    );
    final double? share = ref.watch(dailyHalachaShareProvider).value;
    // Owner request 2026-10-15: a section like "זמני היום", every row on
    // one line.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.only(bottom: spacingXs),
          child: Text(
            l10n.dailyHalachaTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SwitchListTile(
          key: const ValueKey<String>('daily-halacha-switch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.menu_book_outlined),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(l10n.dailyHalachaSettingTitle, maxLines: 1),
          ),
          subtitle: Text(
            share == null
                ? l10n.dailyHalachaSettingSubtitle
                : l10n.dailyHalachaSettingShare(
                    (share * 100).round().toString(),
                  ),
          ),
          value: settings.enabled,
          onChanged: (bool value) => unawaited(
            ref
                .read(dailyHalachaSettingsProvider.notifier)
                .setEnabled(value)
                .then((_) => ref.invalidate(dailyHalachaShareProvider)),
          ),
        ),
        ListTile(
          key: const ValueKey<String>('daily-halacha-open'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_stories_outlined),
          title: Text(l10n.dailyHalachaOpenToday),
          onTap: () => unawaited(openDailyHalacha(context, ref, auto: false)),
        ),
      ],
    );
  }
}
