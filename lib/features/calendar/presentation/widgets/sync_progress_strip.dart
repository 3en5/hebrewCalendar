import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/sync/sync_state.dart';
import '../../../settings/application/google_sync_providers.dart';
import '../../../settings/application/google_sync_settings_state.dart';
import '../../../settings/presentation/widgets/sync_progress_view.dart';

/// A slim sync progress strip under the calendar's app bar while a Google
/// sync pass runs (device request 2026-10-12); nothing otherwise. Its own
/// widget so progress ticks rebuild only this strip, not the calendar.
class SyncProgressStrip extends ConsumerWidget {
  const SyncProgressStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoogleSyncSettingsState? state = ref
        .watch(googleSyncStateProvider)
        .value;
    if (state == null || state.status != SyncStatus.syncing) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        spacingMd,
        0,
        spacingMd,
        spacingXs,
      ),
      child: SyncProgressView(progress: state.progress, compact: true),
    );
  }
}
