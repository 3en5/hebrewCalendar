// Tests for sync_engine.dart (M5a) against FakeGoogleCalendarApi +
// InMemoryEventRepository — no network, no Firebase (task brief §5). M5b
// adds the concurrency guard and permanent-vs-transient failure
// classification (read by `BackgroundSyncRunner`).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/google_calendar_api.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/data/sync/sync_engine.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_source.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/sync/remote_event_snapshot.dart';
import 'package:hebrew_calendar/domain/sync/sync_run_result.dart';
import 'package:hebrew_calendar/domain/sync/sync_state.dart';

import '../../test_support/fake_google_calendar_api.dart';

const HebrewDateEngine _engine = HebrewDateEngine();
final DateTime _fixedNow = DateTime(2026, 6, 15, 9);

Event _baseEvent({
  String title = 'אירוע',
  HebrewDate? hebrewDate,
  RecurrenceRule recurrence = const RecurrenceRule(),
}) => Event(
  id: '',
  ownerUid: 'uid-1',
  calendarId: 'default',
  title: title,
  hebrewDate:
      hebrewDate ??
      const HebrewDate(year: 5786, month: HebrewMonth.tevet, day: 10),
  recurrence: recurrence,
  createdAt: _fixedNow,
  updatedAt: _fixedNow,
);

