import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/app_version_provider.dart';
import '../application/google_sync_providers.dart';
import '../application/google_sync_settings_state.dart';
import '../application/google_sync_trigger_service.dart';
import 'widgets/backup_section.dart';
import 'widgets/google_sync_section.dart';

/// The app's settings screen, reached via the gear icon in
/// `CalendarShellScreen`'s app bar: Google Calendar sync (M5a), local-file
/// backup/restore (M7) and the installed app version. A `ListView` (not a
/// fixed `Column`) so it stays usable if more sections are added later or
/// the content doesn't fit a small screen — RULES.md §4.3 ("no hard-coded
/// height for a full screen").
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<GoogleSyncSettingsState> syncState = ref.watch(
      googleSyncStateProvider,
    );
    final GoogleSyncTriggerService service = ref.read(
      googleSyncTriggerServiceProvider,
    );
    final AsyncValue<String> version = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsScreenTitle)),
      body: ListView(
        padding: EdgeInsets.all(spacingMd),
        children: <Widget>[
          syncState.when(
            data: (GoogleSyncSettingsState state) => GoogleSyncSection(
              state: state,
              onEnabledChanged: (bool enabled) =>
                  unawaited(_onEnabledChanged(context, service, l10n, enabled)),
              onSyncNow: () => unawaited(service.syncNow()),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => GoogleSyncSection(
              state: const GoogleSyncSettingsState(),
              onEnabledChanged: (bool enabled) =>
                  unawaited(_onEnabledChanged(context, service, l10n, enabled)),
              onSyncNow: () => unawaited(service.syncNow()),
            ),
          ),
          SizedBox(height: spacingMd),
          const BackupSection(),
          SizedBox(height: spacingLg),
          Center(
            child: Text(
              l10n.settingsVersionLabel(version.value ?? ''),
              style: TextStyle(
                fontSize: captionRem,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onEnabledChanged(
    BuildContext context,
    GoogleSyncTriggerService service,
    AppLocalizations l10n,
    bool enabled,
  ) async {
    if (!enabled) {
      await service.disable();
      return;
    }
    final bool granted = await service.enable();
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsGoogleSyncAccessDeniedMessage)),
      );
    }
  }
}
