import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Placeholder body for screens that are built in later stages.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).comingSoon,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
