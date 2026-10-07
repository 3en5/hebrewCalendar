// Tests for BackgroundSyncRunner (M5b): the pure decision layer behind the
// WorkManager callback dispatcher. Every dependency is a fake — no
// Firebase/Google Sign-In/WorkManager involved (docs/LESSONS.md: no Android
// SDK/emulator in this dev environment).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/google_calendar_api.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/data/sync/sync_engine.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/features/settings/application/background_sync_runner.dart';

import '../../../test_support/fake_google_calendar_api.dart';

const HebrewDateEngine _engine = HebrewDateEngine();
final DateTime _now = DateTime(2026, 6, 15, 9);

void main() {
  late InMemoryEventRepository repository;
  late FakeGoogleCalendarApi api;
  late InMemorySyncSettingsStore settingsStore;
  int engineFactoryCallCount = 0;

  SyncEngine buildEngine() {
    engineFactoryCallCount++;
    return SyncEngine(
      repository: repository,
      api: api,
      settingsStore: settingsStore,
      engine: _engine,
      now: () => _now,
    );
  }

  BackgroundSyncRunner buildRunner({
    required bool signedIn,
    Duration timeout = const Duration(minutes: 4),
  }) {
    return BackgroundSyncRunner(
      isSignedIn: () async => signedIn,
      settingsStore: settingsStore,
      engineFactory: buildEngine,
      now: () => _now,
      timeout: timeout,
    );
  }

  setUp(() {
    repository = InMemoryEventRepository(now: () => _now);
    api = FakeGoogleCalendarApi();
    settingsStore = InMemorySyncSettingsStore();
    engineFactoryCallCount = 0;
  });

  tearDown(() {
    repository.dispose();
  });

  test(
    'not signed in -> permanent skip, without ever building an engine',
    () async {
      await settingsStore.setEnabled(true);
      final BackgroundSyncRunner runner = buildRunner(signedIn: false);

      final BackgroundSyncOutcome outcome = await runner.run();

      expect(outcome, BackgroundSyncOutcome.permanentSkip);
      expect(engineFactoryCallCount, 0);
    },
  );

  test(
    'sync disabled -> permanent skip, without ever building an engine',
    () async {
      // settingsStore starts disabled by default.
      final BackgroundSyncRunner runner = buildRunner(signedIn: true);

      final BackgroundSyncOutcome outcome = await runner.run();

      expect(outcome, BackgroundSyncOutcome.permanentSkip);
      expect(engineFactoryCallCount, 0);
    },
  );

  test(
    'happy path: signed in + enabled runs the engine and updates lastSyncedAt',
    () async {
      await settingsStore.setEnabled(true);
      final BackgroundSyncRunner runner = buildRunner(signedIn: true);

      final BackgroundSyncOutcome outcome = await runner.run();

      expect(outcome, BackgroundSyncOutcome.success);
      expect(engineFactoryCallCount, 1);
      expect((await settingsStore.load()).lastSyncedAt, _now);
      expect(runner.lastAttemptAt, _now);
    },
  );

  test('a transient (unrecognized) engine failure -> retry', () async {
    await settingsStore.setEnabled(true);
    api.nextListError = Exception('network unreachable');
    final BackgroundSyncRunner runner = buildRunner(signedIn: true);

    final BackgroundSyncOutcome outcome = await runner.run();

    expect(outcome, BackgroundSyncOutcome.retry);
  });

  test(
    'a permanent (grant revoked, HTTP 403) engine failure -> permanent skip, sync stays enabled',
    () async {
      await settingsStore.setEnabled(true);
      api.nextListError = const GoogleCalendarApiException(
        403,
        'insufficient permission',
      );
      final BackgroundSyncRunner runner = buildRunner(signedIn: true);

      final BackgroundSyncOutcome outcome = await runner.run();

      expect(outcome, BackgroundSyncOutcome.permanentSkip);
      // M5b task brief §5: a permanent failure does NOT disable sync — it
      // only surfaces as an error in the settings store (SyncEngine already
      // persists it via `saveLastError`), so the user notices and can
      // re-authorize instead of silently losing background sync.
      expect((await settingsStore.load()).enabled, isTrue);
      expect((await settingsStore.load()).lastErrorMessage, isNotNull);
    },
  );

  test('a hard timeout -> retry', () async {
    await settingsStore.setEnabled(true);
    // Never completes within the test's lifetime — `run()` must give up
    // after `timeout` rather than hang.
    api.holdNextListUntil = Completer<void>().future;
    final BackgroundSyncRunner runner = buildRunner(
      signedIn: true,
      timeout: const Duration(milliseconds: 20),
    );

    final BackgroundSyncOutcome outcome = await runner.run();

    expect(outcome, BackgroundSyncOutcome.retry);
  });

  test(
    'a concurrent-skip result (engine already in flight) -> permanent skip',
    () async {
      await settingsStore.setEnabled(true);
      final SyncEngine sharedEngine = SyncEngine(
        repository: repository,
        api: api,
        settingsStore: settingsStore,
        engine: _engine,
        now: () => _now,
      );
      final Completer<void> hold = Completer<void>();
      api.holdNextListUntil = hold.future;
      // Start a first pass directly on the shared engine and leave it in
      // flight, then let the runner's own call observe the guard.
      final Future<void> firstPass = sharedEngine.runSync();
      final BackgroundSyncRunner runner = BackgroundSyncRunner(
        isSignedIn: () async => true,
        settingsStore: settingsStore,
        engineFactory: () => sharedEngine,
        now: () => _now,
      );

      final BackgroundSyncOutcome outcome = await runner.run();

      expect(outcome, BackgroundSyncOutcome.permanentSkip);
      hold.complete();
      await firstPass;
    },
  );
}
