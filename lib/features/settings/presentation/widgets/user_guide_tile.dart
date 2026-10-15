import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';

/// The user guide on the app's site (owner request 2026-10-15).
final Uri userGuideUri = Uri.https(
  'hebrewcalendar-68363.web.app',
  '/guide.html',
);

/// Opens the user guide in the browser; a snack bar if it can't.
Future<void> openUserGuide(BuildContext context) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final String failed = AppLocalizations.of(context).linkOpenFailed;
  try {
    if (await launchUrl(userGuideUri, mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {
    // Reported below.
  }
  messenger?.showSnackBar(SnackBar(content: Text(failed)));
}

/// "User guide" in settings (and in the calendar's ⋮ menu, by
/// [openUserGuide]).
class UserGuideTile extends StatelessWidget {
  const UserGuideTile({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListTile(
      key: const ValueKey<String>('user-guide'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(l10n.settingsUserGuide),
      subtitle: Text(l10n.settingsUserGuideSubtitle),
      onTap: () => unawaited(openUserGuide(context)),
    );
  }
}
