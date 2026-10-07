import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/app_version_provider.dart';

/// A simple About screen (task brief #5): app name, tagline, installed
/// version (reusing [appVersionProvider]), a modest developer credit, and a
/// link to Flutter's built-in open-source licenses page. Reached from a
/// list item on the settings screen — RULES.md §4.1 (no hard-coded font
/// sizes) and §4.4 (RTL via `start`/`end`) apply here like everywhere else.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<String> version = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutScreenTitle)),
      body: Center(
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacingSm),
              Text(
                l10n.aboutTagline,
                style: TextStyle(
                  fontSize: bodyRem,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacingLg),
              Text(
                l10n.settingsVersionLabel(version.value ?? ''),
                style: TextStyle(fontSize: bodySmallRem),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacingSm),
              // A modest, single-line credit — kalit's first (and only)
              // branding placement in the app, per the task brief.
              Text(
                l10n.aboutDeveloperCredit,
                style: TextStyle(
                  fontSize: captionRem,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacingXxl),
              OutlinedButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: l10n.appTitle,
                  applicationVersion: version.value,
                ),
                child: Text(l10n.aboutLicensesButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
