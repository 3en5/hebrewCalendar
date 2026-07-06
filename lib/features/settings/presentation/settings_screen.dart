import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/demo_mode_provider.dart';
import '../application/app_version_provider.dart';
import '../application/google_sync_providers.dart';
import '../application/google_sync_settings_state.dart';
import '../application/google_sync_trigger_service.dart';
import 'about_screen.dart';
import 'widgets/backup_section.dart';
import 'widgets/google_sync_section.dart';

/// The app's settings screen, reached via the gear icon in
/// `CalendarShellScreen`'s app bar: Google Calendar sync (M5a), local-file
/// backup/restore (M7), an About entry (M5c) and the installed app version.
/// A `ListView` (not a fixed `Column`) so it stays usable if more sections
/// are added later or the content doesn't fit a small screen — RULES.md
/// §4.3 ("no hard-coded height for a full screen").
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<String> version = ref.watch(appVersionProvider);
    final bool demoMode = ref.watch(demoModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsScreenTitle)),
      body: ListView(
        padding: EdgeInsets.all(spacingMd),
        children: <Widget>[
          // Task brief #5: in demo mode there is no signed-in account to
          // sync with, so the section shows a fixed disabled message and
          // this screen never watches `googleSyncStateProvider`/
          // `googleSyncTriggerServiceProvider` at all — no Google/Firestore
          // calls, not even indirectly through building those providers.
          if (demoMode)
            GoogleSyncSection(
              state: const GoogleSyncSettingsState(),
              onEnabledChanged: (bool _) {},
              onSyncNow: () {},
              demoModeDisabled: true,
            )
          else
            _RealGoogleSyncSection(l10n: l10n),
          SizedBox(height: spacingMd),
          const BackupSection(),
          SizedBox(height: spacingMd),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAboutTooltip),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
          ),
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
}

/// The real (non-demo) Google Calendar sync section — split out so
/// `SettingsScreen.build` can skip watching `googleSyncStateProvider`/
/// `googleSyncTriggerServiceProvider` entirely in demo mode (task brief
/// #5), rather than building them and discarding the result.
class _RealGoogleSyncSection extends ConsumerWidget {
  const _RealGoogleSyncSection({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GoogleSyncSettingsState> syncState = ref.watch(
      googleSyncStateProvider,
    );
    final GoogleSyncTriggerService service = ref.read(
      googleSyncTriggerServiceProvider,
    );

    return syncState.when(
      data: (GoogleSyncSettingsState state) => GoogleSyncSection(
        state: state,
        onEnabledChanged: (bool enabled) =>
            unawaited(_onEnabledChanged(context, service, l10n, enabled)),
        onSyncNow: () => unawaited(service.syncNow()),
        onRetryLoad: () => unawaited(service.retryLoad()),
      ),
      // `GoogleSyncTriggerService.start()` now always reaches an `_emit()`
      // call within `_startTimeout` at the very worst (success, or a
      // caught/timed-out failure) — so this spinner is bounded, not endless
      // (real-device report #2's root cause).
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => GoogleSyncSection(
        state: const GoogleSyncSettingsState(initialLoadFailed: true),
        onEnabledChanged: (bool enabled) =>
            unawaited(_onEnabledChanged(context, service, l10n, enabled)),
        onSyncNow: () => unawaited(service.syncNow()),
        onRetryLoad: () => unawaited(service.retryLoad()),
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
