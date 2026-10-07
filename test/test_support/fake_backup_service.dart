import 'package:hebrew_calendar/data/backup/backup_service.dart';

/// A controllable [BackupService] test double (M7) — used as a
/// `backupServiceProvider` override in
/// `test/features/settings/presentation/widgets/backup_section_test.dart` so
/// that widget test never touches the `file_picker`/`share_plus` plugin
/// channels, mirroring `FakeNotificationScheduler`/`FakeGoogleCalendarApi`'s
/// role for M4/M5a (see docs/LESSONS.md).
class FakeBackupService implements BackupService {
  BackupExportResult exportResult = const BackupExportResult(
    status: BackupExportStatus.success,
  );
  BackupExportResult shareResult = const BackupExportResult(
    status: BackupExportStatus.success,
  );
  BackupImportResult importResult = const BackupImportResult(
    status: BackupImportStatus.success,
    createdCount: 1,
    updatedCount: 2,
  );

  int exportToFileCallCount = 0;
  int shareBackupCallCount = 0;
  int importFromFileCallCount = 0;

  @override
  Future<BackupExportResult> exportToFile() async {
    exportToFileCallCount++;
    return exportResult;
  }

  @override
  Future<BackupExportResult> shareBackup() async {
    shareBackupCallCount++;
    return shareResult;
  }

  @override
  Future<BackupImportResult> importFromFile() async {
    importFromFileCallCount++;
    return importResult;
  }
}
