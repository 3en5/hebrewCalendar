import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';

const String _packageId = 'il.co.natanor.kalfapp.hebrewcalendar';

/// The app's Play Store page: the Play app first, the web page if the Play
/// app can't open it.
final Uri playStoreAppUri = Uri.parse('market://details?id=$_packageId');
final Uri playStoreWebUri = Uri.https(
  'play.google.com',
  '/store/apps/details',
  <String, String>{'id': _packageId},
);

/// "Rate the app" in settings (owner request 2026-10-15): opens the app's
/// page in Google Play, where the reviews are.
class RateAppTile extends StatelessWidget {
  const RateAppTile({super.key});

  Future<void> _open(BuildContext context) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final String failed = AppLocalizations.of(context).linkOpenFailed;
    for (final Uri uri in <Uri>[playStoreAppUri, playStoreWebUri]) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {
        // Try the next one.
      }
    }
    messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListTile(
      key: const ValueKey<String>('rate-app'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.star_outline),
      title: Text(l10n.settingsRateApp),
      subtitle: Text(l10n.settingsRateAppSubtitle),
      onTap: () => unawaited(_open(context)),
    );
  }
}
