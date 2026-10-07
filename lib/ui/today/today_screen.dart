import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../calendar/hebrew_date_service.dart';
import '../../l10n/app_localizations.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final hebrewDate = const HebrewDateService().formatDate(
      now,
      hebrew: locale.languageCode == 'he',
    );
    final gregorianDate = DateFormat.yMMMMEEEEd(locale.toLanguageTag())
        .format(now);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navToday)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(l10n.todayHebrewDate, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(
                    hebrewDate,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Divider(height: 32),
                  Text(
                    l10n.todayGregorianDate,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gregorianDate,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
