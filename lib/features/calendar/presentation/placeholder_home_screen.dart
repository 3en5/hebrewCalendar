import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../l10n/app_localizations.dart';

/// Temporary M0 home screen: confirms the app shell, theme and
/// localization infrastructure are wired up correctly before any real
/// feature is implemented.
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.placeholderMilestoneStatus,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: spacingMd),
              Text(
                l10n.placeholderScreenSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
