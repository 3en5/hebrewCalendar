import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/sync/sync_state.dart';
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
///
/// A `ConsumerStatefulWidget` (not stateless) purely to hold
/// [_loadingWatchdog]: real-device report #2, round 2's last line of
/// defense. `google_sync_providers.dart`/`google_sync_trigger_service.dart`
/// now bound every layer of the load (settings-store read, provider/service
/// construction) to an explicit timeout that always ends in an `_emit()` —
/// but should some *future* change to that chain reintroduce a path that
/// never emits, this widget must still be provably unable to spin forever
/// on its own, independent of how well-behaved the providers are.
class _RealGoogleSyncSection extends ConsumerStatefulWidget {
  const _RealGoogleSyncSection({required this.l10n});

  final AppLocalizations l10n;

  @override
  ConsumerState<_RealGoogleSyncSection> createState() =>
      _RealGoogleSyncSectionState();
}

class _RealGoogleSyncSectionState
    extends ConsumerState<_RealGoogleSyncSection> {
  static const Duration _watchdogDuration = Duration(seconds: 12);

  Timer? _watchdog;
  bool _watchdogFired = false;

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  void _armWatchdogIfNeeded() {
    if (_watchdog != null || _watchdogFired) {
      return;
    }
    _watchdog = Timer(_watchdogDuration, () {
      debugPrint(
        '[sync-settings] widget-level loading watchdog fired after '
        '$_watchdogDuration — forcing the retry card',
      );
      if (mounted) {
        setState(() => _watchdogFired = true);
      }
    });
  }

  void _disarmWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = widget.l10n;
    final AsyncValue<GoogleSyncSettingsState> syncState = ref.watch(
      googleSyncStateProvider,
    );
    final GoogleSyncTriggerService service = ref.read(
      googleSyncTriggerServiceProvider,
    );

    if (syncState.isLoading) {
      _armWatchdogIfNeeded();
    } else {
      _disarmWatchdog();
    }

    if (_watchdogFired && syncState.isLoading) {
      return GoogleSyncSection(
        state: GoogleSyncSettingsState(
          initialLoadFailed: true,
          errorMessage: l10n.settingsGoogleSyncWatchdogMessage,
        ),
        onEnabledChanged: (bool enabled) =>
            unawaited(_onEnabledChanged(context, service, l10n, enabled)),
        onSyncNow: () => unawaited(service.syncNow()),
        onRetryLoad: () {
          setState(() => _watchdogFired = false);
          unawaited(service.retryLoad());
        },
      );
    }

    return syncState.when(
      data: (GoogleSyncSettingsState state) => GoogleSyncSection(
        state: state,
        onEnabledChanged: (bool enabled) =>
            unawaited(_onEnabledChanged(context, service, l10n, enabled)),
        onSyncNow: () => unawaited(service.syncNow()),
        onRetryLoad: () => unawaited(service.retryLoad()),
      ),
      // Bounded by `GoogleSyncTriggerService.start()`'s timeout *and* this
      // widget's own `_watchdogDuration` fallback above — never endless
      // (real-device report #2).
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => GoogleSyncSection(
        state: GoogleSyncSettingsState(
          initialLoadFailed: true,
          errorMessage: error.toString(),
        ),
        onEnabledChanged: (bool enabled) =>
            unawaited(_onEnabledChanged(context, service, l10n, enabled)),
        onSyncNow: () => unawaited(service.syncNow()),
        onRetryLoad: () => unawaited(service.retryLoad()),
      ),
    );
  }

  /// Device-feedback round #3: `service.enable()`/`service.disable()` now
  /// always resolve (never throw — see `google_sync_trigger_service.dart`),
  /// so this callback can reliably tell a quiet decline/cancel apart from a
  /// genuine failure by reading `service.state` right after: a real failure
  /// sets `status == SyncStatus.error` with an `errorMessage`, which gets
  /// its own snackbar with the actual error text (never swallowed); a plain
  /// decline/cancel leaves `status` at `idle` and shows the existing
  /// generic "access denied" message instead, matching prior behavior.
  Future<void> _onEnabledChanged(
    BuildContext context,
    GoogleSyncTriggerService service,
    AppLocalizations l10n,
    bool enabled,
  ) async {
    if (!enabled) {
      await service.disable();
      if (context.mounted) {
        _showErrorSnackBarIfAny(context, service, l10n);
      }
      return;
    }
    final bool granted = await service.enable();
    if (granted || !context.mounted) {
      return;
    }
    final GoogleSyncSettingsState afterEnable = service.state;
    if (afterEnable.status == SyncStatus.error &&
        afterEnable.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.settingsGoogleSyncActionFailedMessage(
              afterEnable.errorMessage!,
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsGoogleSyncAccessDeniedMessage)),
      );
    }
  }

  void _showErrorSnackBarIfAny(
    BuildContext context,
    GoogleSyncTriggerService service,
    AppLocalizations l10n,
  ) {
    if (!context.mounted) {
      return;
    }
    final GoogleSyncSettingsState state = service.state;
    if (state.status == SyncStatus.error && state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.settingsGoogleSyncActionFailedMessage(state.errorMessage!),
          ),
        ),
      );
    }
  }
}
