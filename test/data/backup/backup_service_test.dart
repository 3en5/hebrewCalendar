// Unit tests for FileBackupService's plugin-free surface (M7,
// docs/RULES.md §3 pattern: the two methods that touch file_picker/
// share_plus, `exportToFile`/`shareBackup`/`importFromFile`, are thin
// adapters not exercised here — see LocalNotificationScheduler's precedent
// in docs/LESSONS.md): `buildBackupJson` (repository -> codec) and
// `restoreEvents` (the merge-by-id semantics), both against a plain
// `InMemoryEventRepository`.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/backup/backup_service.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/domain/backup/backup_codec.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';

const HebrewDate _anchor = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 5,
);

Event _draftEvent({
  String id = 'ignored-on-create',
  String title = 'אירוע',
  HebrewDate hebrewDate = _anchor,
}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Event(
    id: id,
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: title,
    hebrewDate: hebrewDate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late InMemoryEventRepository repository;
  late FileBackupService service;
  int idCounter = 0;

  setUp(() {
    idCounter = 0;
    repository = InMemoryEventRepository(
      idGenerator: () => 'test-event-${idCounter++}',
      now: () => DateTime(2026, 7, 6),
    );
    service = FileBackupService(
      repository: repository,
      now: () => DateTime(2026, 7, 6),
      appVersionResolver: () async => '1.2.3',
    );
  });

  tearDown(() {
    repository.dispose();
  });

  group('buildBackupJson', () {
    test('encodes every event from the repository', () async {
      await repository.create(_draftEvent(title: 'אירוע 1'));
      await repository.create(_draftEvent(title: 'אירוע 2'));

      final String json = await service.buildBackupJson();
      final BackupPayload payload = decodeBackup(json);

      expect(payload.appVersion, '1.2.3');
      expect(payload.events, hasLength(2));
      expect(
        payload.events.map((Event e) => e.title),
        containsAll(<String>['אירוע 1', 'אירוע 2']),
      );
    });

    test('encodes an empty backup when there are no events', () async {
      final String json = await service.buildBackupJson();
      final BackupPayload payload = decodeBackup(json);
      expect(payload.events, isEmpty);
    });
  });

  group('restoreEvents (merge-by-id)', () {
    test('creates a fresh event (new id) when no local id matches', () async {
      final BackupImportResult result = await service.restoreEvents(<Event>[
        _draftEvent(id: 'backup-id-from-another-device', title: 'משוחזר'),
      ]);

      expect(result.status, BackupImportStatus.success);
      expect(result.createdCount, 1);
      expect(result.updatedCount, 0);

      final List<Event> all = await repository.getAllForSync();
      expect(all, hasLength(1));
      // create() always assigns its own id, ignoring the one on the backup
      // event (EventRepository.create's documented contract) — the local
      // repository never ends up with an id it didn't itself generate.
      expect(all.single.id, isNot('backup-id-from-another-device'));
      expect(all.single.title, 'משוחזר');
    });

    test('overwrites an existing event with the same id', () async {
      final Event created = await repository.create(_draftEvent(title: 'לפני'));

      final BackupImportResult result = await service.restoreEvents(<Event>[
        created.copyWith(title: 'אחרי'),
      ]);

      expect(result.status, BackupImportStatus.success);
      expect(result.createdCount, 0);
      expect(result.updatedCount, 1);

      final Event? restored = await repository.getById(created.id);
      expect(restored?.title, 'אחרי');
    });

    test('marks a restored (overwritten) event dirty for re-sync', () async {
      final Event created = await repository.create(_draftEvent());
      await repository.updateSyncState(
        created.id,
        googleSync: created.googleSync.copyWith(dirty: false),
      );
      final Event? beforeRestore = await repository.getById(created.id);
      expect(beforeRestore?.googleSync.dirty, isFalse);

      await service.restoreEvents(<Event>[
        created.copyWith(title: 'עודכן מגיבוי'),
      ]);

      final Event? afterRestore = await repository.getById(created.id);
      expect(afterRestore?.googleSync.dirty, isTrue);
    });

    test('never deletes an existing event missing from the backup', () async {
      final Event keep = await repository.create(
        _draftEvent(title: 'נשאר', hebrewDate: _anchor),
      );
      await service.restoreEvents(<Event>[
        _draftEvent(id: 'other-device-id', title: 'חדש מהגיבוי'),
      ]);

      final Event? stillThere = await repository.getById(keep.id);
      expect(stillThere, isNotNull);
      expect(stillThere?.title, 'נשאר');

      final List<Event> all = await repository.getAllForSync();
      expect(all, hasLength(2));
    });

    test('restoring an empty backup is a no-op', () async {
      await repository.create(_draftEvent());
      final BackupImportResult result = await service.restoreEvents(<Event>[]);
      expect(result.status, BackupImportStatus.success);
      expect(result.createdCount, 0);
      expect(result.updatedCount, 0);
      expect(await repository.getAllForSync(), hasLength(1));
    });
  });

  group('export -> import round trip through the codec', () {
    test(
      'restoring an exported backup into the same repository is a no-op',
      () async {
        final Event created = await repository.create(_draftEvent());
        final String json = await service.buildBackupJson();
        final BackupPayload payload = decodeBackup(json);

        final BackupImportResult result = await service.restoreEvents(
          payload.events,
        );

        expect(result.updatedCount, 1);
        expect(result.createdCount, 0);
        final Event? afterRestore = await repository.getById(created.id);
        expect(afterRestore?.title, created.title);
      },
    );
  });
}
