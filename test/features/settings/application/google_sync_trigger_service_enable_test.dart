// Device-feedback round #3 ("the settings screen's enable toggle silently
// does nothing"): tests for GoogleSyncTriggerService.enable()'s handling of
// GoogleCalendarApi.requestAccess() failures, as distinct from a plain
// decline/cancel — split out from google_sync_trigger_service_test.dart
// (RULES.md §2, 500-line file limit) since it's a distinct responsibility
// (the enable-flow's error/busy-state handling) rather than "part 2" of the
// same tests.
//
// Confirmed root cause (docs/LESSONS.md): a restored FirebaseAuth session
// never runs the interactive sign-in flow that initializes
// `GoogleSignIn.instance` (`google_sign_in` v7's one-time `initialize()`
// contract) — so the first other code to touch it, e.g. tapping "enable
// sync" in Settings, could throw. Previously `enable()` had no try/catch at
// all around `_api.requestAccess()`, so that exception propagated out
// through `settings_screen.dart`'s `unawaited(...)` call site and was
// silently dropped by the app's global `runZonedGuarded` handler — the
// switch never flipped, no snackbar, no dialog. These tests assert the
// fixed contract: every path through `enable()` ends in an explicit,
// UI-visible state update.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/data/sync/sync_engine.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/sync/sync_settings_store.dart';
import 'package:hebrew_calendar/domain/sync/sync_state.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_trigger_service.dart';

import '../../../test_support/fake_google_calendar_api.dart';

const HebrewDateEngine _engine = HebrewDateEngine();
final DateTime _now = DateTime(2026, 6, 15, 9);

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
      now: () => _now,
    );
  });

  tearDown(() {
    repository.dispose();
  });

  test('a genuine requestAccess() failure surfaces as SyncStatus.error with '
      'the real error text — never silently swallowed', () async {
    await service.start();
    api.nextRequestAccessError = StateError(
      'No signed-in Google account available for Calendar sync.',
    );

    final bool granted = await service.enable();

    expect(granted, isFalse);
    expect(service.state.enabled, isFalse);
    expect(service.state.status, SyncStatus.error);
    expect(service.state.errorMessage, contains('No signed-in Google account'));
    expect((await settingsStore.load()).enabled, isFalse);
    await service.stop();
  });

  test('a plain decline (requestAccess() returns false, not an exception) '
      'stays quiet — idle, no error message', () async {
    await service.start();
    api.accessGranted = false;

    final bool granted = await service.enable();

    expect(granted, isFalse);
    expect(service.state.enabled, isFalse);
    expect(service.state.status, SyncStatus.idle);
    expect(service.state.errorMessage, isNull);
    await service.stop();
  });

  test('authorizing is true only while requestAccess() is in flight, and false '
      'again once enable() resolves (success path)', () async {
    await service.start();
    final Completer<void> gate = Completer<void>();
    api.holdRequestAccessUntil = gate.future;

    final Future<bool> enableFuture = service.enable();
    // Let enable() reach the in-flight requestAccess() await point.
    await Future<void>.delayed(Duration.zero);
    expect(service.state.authorizing, isTrue);

    gate.complete();
    final bool granted = await enableFuture;

    expect(granted, isTrue);
    expect(service.state.authorizing, isFalse);
    await service.stop();
  });

  test(
    'authorizing is reset to false after a requestAccess() failure too',
    () async {
      await service.start();
      final Completer<void> gate = Completer<void>();
      api.holdRequestAccessUntil = gate.future;
      api.nextRequestAccessError = StateError('boom');

      final Future<bool> enableFuture = service.enable();
      await Future<void>.delayed(Duration.zero);
      expect(service.state.authorizing, isTrue);

      gate.complete();
      final bool granted = await enableFuture;

      expect(granted, isFalse);
      expect(service.state.authorizing, isFalse);
      await service.stop();
    },
  );

  test('a previous error is cleared once enable() succeeds', () async {
    await service.start();
    api.nextRequestAccessError = StateError('boom');
    await service.enable();
    expect(service.state.status, SyncStatus.error);

    final bool granted = await service.enable();

    expect(granted, isTrue);
    // enable()'s own state update (which clears the previous error) is
    // synchronous, but it also kicks off `unawaited(syncNow())` — whose
    // first synchronous step flips `status` to `syncing` before this test
    // gets a chance to observe it. `errorMessage` is what actually
    // matters here (cleared before syncNow ever runs); settle first so
    // the immediately-following sync pass has time to finish before
    // checking `status` too.
    expect(service.state.errorMessage, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(service.state.status, SyncStatus.idle);
    await service.stop();
  });

  test('disable() surfaces a settings-store write failure instead of '
      'silently leaving the toggle stuck', () async {
    await service.start();
    await service.enable();
    final FailingSettingsStoreWrite failingStore = FailingSettingsStoreWrite(
      settingsStore,
    );
    final GoogleSyncTriggerService svc = GoogleSyncTriggerService(
      engine: SyncEngine(
        repository: repository,
        api: api,
        settingsStore: failingStore,
        engine: _engine,
        now: () => _now,
      ),
      settingsStore: failingStore,
      api: api,
      repository: repository,
      now: () => _now,
    );
    await svc.start();
    await svc.enable();

    await svc.disable();

    expect(svc.state.status, SyncStatus.error);
    expect(svc.state.errorMessage, contains('disable boom'));
    await svc.stop();
  });
}

/// Wraps a real [InMemorySyncSettingsStore] but makes [setEnabled] throw
/// when asked to disable — used to prove `disable()` surfaces a store
/// failure instead of leaving an unexplained stuck toggle.
class FailingSettingsStoreWrite implements SyncSettingsStore {
  FailingSettingsStoreWrite(this._delegate);

  final InMemorySyncSettingsStore _delegate;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      throw StateError('disable boom');
    }
    return _delegate.setEnabled(enabled);
  }

  @override
  Future<void> saveLastError(String? message) =>
      _delegate.saveLastError(message);

  @override
  Future<void> saveSyncToken(String? token) => _delegate.saveSyncToken(token);

  @override
  Future<void> saveLastSyncedAt(DateTime at) => _delegate.saveLastSyncedAt(at);

  @override
  Future<SyncSettings> load() => _delegate.load();
}
