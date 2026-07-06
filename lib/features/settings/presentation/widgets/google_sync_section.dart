import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/sync/sync_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/google_sync_settings_state.dart';

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
  });

  final GoogleSyncSettingsState state;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onSyncNow;

  bool get _isSyncing => state.status == SyncStatus.syncing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.settingsGoogleSyncSectionTitle,
              style: TextStyle(fontSize: titleRem, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: spacingSm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsGoogleSyncEnableLabel),
              value: state.enabled,
              onChanged: _isSyncing ? null : onEnabledChanged,
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
          ],
        ),
      ),
    );
  }
}
