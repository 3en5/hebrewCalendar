import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/sync/sync_progress.dart';
import '../../../../l10n/app_localizations.dart';

/// The running sync pass's progress (device request 2026-10-12): what it is
/// doing in words ("מעדכן ביומן: 340 מתוך 2,944") over a progress bar that
/// fills when the total is known and runs indeterminate before that.
/// Shown in the settings sync card and, slim, under the calendar app bar.
class SyncProgressView extends StatelessWidget {
  const SyncProgressView({
    required this.progress,
    this.compact = false,
    super.key,
  });

  /// Null while the pass is starting up.
  final SyncProgress? progress;

  /// The slim variant for the calendar screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final NumberFormat number = NumberFormat.decimalPattern('he');
    final SyncProgress? p = progress;
    final String label = switch (p?.phase) {
      null => l10n.syncProgressStarting,
      SyncPhase.downloading => l10n.syncProgressDownloading,
      SyncPhase.applying => l10n.syncProgressApplying(
        number.format(p!.done),
        number.format(p.total),
      ),
      SyncPhase.uploading => l10n.syncProgressUploading(
        number.format(p!.done),
        number.format(p.total),
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LinearProgressIndicator(
            value: p?.fraction,
            minHeight: compact ? spacingXs / 2 : spacingXs,
            borderRadius: BorderRadius.circular(spacingXs),
          ),
          SizedBox(height: spacingXs),
          Text(
            label,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: compact ? captionRem : bodySmallRem,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