void main() {
  late InMemoryEventRepository repository;
  late FakeGoogleCalendarApi api;
  late InMemorySyncSettingsStore settingsStore;
  late SyncEngine engine;

  setUp(() {
    repository = InMemoryEventRepository(now: () => _fixedNow);
    api = FakeGoogleCalendarApi();
    settingsStore = InMemorySyncSettingsStore();
    engine = SyncEngine(
      repository: repository,
      api: api,
      settingsStore: settingsStore,
      engine: _engine,
      now: () => _fixedNow,
    );
  });

  tearDown(() {
    repository.dispose();
  });

  test('sync disabled -> no API calls at all', () async {
    await repository.create(_baseEvent());

    final SyncRunResult result = await engine.runSync();

    expect(result.status, SyncStatus.idle);
    expect(api.requestAccessCallCount, 0);
    expect(api.insertedEvents, isEmpty);
    expect(api.deletedEventIds, isEmpty);
    expect((await settingsStore.load()).syncToken, isNull);
  });

  group('when enabled', () {
    setUp(() async {
      await settingsStore.setEnabled(true);
    });

    test(
      'first sync (no token) exports every dirty local event and imports every remote event',
      () async {
        final Event created = await repository.create(_baseEvent());
        expect(created.googleSync.dirty, isTrue);

        api.events['remote-external-1'] = RemoteEventSnapshot(
          googleEventId: 'remote-external-1',
          etag: 'etag-ext-1',
          updatedAt: _fixedNow,
          isCancelled: false,
          summary: 'חג חיצוני',
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 2),
          isAllDay: true,
        );

        final SyncRunResult result = await engine.runSync();

        expect(result.status, SyncStatus.idle);
        expect(api.insertedEvents, hasLength(1));
        expect(api.insertedEvents.single.hebcalEventId, created.id);

        final List<Event> all = await repository.getAllForSync();
        final Event exported = all.firstWhere((Event e) => e.id == created.id);
        expect(exported.googleSync.dirty, isFalse);
        expect(exported.googleSync.googleEventId, isNotNull);

        final Event imported = all.firstWhere(
          (Event e) => e.source == EventSource.google,
        );
        expect(imported.title, 'חג חיצוני');
        expect(imported.googleSync.googleEventId, 'remote-external-1');
      },
    );

    test(
      'incremental sync only applies the delta page and persists the new sync token',
      () async {
        await settingsStore.saveSyncToken('token-1');
        final Event existingImported = await repository.upsertFromGoogle(
          RemoteEventSnapshot(
            googleEventId: 'remote-1',
            etag: 'etag-1',
            updatedAt: _fixedNow.subtract(const Duration(days: 1)),
            isCancelled: false,
            summary: 'ישן',
            start: DateTime(2026, 6, 20),
            end: DateTime(2026, 6, 21),
          ),
        );

        api.scriptedPages.add(
          GoogleEventsPage(
            events: <RemoteEventSnapshot>[
              RemoteEventSnapshot(
                googleEventId: 'remote-1',
                etag: 'etag-2',
                updatedAt: _fixedNow,
                isCancelled: false,
                summary: 'עודכן',
                start: DateTime(2026, 6, 20),
                end: DateTime(2026, 6, 21),
              ),
            ],
            nextSyncToken: 'token-2',
          ),
        );

        final SyncRunResult result = await engine.runSync();

        expect(result.status, SyncStatus.idle);
        expect((await settingsStore.load()).syncToken, 'token-2');
        final Event? updated = await repository.getById(existingImported.id);
        expect(updated?.title, 'עודכן');
      },
    );

    test(
      'a 410 (expired sync token) triggers a full resync and stores the fresh token',
      () async {
        await settingsStore.saveSyncToken('stale-token');
        api.nextListError = const GoogleSyncTokenExpiredException();
        api.scriptedPages.add(
          const GoogleEventsPage(
            events: <RemoteEventSnapshot>[],
            nextSyncToken: 'brand-new-token',
          ),
        );

        final SyncRunResult result = await engine.runSync();

        expect(result.status, SyncStatus.idle);
        expect((await settingsStore.load()).syncToken, 'brand-new-token');
      },
    );

    test(
      'a 412 (etag mismatch) re-fetches and retries the push when the local edit is newer',
      () async {
        final Event created = await repository.create(_baseEvent());
        // Simulate a previous, already-synced state with a stale etag.
        await repository.updateSyncState(
          created.id,
          googleSync: const GoogleSyncState(
            googleEventId: 'remote-1',
            etag: 'stale-etag',
            dirty: true,
          ),
        );
        // The "server" has a newer etag but an older `updated` timestamp than
        // our local edit — local should win and the retry should succeed.
        api.events['remote-1'] = RemoteEventSnapshot(
          googleEventId: 'remote-1',
          etag: 'server-etag',
          updatedAt: _fixedNow.subtract(const Duration(hours: 1)),
          isCancelled: false,
          summary: 'ישן מהשרת',
          start: DateTime(2026, 6, 10),
          end: DateTime(2026, 6, 11),
        );

        final SyncRunResult result = await engine.runSync();

        expect(result.status, SyncStatus.idle, reason: result.errorMessage);
        final Event? afterSync = await repository.getById(created.id);
        expect(afterSync?.googleSync.dirty, isFalse);
        expect(afterSync?.googleSync.googleEventId, 'remote-1');
        // The retried patch should have gone through with the fresh etag.
        expect(api.events['remote-1']?.summary, created.title);
      },
    );

    test(
      'dedup-by-extendedProperties: never creates a duplicate export when local state is unknown',
      () async {
        final Event created = await repository.create(_baseEvent());
        final String occurrenceKey =
            '${created.hebrewDate.year}-${created.hebrewDate.month.name}-${created.hebrewDate.day}';
        // The remote side already has our own previous export (local sync
        // state was lost/never persisted) — a first/full sync must discover
        // it via extendedProperties instead of creating a second copy.
        api.events['already-exported'] = RemoteEventSnapshot(
          googleEventId: 'already-exported',
          etag: 'existing-etag',
          updatedAt: _fixedNow,
          isCancelled: false,
          summary: created.title,
          start: DateTime(2026, 6, 10),
          end: DateTime(2026, 6, 11),
          hebcalEventId: created.id,
          hebcalOccurrence: occurrenceKey,
        );

        await engine.runSync();

        expect(api.insertedEvents, isEmpty, reason: 'no duplicate create');
        expect(api.events, hasLength(1));
        final Event? afterSync = await repository.getById(created.id);
        expect(afterSync?.googleSync.googleEventId, 'already-exported');
      },
    );

    test(
      'deletion propagates app-side: a local delete removes the exported remote instance',
      () async {
        final Event created = await repository.create(_baseEvent());
        await engine.runSync();
        final Event? synced = await repository.getById(created.id);
        final String googleEventId = synced!.googleSync.googleEventId!;
        expect(api.events, contains(googleEventId));

        await repository.delete(created.id);
        await engine.runSync();

        expect(api.deletedEventIds, contains(googleEventId));
      },
    );

    test(
      'deletion propagates Google-side: a remote cancellation removes the imported local copy',
      () async {
        final Event imported = await repository.upsertFromGoogle(
          RemoteEventSnapshot(
            googleEventId: 'remote-imported',
            etag: 'etag-1',
            updatedAt: _fixedNow,
            isCancelled: false,
            summary: 'יבוא',
            start: DateTime(2026, 6, 20),
            end: DateTime(2026, 6, 21),
          ),
        );
        api.scriptedPages.add(
          GoogleEventsPage(
            events: <RemoteEventSnapshot>[
              RemoteEventSnapshot(
                googleEventId: 'remote-imported',
                etag: 'etag-2',
                updatedAt: _fixedNow.add(const Duration(minutes: 1)),
                isCancelled: true,
              ),
            ],
            nextSyncToken: 'token-after-delete',
          ),
        );

        await engine.runSync();

        expect(await repository.getById(imported.id), isNull);
      },
    );

    test(
      'a recurring dirty event exports one Google event per materialized instance',
      () async {
        final Event created = await repository.create(
          _baseEvent(
            hebrewDate: const HebrewDate(
              year: 5786,
              month: HebrewMonth.tevet,
              day: 1,
            ),
            recurrence: const RecurrenceRule(type: RecurrenceType.weekly),
          ),
        );

        await engine.runSync();

        // Rolling ~24-month export window from `_fixedNow` -> many weekly
        // instances; every insert must carry the same hebcalEventId with a
        // distinct hebcalOccurrence.
        expect(api.insertedEvents, isNotEmpty);
        expect(
          api.insertedEvents.every(
            (GoogleEventWrite w) => w.hebcalEventId == created.id,
          ),
          isTrue,
        );
        final Set<String> occurrenceKeys = api.insertedEvents
            .map((GoogleEventWrite w) => w.hebcalOccurrence)
            .toSet();
        expect(occurrenceKeys, hasLength(api.insertedEvents.length));

        final Event? afterSync = await repository.getById(created.id);
        expect(afterSync?.googleSync.dirty, isFalse);
        expect(afterSync?.googleInstanceSync.length, api.insertedEvents.length);
      },
    );

    test('a second runSync() call while one is in flight is a no-op', () async {
      final Completer<void> hold = Completer<void>();
      api.holdNextListUntil = hold.future;

      final Future<SyncRunResult> firstCall = engine.runSync();
      final SyncRunResult second = await engine.runSync();

      expect(second.wasConcurrentSkip, isTrue);
      expect(second.isError, isFalse);

      hold.complete();
      final SyncRunResult first = await firstCall;
      expect(first.wasConcurrentSkip, isFalse);
      expect(first.status, SyncStatus.idle);
    });

    test('a 403 (grant revoked) failure is classified permanent', () async {
      api.nextListError = const GoogleCalendarApiException(
        403,
        'insufficient permission',
      );

      final SyncRunResult result = await engine.runSync();

      expect(result.isError, isTrue);
      expect(result.permanent, isTrue);
      expect((await settingsStore.load()).lastErrorMessage, isNotNull);
    });

    test(
      'an unrecognized (e.g. network) failure is classified transient',
      () async {
        api.nextListError = Exception('socket closed');

        final SyncRunResult result = await engine.runSync();

        expect(result.isError, isTrue);
        expect(result.permanent, isFalse);
      },
    );

    test('a successful pass clears any previously stored error', () async {
      await settingsStore.saveLastError('stale error from a previous pass');

      final SyncRunResult result = await engine.runSync();

      expect(result.status, SyncStatus.idle);
      expect((await settingsStore.load()).lastErrorMessage, isNull);
    });
  });

  group('round #9', () {
    test('a big first import lands every remote event exactly once', () async {
      await settingsStore.setEnabled(true);
      for (int i = 0; i < 120; i++) {
        api.events['remote-big-$i'] = RemoteEventSnapshot(
          googleEventId: 'remote-big-$i',
          etag: 'etag-$i',
          updatedAt: _fixedNow,
          isCancelled: false,
          summary: 'אירוע $i',
          start: DateTime(2026, 7, 1).add(Duration(days: i)),
          end: DateTime(2026, 7, 1).add(Duration(days: i, hours: 1)),
          isAllDay: false,
        );
      }

      final SyncRunResult first = await engine.runSync();
      final SyncRunResult second = await engine.runSync();

      expect(first.isError, isFalse);
      expect(second.isError, isFalse);
      final List<Event> all = await repository.getAllForSync();
      expect(
        all.where((Event e) => e.source == EventSource.google),
        hasLength(120),
      );
    });

    test('a failure whose error cannot be saved is still reported', () async {
      final _FailingErrorStore store = _FailingErrorStore();
      await store.setEnabled(true);
      api.nextListError = StateError('boom');
      final SyncEngine failing = SyncEngine(
        repository: repository,
        api: api,
        settingsStore: store,
        engine: _engine,
        now: () => _fixedNow,
      );

      final SyncRunResult result = await failing.runSync();

      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('boom'));
    });
  });
}

/// A settings store whose error bookkeeping write fails (round #9: the
/// Security Rules rejected a new field, and the exception escaped the pass).
class _FailingErrorStore extends InMemorySyncSettingsStore {
  @override
  Future<void> saveLastError(String? message) async {
    throw StateError('permission-denied');
  }
}
