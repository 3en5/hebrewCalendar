/// Local-file backup/restore (ARCHITECTURE.md §7, M7 — the Storage-backed
/// cloud variant is deferred alongside M6/Blaze, see docs/WISHLIST.md):
/// exports the signed-in user's full event list to a JSON file the user
/// either saves directly (`file_picker`'s `saveFile`) or hands to another
/// app via the OS share sheet (`share_plus`), and restores from one with
/// merge-by-id semantics.
///
/// Split into an abstract [BackupService] (what the settings UI depends on —
/// overridden with a fake in `test/test_support/fake_backup_service.dart` for
/// the widget test, the same pattern as `NotificationScheduler`/
/// `GoogleCalendarApi`) and the real [FileBackupService] implementation.
/// [FileBackupService.buildBackupJson]/[FileBackupService.restoreEvents] are
/// public *beyond* the abstract interface specifically so
/// `test/data/backup/backup_service_test.dart` can exercise the codec
/// round-trip and merge-by-id logic against an `InMemoryEventRepository`
/// without ever touching the `file_picker`/`share_plus` plugin channels
/// (which throw `MissingPluginException` under plain `flutter test` — see
/// docs/LESSONS.md's note on `LocalNotificationScheduler`).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/backup/backup_codec.dart';
import '../../domain/event/event.dart';
import '../../domain/event/event_repository.dart';

/// Outcome of an export action ([BackupService.exportToFile]/
/// [BackupService.shareBackup]).
enum BackupExportStatus { success, cancelled, failure }

class BackupExportResult {
  const BackupExportResult({required this.status, this.filePath, this.error});

  final BackupExportStatus status;

  /// The path the file was saved to, if [status] is
  /// [BackupExportStatus.success] and came from [BackupService.exportToFile]
  /// (`saveFile` returns the destination path; `shareBackup` doesn't, since
  /// the share sheet doesn't report one).
  final String? filePath;

  final Object? error;
}

enum BackupImportStatus { success, cancelled, failure, unsupportedVersion }

class BackupImportResult {
  const BackupImportResult({
    required this.status,
    this.createdCount = 0,
    this.updatedCount = 0,
    this.error,
  });

  final BackupImportStatus status;

  /// Number of events that had no matching local id and were created fresh
  /// (with a brand-new id — see [FileBackupService.restoreEvents]).
  final int createdCount;

  /// Number of events whose id matched an existing local event, which was
  /// overwritten in place.
  final int updatedCount;

  final Object? error;
}

/// What the settings screen's backup section depends on — lets
/// `test/test_support/fake_backup_service.dart` stand in for
/// [FileBackupService] in the widget test without touching any plugin.
abstract class BackupService {
  /// Exports every event to a JSON file at a location the user picks via the
  /// native "save file" dialog.
  Future<BackupExportResult> exportToFile();

  /// Opens the OS share sheet with the backup file, letting the user hand it
  /// to any app (cloud drive, messaging, etc.) instead of picking a location
  /// directly.
  Future<BackupExportResult> shareBackup();

  /// Lets the user pick a backup JSON file and restores it (merge-by-id —
  /// see [FileBackupService.restoreEvents]).
  Future<BackupImportResult> importFromFile();
}

/// The real [BackupService]: [EventRepository.getAllForSync] + `backup_codec`
/// for the JSON shape, `file_picker`/`share_plus` for the actual file I/O.
class FileBackupService implements BackupService {
  FileBackupService({
    required EventRepository repository,
    DateTime Function() now = DateTime.now,
    Future<String> Function() appVersionResolver = _defaultAppVersionResolver,
  }) : _repository = repository,
       _now = now,
       _appVersionResolver = appVersionResolver;

  final EventRepository _repository;
  final DateTime Function() _now;
  final Future<String> Function() _appVersionResolver;

