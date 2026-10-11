// Unit tests for InMemoryEventRepository's M5a sync-support methods
// (dirty-marking on create/update, updateSyncState, pending Google
// deletions, upsertFromGoogle/applyRemoteDelete) — split out from
// in_memory_event_repository_test.dart (RULES.md §2, that file would
// otherwise exceed 500 lines).

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_source.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/sync/export_candidate.dart';
import 'package:hebrew_calendar/domain/sync/remote_event_snapshot.dart';
import 'package:hebrew_calendar/domain/sync/sync_state.dart';

const HebrewDate _tishrei5 = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 5,
);

Event _draftEvent({String title = 'אירוע', HebrewDate hebrewDate = _tishrei5}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Event(
    id: 'ignored-on-create',
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
  int idCounter = 0;

  setUp(() {
    idCounter = 0;
    repository = InMemoryEventRepository(
      idGenerator: () => 'test-event-${idCounter++}',
      now: () => DateTime(2026, 7, 6),
    );
  });

  tearDown(() {
    repository.dispose();
  });

  group('M5a sync support', () {
    test('create marks the new event dirty for export', () async {
      final Event created = await repository.create(_draftEvent());
      expect(created.googleSync.dirty, isTrue);
    });

    test(
      'update marks the event dirty again, even if the caller passed dirty: false',
      () async {
        final Event created = await repository.create(_draftEvent());
        await repository.updateSyncState(
          created.id,
          googleSync: const GoogleSyncState(
            googleEventId: 'g-1',
            etag: 'etag-1',
          ),
        );
        final Event notDirty = (await repository.getById(created.id))!;
        expect(notDirty.googleSync.dirty, isFalse);

        final Event updated = await repository.update(
          notDirty.copyWith(title: 'עודכן'),
        );
        expect(updated.googleSync.dirty, isTrue);
      },
    );

    test('updateSyncState does not mark the event dirty', () async {
      final Event created = await repository.create(_draftEvent());
      await repository.updateSyncState(
        created.id,
        googleSync: const GoogleSyncState(
          googleEventId: 'g-1',
          etag: 'etag-1',
          dirty: false,
        ),
      );
      final Event? afterSync = await repository.getById(created.id);
      expect(afterSync?.googleSync.dirty, isFalse);
      expect(afterSync?.googleSync.googleEventId, 'g-1');
    });

    test(
      'updateSyncState merges googleInstanceSync entries instead of replacing the map',
      () async {
        final Event created = await repository.create(_draftEvent());
        await repository.updateSyncState(
          created.id,
          googleInstanceSync: const <String, GoogleSyncState>{
            'key-1': GoogleSyncState(googleEventId: 'g-1'),
          },
        );
        await repository.updateSyncState(
          created.id,
          googleInstanceSync: const <String, GoogleSyncState>{
            'key-2': GoogleSyncState(googleEventId: 'g-2'),
          },
        );
        final Event? afterSync = await repository.getById(created.id);
        expect(
          afterSync?.googleInstanceSync.keys,
          containsAll(<String>['key-1', 'key-2']),
        );
      },
    );

    test(
      'getAllForSync returns every event regardless of date range',
      () async {
        await repository.create(_draftEvent());
        await repository.create(
          _draftEvent(
            hebrewDate: const HebrewDate(
              year: 5800,
              month: HebrewMonth.nisan,
              day: 1,
            ),
          ),
        );
        final List<Event> all = await repository.getAllForSync();
        expect(all, hasLength(2));
      },
    );

    test(
      'getByGoogleEventId finds the event whose googleSync references it',
      () async {
        final Event created = await repository.create(_draftEvent());
        await repository.updateSyncState(
          created.id,
          googleSync: const GoogleSyncState(googleEventId: 'g-42'),
        );
        final Event? found = await repository.getByGoogleEventId('g-42');
        expect(found?.id, created.id);
        expect(await repository.getByGoogleEventId('missing'), isNull);
      },
    );

    test(
      'delete with no Google sync state does not queue a pending deletion',
      () async {
        final Event created = await repository.create(_draftEvent());
        await repository.delete(created.id);
        expect(await repository.takePendingGoogleDeletions(), isEmpty);
      },
    );

    test(
      'delete with existing googleSync queues a PendingGoogleDeletion, drained once',
      () async {
        final Event created = await repository.create(_draftEvent());
        await repository.updateSyncState(
          created.id,
          googleSync: const GoogleSyncState(
            googleEventId: 'g-1',
            etag: 'etag-1',
          ),
        );
        await repository.delete(created.id);

        final List<PendingGoogleDeletion> pending = await repository
            .takePendingGoogleDeletions();
        expect(pending, hasLength(1));
        expect(pending.single.eventId, created.id);
        expect(pending.single.remoteInstances.single.googleEventId, 'g-1');

        // Draining again returns nothing — the queue only surfaces once.
        expect(await repository.takePendingGoogleDeletions(), isEmpty);
      },
    );

    test(
      'delete with googleInstanceSync entries queues one remote instance per entry',
      () async {
        final Event created = await repository.create(_draftEvent());
        await repository.updateSyncState(
          created.id,
          googleInstanceSync: const <String, GoogleSyncState>{
            'k1': GoogleSyncState(googleEventId: 'g-1'),
            'k2': GoogleSyncState(googleEventId: 'g-2'),
          },
        );
        await repository.delete(created.id);
        final List<PendingGoogleDeletion> pending = await repository
            .takePendingGoogleDeletions();
        expect(pending.single.remoteInstances, hasLength(2));
      },
    );

    test(
      'upsertFromGoogle creates a new event sourced from a remote snapshot',
      () async {
        final Event created = await repository.upsertFromGoogle(
          RemoteEventSnapshot(
            googleEventId: 'g-1',
            etag: 'etag-1',
            updatedAt: DateTime(2026, 3, 1),
            isCancelled: false,
            summary: 'אירוע מיובא',
            start: DateTime(2026, 3, 1),
            end: DateTime(2026, 3, 2),
          ),
        );
        expect(created.source, EventSource.google);
        expect(created.title, 'אירוע מיובא');
        expect(created.googleSync.googleEventId, 'g-1');
        expect(created.googleSync.dirty, isFalse);
      },
    );

    test(
      'upsertFromGoogle with existingEventId updates the same local event in place',
      () async {
        final Event created = await repository.upsertFromGoogle(
          RemoteEventSnapshot(
            googleEventId: 'g-1',
            etag: 'etag-1',
            updatedAt: DateTime(2026, 3, 1),
            isCancelled: false,
            summary: 'גרסה ראשונה',
            start: DateTime(2026, 3, 1),
            end: DateTime(2026, 3, 2),
          ),
        );
        final Event updated = await repository.upsertFromGoogle(
          RemoteEventSnapshot(
            googleEventId: 'g-1',
            etag: 'etag-2',
            updatedAt: DateTime(2026, 3, 2),
            isCancelled: false,
            summary: 'גרסה מעודכנת',
            start: DateTime(2026, 3, 1),
            end: DateTime(2026, 3, 2),
          ),
          existingEventId: created.id,
        );
        expect(updated.id, created.id);
        expect(updated.title, 'גרסה מעודכנת');
        expect(await repository.getAllForSync(), hasLength(1));
      },
    );

    test(
      'applyRemoteDelete removes the event without queuing a pending deletion',
      () async {
        final Event created = await repository.upsertFromGoogle(
          RemoteEventSnapshot(
            googleEventId: 'g-1',
            etag: 'etag-1',
            updatedAt: DateTime(2026, 3, 1),
            isCancelled: false,
            start: DateTime(2026, 3, 1),
            end: DateTime(2026, 3, 2),
          ),
        );
        await repository.applyRemoteDelete(created.id);
        expect(await repository.getById(created.id), isNull);
        expect(await repository.takePendingGoogleDeletions(), isEmpty);
      },
    );
  });

  test(
    'localEdits fires for user edits only, never for imports (round #10)',
    () async {
      int edits = 0;
      final sub = repository.localEdits.listen((_) => edits++);
      addTearDown(sub.cancel);

      await repository.upsertFromGoogle(
        RemoteEventSnapshot(
          googleEventId: 'g-edits',
          etag: 'etag',
          updatedAt: DateTime(2026, 3, 1),
          isCancelled: false,
          summary: 'מיובא',
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 2),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(edits, 0);

      final Event created = await repository.create(_draftEvent());
      await repository.update(created.copyWith(title: 'שונה'));
      await repository.delete(created.id);
      await Future<void>.delayed(Duration.zero);
      expect(edits, 3);
    },
  );

  test('getDirtyForSync returns only events waiting to be pushed', () async {
    final Event created = await repository.create(_draftEvent());
    await repository.upsertFromGoogle(
      RemoteEventSnapshot(
        googleEventId: 'g-clean',
        etag: 'etag',
        updatedAt: DateTime(2026, 3, 1),
        isCancelled: false,
        summary: 'מיובא',
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 2),
      ),
    );

    final List<Event> dirty = await repository.getDirtyForSync();

    expect(dirty.map((Event e) => e.id), <String>[created.id]);
  });
}
