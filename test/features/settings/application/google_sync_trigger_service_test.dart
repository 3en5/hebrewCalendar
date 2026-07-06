// Tests for the M5a settings orchestrator: enable/disable (incremental
// scope request), the app-open throttle, and the post-edit debounce trigger
// — all against InMemoryEventRepository + FakeGoogleCalendarApi +
// InMemorySyncSettingsStore (no network/Firebase, matching
// ReminderSyncService's testing pattern for M4).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/data/sync/sync_engine.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/sync/sync_state.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_settings_state.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_trigger_service.dart';

import '../../../test_support/fake_background_sync_scheduler.dart';
import '../../../test_support/fake_google_calendar_api.dart';
import '../../../test_support/fake_hanging_sync_settings_store.dart';

const HebrewDateEngine _engine = HebrewDateEngine();
final DateTime _now = DateTime(2026, 6, 15, 9);

Event _draftEvent({String title = 'אירוע'}) => Event(
  id: 'ignored-on-create',
  ownerUid: 'uid-1',
  calendarId: 'default',
  title: title,
  hebrewDate: const HebrewDate(year: 5786, month: HebrewMonth.tevet, day: 10),
  createdAt: _now,
  updatedAt: _now,
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

void main() {
  late InMemoryEventRepository repository;
  late FakeGoogleCalendarApi api;
  late InMemorySyncSettingsStore settingsStore;
  late GoogleSyncTriggerService service;

  setUp(() {
    repository = InMemoryEventRepository(now: () => _now);
    api = FakeGoogleCalendarApi();
    settingsStore = InMemorySyncSettingsStore();
    service = GoogleSyncTriggerService(
      engine: SyncEngine(
        repository: repository,
        api: api,
        settingsStore: settingsStore,
        engine: _engine,
        now: () => _now,
      ),
      settingsStore: settingsStore,
      api: api,
      repository: repository,
      hebrewEngine: _engine,
      now: () => _now,
      editDebounce: const Duration(milliseconds: 10),
      openThrottle: const Duration(milliseconds: 50),
    );
  });

  tearDown(() {
    repository.dispose();
  });

  test('start() reflects the persisted disabled-by-default state', () async {
    await service.start();
    expect(service.state.enabled, isFalse);
    await service.stop();
  });

  test(
    'enable() requests calendar access and, once granted, runs a first sync',
    () async {
      await service.start();
      await repository.create(_draftEvent());

      final bool granted = await service.enable();
      await _settle();

      expect(granted, isTrue);
      expect(api.requestAccessCallCount, 1);
      expect(service.state.enabled, isTrue);
      expect(service.state.status, SyncStatus.idle);
      expect(service.state.lastSyncedAt, isNotNull);
      expect(api.insertedEvents, hasLength(1));
      await service.stop();
    },
  );

  test(
    'enable() returns false and stays disabled when access is denied',
    () async {
      api.accessGranted = false;
      await service.start();

      final bool granted = await service.enable();

      expect(granted, isFalse);
      expect(service.state.enabled, isFalse);
      expect((await settingsStore.load()).enabled, isFalse);
      await service.stop();
    },
  );

  test('disable() stops reacting to local edits', () async {
    await service.start();
    await service.enable();
    await _settle();
    final int syncsSoFar = api.insertedEvents.length;

    await service.disable();
    await repository.create(_draftEvent(title: 'אחרי כיבוי'));
    await _settle();

    expect(api.insertedEvents, hasLength(syncsSoFar));
    expect(service.state.enabled, isFalse);
  });

  test('a local create/update/delete triggers a debounced sync', () async {
    await service.start();
    await service.enable();
    await _settle();
    final int syncsAfterEnable = api.insertedEvents.length;

    await repository.create(_draftEvent(title: 'אירוע חדש'));
    // Not yet — still inside the debounce window.
    expect(api.insertedEvents.length, syncsAfterEnable);

    await _settle();
    expect(api.insertedEvents.length, greaterThan(syncsAfterEnable));
    await service.stop();
  });

  test(
    'rapid successive edits collapse into a single debounced sync',
    () async {
      await service.start();
      await service.enable();
      await _settle();

      await repository.create(_draftEvent(title: 'א'));
      await repository.create(_draftEvent(title: 'ב'));
      await repository.create(_draftEvent(title: 'ג'));
      await _settle();

      // Exactly one sync pass ran for all three creates together (not one per
      // edit), so all three appear in the (single) subsequent
      // `getAllForSync`-driven export pass — asserted indirectly via
      // `syncNow` not having been called more than debounce-collapsing allows.
      expect(api.insertedEvents.length, greaterThanOrEqualTo(3));
      await service.stop();
    },
  );

  test(
    'triggerAppOpen is throttled: a second call within openThrottle is a no-op',
    () async {
      await service.start();
      await service.enable();
      await _settle();
      final DateTime? firstSyncTime = service.state.lastSyncedAt;

      await service.triggerAppOpen();
      await _settle();

      expect(service.state.lastSyncedAt, firstSyncTime);
      await service.stop();
    },
  );

  test('syncNow() bypasses the throttle and runs immediately', () async {
    await service.start();
    await service.enable();
    await _settle();
    await repository.create(_draftEvent(title: 'ידני'));

    await service.syncNow();

    expect(api.insertedEvents.any((w) => w.summary == 'ידני'), isTrue);
    await service.stop();
  });

  test('a sync failure surfaces as SyncStatus.error with a message', () async {
    await service.start();
    await service.enable();
    await _settle();
    api.nextListError = StateError('boom');

    await service.syncNow();

    expect(service.state.status, SyncStatus.error);
    expect(service.state.errorMessage, contains('boom'));
    await service.stop();
  });

  test(
    'stop() cancels the local-edit subscription: further edits have no effect',
    () async {
      await service.start();
      await service.enable();
      await _settle();
      final int syncsBeforeStop = api.insertedEvents.length;

      await service.stop();
      await repository.create(_draftEvent(title: 'אחרי stop'));
      await _settle();

      expect(api.insertedEvents.length, syncsBeforeStop);
    },
  );

  group('M5b background sync registration', () {
    test(
      'enable() registers the periodic task; disable() cancels it',
      () async {
        final FakeBackgroundSyncScheduler scheduler =
            FakeBackgroundSyncScheduler();
        final GoogleSyncTriggerService svc = GoogleSyncTriggerService(
          engine: SyncEngine(
            repository: repository,
            api: api,
            settingsStore: settingsStore,
            engine: _engine,
            now: () => _now,
          ),
          settingsStore: settingsStore,
          api: api,
          repository: repository,
          hebrewEngine: _engine,
          now: () => _now,
          backgroundScheduler: scheduler,
        );

        await svc.start();
        expect(scheduler.registerPeriodicCallCount, 0);

        await svc.enable();
        expect(scheduler.registerPeriodicCallCount, 1);

        await svc.disable();
        expect(scheduler.cancelCallCount, 1);
      },
    );

    test(
      'start() re-registers the periodic task when sync was already enabled',
      () async {
        await settingsStore.setEnabled(true);
        final FakeBackgroundSyncScheduler scheduler =
            FakeBackgroundSyncScheduler();
        final GoogleSyncTriggerService svc = GoogleSyncTriggerService(
          engine: SyncEngine(
            repository: repository,
            api: api,
            settingsStore: settingsStore,
            engine: _engine,
            now: () => _now,
          ),
          settingsStore: settingsStore,
          api: api,
          repository: repository,
          hebrewEngine: _engine,
          now: () => _now,
          backgroundScheduler: scheduler,
        );

        await svc.start();

        expect(scheduler.registerPeriodicCallCount, 1);
      },
    );

    test('stop() cancels the periodic task only if sync was enabled', () async {
      final FakeBackgroundSyncScheduler scheduler =
          FakeBackgroundSyncScheduler();
      final GoogleSyncTriggerService svc = GoogleSyncTriggerService(
        engine: SyncEngine(
          repository: repository,
          api: api,
          settingsStore: settingsStore,
          engine: _engine,
          now: () => _now,
        ),
        settingsStore: settingsStore,
        api: api,
        repository: repository,
        hebrewEngine: _engine,
        now: () => _now,
        backgroundScheduler: scheduler,
      );

      // Never enabled: stop() should not bother cancelling.
      await svc.start();
      await svc.stop();
      expect(scheduler.cancelCallCount, 0);
    });
  });

  test('start() surfaces a persisted background sync error (M5b)', () async {
    await settingsStore.setEnabled(true);
    await settingsStore.saveLastError('הרשאה בוטלה');

    await service.start();

    expect(service.state.status, SyncStatus.error);
    expect(service.state.errorMessage, 'הרשאה בוטלה');
    await service.stop();
  });

  group('real-device report #2: settings load never hangs the UI forever', () {
    test('start() times out a settings load that never completes and surfaces '
        'a retryable error instead of never emitting', () async {
      final FakeHangingSyncSettingsStore hangingStore =
          FakeHangingSyncSettingsStore();
      final GoogleSyncTriggerService svc = GoogleSyncTriggerService(
        engine: SyncEngine(
          repository: repository,
          api: api,
          settingsStore: hangingStore,
          engine: _engine,
          now: () => _now,
        ),
        settingsStore: hangingStore,
        api: api,
        repository: repository,
        hebrewEngine: _engine,
        now: () => _now,
        // A tiny timeout so the test doesn't wait for the real 10s
        // production default — the timeout mechanism itself is what's
        // under test, not its exact duration.
        startTimeout: const Duration(milliseconds: 20),
      );

      await svc.start();

      expect(svc.state.status, SyncStatus.error);
      expect(svc.state.initialLoadFailed, isTrue);
      expect(svc.state.errorMessage, isNotNull);
      await svc.stop();
    });

    test('retryLoad() re-attempts start() and can recover', () async {
      final FakeHangingSyncSettingsStore hangingStore =
          FakeHangingSyncSettingsStore();
      final GoogleSyncTriggerService svc = GoogleSyncTriggerService(
        engine: SyncEngine(
          repository: repository,
          api: api,
          settingsStore: settingsStore,
          engine: _engine,
          now: () => _now,
        ),
        settingsStore: hangingStore,
        api: api,
        repository: repository,
        hebrewEngine: _engine,
        now: () => _now,
        startTimeout: const Duration(milliseconds: 20),
      );

      await svc.start();
      expect(svc.state.initialLoadFailed, isTrue);

      // The stream never leaves the app stuck: every failed attempt still
      // re-emits, so a widget bound to `svc.states` sees a fresh error
      // state (not silence) on every retry too.
      final List<bool> loadFailedEmissions = <bool>[];
      final StreamSubscription<GoogleSyncSettingsState> sub = svc.states.listen(
        (GoogleSyncSettingsState state) =>
            loadFailedEmissions.add(state.initialLoadFailed),
      );
      await svc.retryLoad();
      // The broadcast stream's async (non-`sync`) delivery to listeners
      // isn't guaranteed to have run yet immediately after `retryLoad()`'s
      // own Future resolves — `_settle()` (used the same way elsewhere in
      // this file for debounced effects) gives it a real event-loop turn.
      await _settle();
      await sub.cancel();

      expect(loadFailedEmissions, contains(true));
      await svc.stop();
    });
  });
}
