import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/backup/backup_service.dart';
import '../../event_editor/application/event_repository_provider.dart';

/// The app-wide [BackupService] (M7): a [FileBackupService] wired to
/// whichever [EventRepository] is currently active
/// (`event_repository_provider.dart` — Firestore once signed in, in-memory
/// otherwise/in tests). Overridden with a fake in
/// `test/features/settings/presentation/widgets/backup_section_test.dart`
/// (same pattern as `notificationSchedulerProvider`/`googleCalendarApiProvider`
/// — see docs/LESSONS.md) so no widget test ever touches the
/// `file_picker`/`share_plus` plugin channels.
final Provider<BackupService> backupServiceProvider = Provider<BackupService>((
  Ref ref,
) {
  return FileBackupService(repository: ref.watch(eventRepositoryProvider));
});
