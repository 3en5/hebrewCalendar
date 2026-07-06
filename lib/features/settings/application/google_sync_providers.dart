/// Riverpod wiring for M5a's Google Calendar sync feature (ARCHITECTURE.md
/// §5), mirroring `reminder_providers.dart`'s role for M4: constructs the
/// real [SyncEngine]/[GoogleSyncTriggerService] from the app's existing
/// providers. The orchestrator itself
/// (`google_sync_trigger_service.dart`) and everything it calls into stay
/// Riverpod-free and are tested directly with fakes — this file only exists
/// to hand them real dependencies and hook them into provider lifecycles.
library;

import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/sync/firestore_sync_settings_store.dart';
import '../../../data/sync/google_calendar_api.dart';
import '../../../data/sync/google_calendar_api_impl.dart';
import '../../../data/sync/in_memory_sync_settings_store.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../domain/auth/app_user.dart';
import '../../../domain/sync/sync_settings_store.dart';
import '../../auth/application/auth_providers.dart';
import '../../calendar/application/hebrew_date_engine_provider.dart';
import '../../event_editor/application/event_repository_provider.dart';
import 'background_sync_scheduler.dart';
import 'google_sync_settings_state.dart';
import 'google_sync_trigger_service.dart';

/// The app's single [GoogleCalendarApi]. Not `autoDispose` (matches
/// `notificationSchedulerProvider`) — its underlying plugin/HTTP client
/// should outlive any one screen. Overridden with a `FakeGoogleCalendarApi`
/// in every widget test that renders the settings screen.
final Provider<GoogleCalendarApi> googleCalendarApiProvider =
    Provider<GoogleCalendarApi>((Ref ref) => GoogleCalendarApiImpl());

/// The signed-in user's [SyncSettingsStore], or an in-memory fallback
/// before sign-in settles — mirrors `eventRepositoryProvider`'s branch on
/// [currentUserProvider].
final Provider<SyncSettingsStore> syncSettingsStoreProvider =
    Provider<SyncSettingsStore>((Ref ref) {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null) {
        return InMemorySyncSettingsStore();
      }
      return FirestoreSyncSettingsStore(uid: user.uid);
    });

/// M5b: registers/cancels the periodic WorkManager background sync task.
/// Overridden with a fake in every test that exercises `enable`/`disable`
/// through the real provider tree (`settings_screen_test.dart`) so those
/// tests never touch the real plugin (which has no channel handler under
/// `flutter test` — mirrors `notificationSchedulerProvider`'s role for M4,
/// see docs/LESSONS.md).
final Provider<BackgroundSyncScheduler> backgroundSyncSchedulerProvider =
    Provider<BackgroundSyncScheduler>(
      (Ref ref) => const WorkmanagerBackgroundSyncScheduler(),
    );

/// Bounds `GoogleSyncTriggerService.start()`'s initial settings load
/// (real-device report #2 — see docs/LESSONS.md). Overridden with a much
/// shorter duration in tests that simulate a settings load which never
/// completes, so those tests don't have to wait out the real 10s default.
final Provider<Duration> syncStartTimeoutProvider = Provider<Duration>(
  (Ref ref) => const Duration(seconds: 10),
);

/// Not `autoDispose`: a sync engine, like the repository it wraps, is a
/// data-layer service rather than screen-scoped UI state.
final Provider<SyncEngine> syncEngineProvider = Provider<SyncEngine>((Ref ref) {
  return SyncEngine(
    repository: ref.watch(eventRepositoryProvider),
    api: ref.watch(googleCalendarApiProvider),
    settingsStore: ref.watch(syncSettingsStoreProvider),
    engine: ref.watch(hebrewDateEngineProvider),
  );
});

/// Connects the signed-in user's local edits to sync triggers.
///
/// `autoDispose`: started from the settings screen (and kept alive by
/// `CalendarShellScreen` watching it so the app-open/post-edit triggers work
/// even while the settings screen itself isn't on screen) and torn down —
/// every subscription/timer cancelled — once nothing watches it anymore
/// (RULES.md §6.1/§6.2), i.e. on sign-out.
final Provider<GoogleSyncTriggerService> googleSyncTriggerServiceProvider =
    Provider.autoDispose<GoogleSyncTriggerService>((Ref ref) {
      final GoogleSyncTriggerService service = GoogleSyncTriggerService(
        engine: ref.watch(syncEngineProvider),
        settingsStore: ref.watch(syncSettingsStoreProvider),
        api: ref.watch(googleCalendarApiProvider),
        repository: ref.watch(eventRepositoryProvider),
        hebrewEngine: ref.watch(hebrewDateEngineProvider),
        backgroundScheduler: ref.watch(backgroundSyncSchedulerProvider),
        startTimeout: ref.watch(syncStartTimeoutProvider),
      );
      // `start()` must finish loading the persisted enabled flag before
      // `triggerAppOpen()` can meaningfully check it.
      unawaited(service.start().then((_) => service.triggerAppOpen()));
      ref.onDispose(() => unawaited(service.stop()));
      return service;
    });

/// The reactive [GoogleSyncSettingsState] the settings screen renders.
final StreamProvider<GoogleSyncSettingsState> googleSyncStateProvider =
    StreamProvider.autoDispose<GoogleSyncSettingsState>((Ref ref) {
      final GoogleSyncTriggerService service = ref.watch(
        googleSyncTriggerServiceProvider,
      );
      return service.states;
    });
