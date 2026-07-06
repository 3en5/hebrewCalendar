import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/google_sync_providers.dart';
import '../application/google_sync_settings_state.dart';
import '../application/google_sync_trigger_service.dart';
import 'widgets/google_sync_section.dart';

/// The app's first real settings screen (M5a task brief §3), reached via
/// the gear icon in `CalendarShellScreen`'s app bar. Currently holds only
/// the Google Calendar sync section; a thin shell so more settings sections
/// can be added later without this file growing unbounded (RULES.md §2).
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsScreenTitle)),
      body: Padding(
        padding: EdgeInsets.all(spacingMd),
        child: syncState.when(
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
