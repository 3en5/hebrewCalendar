import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../data/backup/backup_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/backup_providers.dart';

/// The settings screen's "גיבוי ושחזור" section (M7 task brief §1): export
/// (save-to-file, with a share-sheet alternative) and import (with a
/// merge-semantics confirm dialog), both showing a progress indicator while
/// busy and a Hebrew success/error snackbar on completion. A thin
/// [ConsumerStatefulWidget] purely for the local "is an action in flight"
/// flag — all the actual work lives in [BackupService] (`backupServiceProvider`).
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _busy = false;

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
              l10n.settingsBackupSectionTitle,
              style: TextStyle(fontSize: titleRem, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: spacingSm),
            Text(
              l10n.settingsBackupDescription,
              style: TextStyle(
                fontSize: bodySmallRem,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacingMd),
            // Device feedback 2026-10-13: compact buttons side by side.
            Wrap(
              spacing: spacingSm,
              runSpacing: spacingXs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _busy ? null : () => _handleExport(l10n),
                  icon: _busy
                      ? const _Spinner()
                      : const Icon(Icons.save_alt_outlined),
                  label: Text(l10n.settingsBackupExportButton),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _handleImport(l10n),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: Text(l10n.settingsBackupImportButton),
                ),
                IconButton(
                  tooltip: l10n.settingsBackupShareTooltip,
                  onPressed: _busy ? null : () => _handleShare(l10n),
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport(AppLocalizations l10n) async {
    final BackupService service = ref.read(backupServiceProvider);
    setState(() => _busy = true);
    final BackupExportResult result = await service.exportToFile();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    _showExportResult(result, l10n);
  }

  Future<void> _handleShare(AppLocalizations l10n) async {
    final BackupService service = ref.read(backupServiceProvider);
    setState(() => _busy = true);
    final BackupExportResult result = await service.shareBackup();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    _showExportResult(result, l10n);
  }

  void _showExportResult(BackupExportResult result, AppLocalizations l10n) {
    switch (result.status) {
      case BackupExportStatus.cancelled:
        return;
      case BackupExportStatus.success:
        _showSnackBar(l10n.settingsBackupExportSuccessMessage);
      case BackupExportStatus.failure:
        _showSnackBar(l10n.settingsBackupExportErrorMessage);
    }
  }

  Future<void> _handleImport(AppLocalizations l10n) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.settingsBackupImportConfirmTitle),
        content: Text(l10n.settingsBackupImportConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsBackupImportConfirmButton),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) {
      return;
    }
    final BackupService service = ref.read(backupServiceProvider);
    setState(() => _busy = true);
    final BackupImportResult result = await service.importFromFile();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    switch (result.status) {
      case BackupImportStatus.cancelled:
        return;
      case BackupImportStatus.success:
        _showSnackBar(
          l10n.settingsBackupImportSuccessMessage(
            result.createdCount,
            result.updatedCount,
          ),
        );
      case BackupImportStatus.failure:
        _showSnackBar(l10n.settingsBackupImportErrorMessage);
      case BackupImportStatus.unsupportedVersion:
        _showSnackBar(l10n.settingsBackupImportUnsupportedVersionMessage);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: bodyRem,
    height: bodyRem,
    child: const CircularProgressIndicator(strokeWidth: 2),
  );
}