  static Future<String> _defaultAppVersionResolver() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return info.version;
  }

  String _fileName() {
    final DateTime timestamp = _now();
    final String stamp =
        '${timestamp.year.toString().padLeft(4, '0')}-'
        '${timestamp.month.toString().padLeft(2, '0')}-'
        '${timestamp.day.toString().padLeft(2, '0')}';
    return 'hebrew-calendar-backup-$stamp.json';
  }

  /// Fetches every event ([EventRepository.getAllForSync]) and encodes them
  /// via `backup_codec.dart` — the pure, plugin-free half of export, kept
  /// public so it's directly unit-testable.
  Future<String> buildBackupJson() async {
    final List<Event> events = await _repository.getAllForSync();
    final String appVersion = await _appVersionResolver();
    return encodeBackup(
      events: events,
      appVersion: appVersion,
      createdAt: _now(),
    );
  }

  @override
  Future<BackupExportResult> exportToFile() async {
    try {
      final Uint8List bytes = Uint8List.fromList(
        utf8.encode(await buildBackupJson()),
      );
      final String? path = await FilePicker.saveFile(
        fileName: _fileName(),
        type: FileType.custom,
        allowedExtensions: <String>['json'],
        bytes: bytes,
      );
      if (path == null) {
        return const BackupExportResult(status: BackupExportStatus.cancelled);
      }
      return BackupExportResult(
        status: BackupExportStatus.success,
        filePath: path,
      );
    } catch (error) {
      return BackupExportResult(
        status: BackupExportStatus.failure,
        error: error,
      );
    }
  }

  @override
  Future<BackupExportResult> shareBackup() async {
    try {
      final Uint8List bytes = Uint8List.fromList(
        utf8.encode(await buildBackupJson()),
      );
      final ShareResult result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile.fromData(bytes, mimeType: 'application/json')],
          fileNameOverrides: <String>[_fileName()],
        ),
      );
      if (result.status == ShareResultStatus.dismissed) {
        return const BackupExportResult(status: BackupExportStatus.cancelled);
      }
      return const BackupExportResult(status: BackupExportStatus.success);
    } catch (error) {
      return BackupExportResult(
        status: BackupExportStatus.failure,
        error: error,
      );
    }
  }

  @override
  Future<BackupImportResult> importFromFile() async {
    final FilePickerResult? picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return const BackupImportResult(status: BackupImportStatus.cancelled);
    }
    final Uint8List? bytes = picked.files.single.bytes;
    if (bytes == null) {
      return const BackupImportResult(status: BackupImportStatus.failure);
    }
    try {
      final BackupPayload payload = decodeBackup(utf8.decode(bytes));
      return restoreEvents(payload.events);
    } on BackupFormatVersionError {
      return const BackupImportResult(
        status: BackupImportStatus.unsupportedVersion,
      );
    } catch (error) {
      return BackupImportResult(
        status: BackupImportStatus.failure,
        error: error,
      );
    }
  }

  /// Restores [events] into [_repository] with merge-by-id semantics — the
  /// safest restore strategy (ARCHITECTURE.md §7): an event whose id matches
  /// an existing local event is overwritten in place
  /// ([EventRepository.update]); every other event is created fresh
  /// ([EventRepository.create], which always assigns a brand-new id
  /// regardless of the id on the passed [Event] — see its doc comment).
  /// Nothing already on the device is ever deleted, even if it's missing
  /// from [events] — restoring is meant to bring events *back*, never to
  /// prune ones created since the backup was made (accidentally wiping
  /// events newer than an old backup would be far worse than leaving a
  /// harmless duplicate). Both `create`/`update` already mark the touched
  /// event dirty (`Event.googleSync.dirty` — a repository-layer hook, RULES.md
  /// §6), so the next Google Calendar sync pass re-pushes every restored
  /// event with no special-casing needed here.
  ///
  /// Public (not part of [BackupService]) so it's directly unit-testable
  /// against an `InMemoryEventRepository` without any plugin involved.
  Future<BackupImportResult> restoreEvents(List<Event> events) async {
    int created = 0;
    int updated = 0;
    for (final Event event in events) {
      final Event? existing = event.id.isEmpty
          ? null
          : await _repository.getById(event.id);
      if (existing == null) {
        await _repository.create(event);
        created++;
      } else {
        await _repository.update(event);
        updated++;
      }
    }
    return BackupImportResult(
      status: BackupImportStatus.success,
      createdCount: created,
      updatedCount: updated,
    );
  }
}
