/// Riverpod wiring for M5a's Google Calendar sync feature (ARCHITECTURE.md
/// §5), mirroring `reminder_providers.dart`'s role for M4: constructs the
/// real [SyncEngine]/[GoogleSyncTriggerService] from the app's existing
/// providers. The orchestrator itself
/// (`google_sync_trigger_service.dart`) and everything it calls into stay
/// Riverpod-free and are tested directly with fakes — this file only exists
/// to hand them real dependencies and hook them into provider lifecycles.
library;

import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/in_memory_event_repository.dart';
import '../../../data/sync/firestore_sync_settings_store.dart';
import '../../../data/sync/google_calendar_api.dart';
import '../../../data/sync/google_calendar_api_impl.dart';
import '../../../data/sync/in_memory_sync_settings_store.dart';
import '../../../data/sync/full_resync_flag.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../domain/auth/app_user.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../domain/sync/remote_event_snapshot.dart';
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
    fullResync: const PrefsFullResyncFlag(),
  );
});

/// Connects the signed-in user's local edits to sync triggers.
///
/// `autoDispose`: started from the settings screen (and kept alive by
/// `CalendarShellScreen` watching it so the app-open/post-edit triggers work
/// even while the settings screen itself isn't on screen) and torn down —
/// every subscription/timer cancelled — once nothing watches it anymore
/// (RULES.md §6.1/§6.2), i.e. on sign-out.
///
/// Real-device report #2, round 2: the *construction* of this service's
/// dependencies (every `ref.watch` below) is wrapped in `try`/`catch` too,
/// not just `start()`'s internal Firestore-read timeout (round 1's fix) —
/// a plain (non-async) `Provider` that throws during build rethrows
/// synchronously to every caller of `ref.watch`/`ref.read` on it, which
/// would crash this screen's build outright rather than showing the retry
/// card. On a construction failure, a service is still built (with inert
/// placeholder dependencies it will never actually call) so the rest of the
/// app keeps a valid, non-throwing provider to read from — `start()`
/// recognizes `constructionError` and emits the failure immediately.
final Provider<GoogleSyncTriggerService> googleSyncTriggerServiceProvider =
    Provider.autoDispose<GoogleSyncTriggerService>((Ref ref) {
      debugPrint(
        '[sync-settings] googleSyncTriggerServiceProvider build start',
      );
      final GoogleSyncTriggerService service = _buildTriggerService(ref);
      // `start()` must finish loading the persisted enabled flag before
      // `triggerAppOpen()` can meaningfully check it.
      unawaited(service.start().then((_) => service.triggerAppOpen()));
      ref.onDispose(() => unawaited(service.stop()));
      return service;
    });

/// Builds the real [GoogleSyncTriggerService] from its provider
/// dependencies, or — if any of that construction throws synchronously —
/// a service built from safe in-memory placeholders and a
/// `constructionError`, which makes [GoogleSyncTriggerService.start] emit
/// the failure immediately instead of ever touching those placeholders.
GoogleSyncTriggerService _buildTriggerService(Ref ref) {
  try {
    return GoogleSyncTriggerService(
      engine: ref.watch(syncEngineProvider),
      settingsStore: ref.watch(syncSettingsStoreProvider),
      api: ref.watch(googleCalendarApiProvider),
      repository: ref.watch(eventRepositoryProvider),
      backgroundScheduler: ref.watch(backgroundSyncSchedulerProvider),
      startTimeout: ref.watch(syncStartTimeoutProvider),
    );
  } catch (error, stackTrace) {
    debugPrint(
      '[sync-settings] googleSyncTriggerServiceProvider construction '
      'failed: $error\n$stackTrace',
    );
    const HebrewDateEngine fallbackEngine = HebrewDateEngine();
    final _UnavailableGoogleCalendarApi fallbackApi =
        _UnavailableGoogleCalendarApi();
    final InMemoryEventRepository fallbackRepository =
        InMemoryEventRepository();
    final InMemorySyncSettingsStore fallbackStore = InMemorySyncSettingsStore();
    return GoogleSyncTriggerService(
      engine: SyncEngine(
        repository: fallbackRepository,
        api: fallbackApi,
        settingsStore: fallbackStore,
        engine: fallbackEngine,
      ),
      settingsStore: fallbackStore,
      api: fallbackApi,
      repository: fallbackRepository,
      constructionError: error,
    );
  }
}

/// The reactive [GoogleSyncSettingsState] the settings screen renders.
///
/// Real-device report #2, round 2's actual root cause (see
/// `GoogleSyncTriggerService.watchState`'s doc): this used to expose the
/// raw `service.states` broadcast stream directly, which only delivers
/// events emitted *after* subscribing. Since `CalendarShellScreen` keeps
/// the service (and `start()`) alive from app-open, but this
/// `StreamProvider.autoDispose` only starts listening once the settings
/// screen is actually opened — often well after `start()`'s one and only
/// `_emit()` already fired — the settings screen was subscribing to a
/// stream whose historical event was already gone, stuck in
/// `AsyncValue.loading()` forever regardless of `start()`'s own
/// try/catch/timeout (round 1's fix, which fires correctly but reaches
/// nobody). `watchState()` fixes this by replaying the current state to
/// every new subscriber.
final StreamProvider<GoogleSyncSettingsState> googleSyncStateProvider =
    StreamProvider.autoDispose<GoogleSyncSettingsState>((Ref ref) {
      debugPrint('[sync-settings] googleSyncStateProvider build start');
      final GoogleSyncTriggerService service = ref.watch(
        googleSyncTriggerServiceProvider,
      );
      return service.watchState();
    });

/// Placeholder [GoogleCalendarApi] used only when the real
/// `googleCalendarApiProvider` fails to construct (see
/// `googleSyncTriggerServiceProvider` above) — every method fails loudly.
/// It is never actually reachable from the UI: while
/// `GoogleSyncSettingsState.initialLoadFailed` is true (which this
/// placeholder always causes, via `constructionError`), the settings
/// screen only renders the retry card, never the switch/sync-now controls
/// that would call into this.
class _UnavailableGoogleCalendarApi implements GoogleCalendarApi {
  static Never _unavailable() =>
      throw StateError('Google Calendar API is unavailable.');

  @override
  Future<bool> requestAccess() async => _unavailable();

  @override
  Future<GoogleEventsPage> listChangedEvents({String? syncToken}) async =>
      _unavailable();

  @override
  Future<RemoteEventSnapshot> getEvent(String googleEventId) async =>
      _unavailable();

  @override
  Future<RemoteEventSnapshot> insertEvent(GoogleEventWrite event) async =>
      _unavailable();

  @override
  Future<RemoteEventSnapshot> patchEvent({
    required String googleEventId,
    required String? etag,
    required GoogleEventWrite event,
  }) async => _unavailable();

  @override
  Future<void> deleteEvent({
    required String googleEventId,
    String? etag,
  }) async => _unavailable();
}
