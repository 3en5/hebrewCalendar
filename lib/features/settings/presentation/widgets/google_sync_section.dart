import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/sync/sync_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/google_sync_settings_state.dart';
import 'sync_progress_view.dart';

/// The M5a settings screen's "סנכרון עם יומן Google" section (task brief
/// §3): enable/disable switch, last-sync time, manual sync button with a
/// progress indicator while [GoogleSyncSettingsState.status] is
/// [SyncStatus.syncing], and a Hebrew error surface when it's
/// [SyncStatus.error]. Split into its own widget (RULES.md §2) so
/// `settings_screen.dart` stays a thin shell as more settings sections are
/// added later.
class GoogleSyncSection extends StatelessWidget {
  const GoogleSyncSection({
    super.key,
    required this.state,
    required this.onEnabledChanged,
    required this.onSyncNow,
    this.onRetryLoad,
    this.demoModeDisabled = false,
  });

  final GoogleSyncSettingsState state;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onSyncNow;

  /// Called by the "נסה שוב" button when [GoogleSyncSettingsState.initialLoadFailed]
  /// is true (real-device report #2 — never leave an endless spinner or a
  /// silently-broken section: always offer a way to try loading again).
  final VoidCallback? onRetryLoad;

  /// M5c demo mode (Play Store reviewer flow, task brief #5): there is no
  /// signed-in Google account to sync with, so this section shows a fixed
  /// "requires signing in with Google" message instead of the switch — no
  /// spinner, no Firestore/Google calls at all.
  final bool demoModeDisabled;

  bool get _isSyncing => state.status == SyncStatus.syncing;

  /// Device-feedback round #3: while [GoogleSyncSettingsState.authorizing]
  /// is true, the enable switch is disabled and shows a small progress
  /// indicator instead of its usual leading space, so a second tap during
  /// the in-flight Google authorization request can't fire a second
  /// attempt.
  bool get _isBusy => _isSyncing || state.authorizing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (demoModeDisabled) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.settingsGoogleSyncSectionTitle,
                style: TextStyle(
                  fontSize: titleRem,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacingSm),
              Text(
                l10n.settingsGoogleSyncDisabledDemoMessage,
                style: TextStyle(
                  fontSize: bodySmallRem,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (state.initialLoadFailed) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.settingsGoogleSyncSectionTitle,
                style: TextStyle(
                  fontSize: titleRem,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacingSm),
              Text(
                state.errorMessage ?? l10n.settingsGoogleSyncLoadFailedMessage,
                style: TextStyle(
                  fontSize: bodySmallRem,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              SizedBox(height: spacingSm),
              FilledButton.icon(
                onPressed: onRetryLoad,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.settingsGoogleSyncRetryButton),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Device feedback 2026-10-13: one title, with the switch on its
            // line (the separate "sync with Google Calendar" label repeated it).
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.settingsGoogleSyncSectionTitle,
                style: TextStyle(
                  fontSize: titleRem,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: state.enabled,
              onChanged: _isBusy ? null : onEnabledChanged,
              secondary: state.authorizing
                  ? SizedBox(
                      width: bodyRem,
                      height: bodyRem,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: spacingSm),
              child: Text(
                state.lastSyncedAt == null
                    ? l10n.settingsGoogleSyncNeverSynced
                    : l10n.settingsGoogleSyncLastSyncedAt(
                        DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(state.lastSyncedAt!),
                      ),
                style: TextStyle(
                  fontSize: bodySmallRem,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (state.status == SyncStatus.error && state.errorMessage != null)
              Padding(
                padding: EdgeInsetsDirectional.only(bottom: spacingSm),
                child: Text(
                  l10n.settingsGoogleSyncErrorPrefix(state.errorMessage!),
                  style: TextStyle(
                    fontSize: bodySmallRem,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            // M5b: read-only — periodic background sync always follows the
            // switch above (no separate toggle, task brief M5b §3).
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: spacingSm),
              child: Text(
                l10n.settingsBackgroundSyncStatus(
                  state.enabled
                      ? l10n.settingsBackgroundSyncStatusActive
                      : l10n.settingsBackgroundSyncStatusOff,
                ),
                style: TextStyle(
                  fontSize: bodySmallRem,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: state.enabled && !_isSyncing ? onSyncNow : null,
              icon: _isSyncing
                  ? SizedBox(
                      width: bodyRem,
                      height: bodyRem,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                _isSyncing
                    ? l10n.settingsGoogleSyncSyncingLabel
                    : l10n.settingsGoogleSyncNowButton,
              ),
            ),
            if (_isSyncing) ...<Widget>[
              SizedBox(height: spacingSm),
              SyncProgressView(progress: state.progress),
            ],
          ],
        ),
      ),
    );
  }
}
