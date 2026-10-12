import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../data/sync/google_calendar_api.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../domain/event/event_repository.dart';
import '../../../domain/sync/sync_progress.dart';
import '../../../domain/sync/sync_run_result.dart';
import '../../../domain/sync/sync_settings_store.dart';
import '../../../domain/sync/sync_state.dart';
import '../../../l10n/app_localizations_he.dart';
import 'background_sync_scheduler.dart';
import 'google_sync_settings_state.dart';

/// The M5a settings orchestrator (task brief §3), following the same
/// pattern as `reminder_sync_service.dart`: Riverpod-free, depends only on
/// abstract domain interfaces plus [SyncEngine]/[GoogleCalendarApi] (data
/// layer, but themselves fakeable), so it's fully testable with fakes. The
/// Riverpod wiring that constructs it with real dependencies and exposes it
/// to widgets lives in `google_sync_providers.dart`.
///
/// Two sync triggers (task brief §3):
/// - [triggerAppOpen], called once when the calendar shell mounts —
///   debounced to at most once every [openThrottle] (default 5 minutes), so
///   repeatedly backgrounding/foregrounding the app doesn't hammer the API.
/// - a subscription to the same broad occurrence range the export window
///   covers — any local create/update/delete re-emits on it (the same
///   `EventRepository` change-notification mechanism
///   `reminder_sync_service.dart` relies on), debounced [editDebounce]
///   (default 30 seconds) before calling [syncNow].
class GoogleSyncTriggerService {
  GoogleSyncTriggerService({
    required SyncEngine engine,
    required SyncSettingsStore settingsStore,
    required GoogleCalendarApi api,
    required EventRepository repository,
    DateTime Function() now = DateTime.now,
    Duration editDebounce = const Duration(seconds: 30),
    Duration openThrottle = const Duration(minutes: 5),
    Duration startTimeout = const Duration(seconds: 10),
    BackgroundSyncScheduler backgroundScheduler =
        const NoopBackgroundSyncScheduler(),
    Object? constructionError,
  }) : _engine = engine,
       _settingsStore = settingsStore,
       _api = api,
       _repository = repository,
       _now = now,
       _editDebounce = editDebounce,
       _openThrottle = openThrottle,
       _startTimeout = startTimeout,
       _backgroundScheduler = backgroundScheduler,
       _constructionError = constructionError;

  final SyncEngine _engine;
  final SyncSettingsStore _settingsStore;
  final GoogleCalendarApi _api;
  final EventRepository _repository;
  final DateTime Function() _now;
  final Duration _editDebounce;
  final Duration _openThrottle;

  /// Real-device report #2: `start()`'s initial `_settingsStore.load()`
  /// (a Firestore read) could previously hang or throw silently (see
  /// `docs/LESSONS.md`) with nothing ever calling `_emit()` — leaving the
  /// settings screen's `StreamProvider` stuck in `AsyncValue.loading()`
  /// forever (an endless spinner, never an error). This bounds that wait so
  /// [start] always reaches an `_emit()` call one way or another.
  final Duration _startTimeout;

  /// Real-device report #2, round 2: a caught error from *constructing*
  /// this service's dependencies (`google_sync_providers.dart`'s
  /// `googleSyncTriggerServiceProvider` — e.g. a `googleCalendarApiProvider`/
  /// `syncSettingsStoreProvider` that throws synchronously while being
  /// built). When set, this service was built with safe placeholder
  /// dependencies purely so it has *something* non-null to hold — [start]
  /// never touches them and instead emits the failure immediately, so the
  /// retry card's error text reflects the true construction failure rather
  /// than a misleading "settings load" message.
  final Object? _constructionError;

  /// M5b: registers/cancels the periodic background sync task alongside
  /// enable/disable/sign-out — defaults to a no-op so pre-M5b callers
  /// (and any construction site that genuinely doesn't care) are
  /// unaffected.
  final BackgroundSyncScheduler _backgroundScheduler;

  final StreamController<GoogleSyncSettingsState> _controller =
      StreamController<GoogleSyncSettingsState>.broadcast();

  GoogleSyncSettingsState _state = const GoogleSyncSettingsState();
  DateTime? _lastRunAt;
  // ignore: cancel_subscriptions
  StreamSubscription<void>? _localChangesSubscription;
  Timer? _debounceTimer;
  bool _disposed = false;

  /// Raw broadcast stream of state changes — only delivers events emitted
  /// *after* whoever calls `.listen()` on it subscribes (standard Dart
  /// broadcast-stream semantics). Safe for a listener that subscribes
  /// before [start] ever runs (e.g. the trigger-service tests below, and
  /// `retryLoad()`'s own re-emission while already subscribed), but NOT
  /// safe for a subscriber that attaches long after [start] already ran —
  /// see [watchState] and its doc for why the settings screen uses that
  /// instead (real-device report #2, round 2's actual root cause).
  Stream<GoogleSyncSettingsState> get states => _controller.stream;

  GoogleSyncSettingsState get state => _state;

  /// Returns a **fresh** stream that immediately replays the current
  /// [state] to its subscriber before forwarding every future update.
  ///
  /// Real-device report #2, round 2's actual root cause: `CalendarShellScreen`
  /// keeps this service alive (and therefore [start] running) for the whole
  /// signed-in session by watching `googleSyncTriggerServiceProvider`
  /// directly, but the settings screen is opened *later*, as a separate
  /// navigation — its `googleSyncStateProvider` (a `StreamProvider.autoDispose`)
  /// only starts listening at that point. [start]'s single `_emit()` call
  /// (even with round 1's try/catch/timeout fix — which does fire
  /// correctly) had already happened and been delivered to nobody by then,
  /// because [states] is backed by a single plain broadcast
  /// `StreamController`: per Dart's broadcast-stream contract, a listener
  /// that subscribes after an event was added never receives that event.
  /// The settings screen was therefore always watching a stream whose one
  /// and only historical emission was already gone — stuck in
  /// `AsyncValue.loading()` forever, regardless of how well [start]'s own
  /// timeout worked. [watchState] fixes this by seeding every new
  /// subscription with [state] synchronously in `onListen`, so a late
  /// subscriber (opening settings minutes after app start) sees the
  /// already-resolved state immediately instead of an empty stream.
  Stream<GoogleSyncSettingsState> watchState() {
    late final StreamController<GoogleSyncSettingsState> controller;
    StreamSubscription<GoogleSyncSettingsState>? subscription;
    controller = StreamController<GoogleSyncSettingsState>.broadcast(
      onListen: () {
        controller.add(_state);
        subscription = _controller.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
        // A `StreamProvider`'s single subscription never re-listens after
        // cancelling (a fresh `watchState()` call is made instead — see
        // `googleSyncStateProvider`), so this per-call controller is done
        // for good once its one subscriber goes away.
        await controller.close();
      },
    );
    return controller.stream;
  }

  /// Loads the persisted enabled/last-synced state and, if already enabled,
  /// starts watching for local edits and (re-)registers the M5b periodic
  /// background sync task (idempotent — `existingWorkPolicy: keep`).
  /// Call once when the settings feature is first wired up (mirrors
  /// `ReminderSyncService.start`).
  ///
  /// M5b: also surfaces any [SyncSettings.lastErrorMessage] left behind by
  /// a previous pass — in particular a *background* pass, which runs in a
  /// separate isolate with no live listener of its own, so this is the only
  /// place its failure ever reaches the UI (task brief M5b §5: "surface
  /// error state in settings store").
  Future<void> start() async {
    debugPrint('[sync-settings] service.start() called');
    if (_constructionError != null) {
      // The service itself failed to be built with real dependencies
      // (`google_sync_providers.dart` caught it and substituted safe
      // placeholders) — there is nothing to load, surface the real cause
      // immediately rather than pretending a settings load was attempted.
      debugPrint(
        '[sync-settings] start() short-circuits on construction error: '
        '$_constructionError',
      );
      _state = _state.copyWith(
        status: SyncStatus.error,
        initialLoadFailed: true,
        errorMessage: _constructionError.toString(),
      );
      _emit();
      return;
    }
    try {
      debugPrint('[sync-settings] settings store load() starting');
      final SyncSettings settings = await _settingsStore.load().timeout(
        _startTimeout,
      );
      debugPrint('[sync-settings] settings store load() done');
      _lastRunAt = settings.lastSyncedAt;
      _state = GoogleSyncSettingsState(
        enabled: settings.enabled,
        lastSyncedAt: settings.lastSyncedAt,
        status: settings.lastErrorMessage == null
            ? SyncStatus.idle
            : SyncStatus.error,
        errorMessage: settings.lastErrorMessage,
      );
      _emit();
      if (settings.enabled) {
        _subscribeToLocalChanges();
        await _backgroundScheduler.registerPeriodic();
      }
    } catch (error) {
      // Never leave the caller (and the settings screen watching `states`)
      // without an emission: whatever the cause — permission-denied from
      // stale/undeployed Security Rules, no network, or the `_startTimeout`
      // above firing — this is a retryable error state, not silence.
      debugPrint('[sync-settings] settings store load() failed: $error');
      _state = _state.copyWith(
        status: SyncStatus.error,
        initialLoadFailed: true,
        errorMessage: AppLocalizationsHe().settingsGoogleSyncLoadFailedMessage,
      );
      _emit();
    }
  }

  /// Retries the initial settings load after [initialLoadFailed] — the
  /// settings screen's "נסה שוב" button. Simply re-running [start] is safe:
  /// [_subscribeToLocalChanges] is idempotent and re-registering the
  /// background task uses `existingWorkPolicy: keep` (see
  /// `background_sync_scheduler.dart`).
  Future<void> retryLoad() => start();

  /// Enables sync: requests the `calendar.events` scope as incremental
  /// authorization (ARCHITECTURE.md §5 — not at sign-in) and, if granted,
  /// persists the enabled flag and runs a first sync immediately. Returns
  /// whether the scope was granted.
  ///
  /// Device-feedback round #3 ("the enable toggle silently does nothing"):
  /// the confirmed root cause was that [GoogleCalendarApi.requestAccess]
  /// could *throw* (most commonly: a restored FirebaseAuth session never
  /// runs the interactive sign-in flow that initializes
  /// `GoogleSignIn.instance` — see `core/auth/google_sign_in_gate.dart`) and
  /// nothing here ever caught it — the exception propagated out through
  /// `settings_screen.dart`'s `unawaited(_onEnabledChanged(...))`, where it
  /// was silently dropped by the app's global `runZonedGuarded` handler
  /// (logged, never crashing, but also never reaching the UI): the switch
  /// never flips, no snackbar, no dialog, exactly as reported. Every path
  /// through this method now ends in an explicit state update — a quiet
  /// decline (no account / user canceled), a surfaced error (anything
  /// else), or success — never a silently-propagating exception.
  Future<bool> enable() async {
    debugPrint('[sync-settings] enable() called');
    _state = _state.copyWith(authorizing: true);
    _emit();
    final bool granted;
    try {
      granted = await _api.requestAccess();
      debugPrint(
        '[sync-settings] enable(): requestAccess() -> granted=$granted',
      );
    } catch (error) {
      debugPrint('[sync-settings] enable(): requestAccess() threw: $error');
      _state = _state.copyWith(
        authorizing: false,
        status: SyncStatus.error,
        // Device report 2026-10-12: backing out of Google's "app not
        // verified" screen reaches here as "[16] Cancelled by user" — say
        // how to get past that screen instead of the raw exception.
        errorMessage: isUserCancellation(error)
            ? AppLocalizationsHe().settingsGoogleSyncCancelledMessage
            : error.toString(),
      );
      _emit();
      return false;
    }
    if (!granted) {
      // A quiet decline (no signed-in account, or the user canceled the
      // consent dialog) — not an error to surface, just revert to idle.
      _state = _state.copyWith(
        authorizing: false,
        status: SyncStatus.idle,
        clearErrorMessage: true,
      );
      _emit();
      return false;
    }
    debugPrint('[sync-settings] enable(): settings store write starting');
    await _settingsStore.setEnabled(true);
    debugPrint('[sync-settings] enable(): settings store write done');
    _state = _state.copyWith(
      authorizing: false,
      enabled: true,
      status: SyncStatus.idle,
      clearErrorMessage: true,
    );
    _emit();
    _subscribeToLocalChanges();
    await _backgroundScheduler.registerPeriodic();
    unawaited(syncNow());
    return true;
  }

  /// Disables sync, stops watching for local edits, and cancels the M5b
  /// periodic background sync task (the sync token and per-event Google
  /// sync state are left as-is, so re-enabling later resumes incrementally
  /// instead of a full resync).
  ///
  /// Device-feedback round #3: like [enable], a failed [_settingsStore]
  /// write must surface as an error state rather than let the exception
  /// propagate out of `settings_screen.dart`'s `unawaited(...)` call site
  /// unnoticed.
  Future<void> disable() async {
    debugPrint('[sync-settings] disable() called');
    try {
      await _settingsStore.setEnabled(false);
    } catch (error) {
      debugPrint(
        '[sync-settings] disable(): settings store write failed: $error',
      );
      _state = _state.copyWith(
        status: SyncStatus.error,
        errorMessage: error.toString(),
      );
      _emit();
      return;
    }
    _state = _state.copyWith(
      enabled: false,
      status: SyncStatus.idle,
      clearErrorMessage: true,
    );
    _emit();
    await _localChangesSubscription?.cancel();
    _localChangesSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _backgroundScheduler.cancel();
  }

  /// The app-open trigger: a no-op if disabled or if a sync already ran
  /// within [_openThrottle].
  Future<void> triggerAppOpen() async {
    if (!_state.enabled) {
      return;
    }
    final DateTime nowValue = _now();
    final DateTime? lastRun = _lastRunAt;
    if (lastRun != null && nowValue.difference(lastRun) < _openThrottle) {
      return;
    }
    await syncNow();
  }

  /// Runs a sync pass immediately, bypassing any debounce/throttle — the
  /// settings screen's manual "סנכרן עכשיו" button.
  ///
  /// Returns the pass's result (`null` when sync is disabled), so the
  /// pull-to-refresh gesture can tell "done" from "a sync was already
  /// running" instead of reporting success either way.
  Future<SyncRunResult?> syncNow() async {
    if (!_state.enabled) {
      return null;
    }
    _state = _state.copyWith(status: SyncStatus.syncing);
    _emit();
    SyncRunResult result;
    try {
      result = await _engine.runSync(onProgress: _onProgress);
    } catch (error) {
      // Round #9: an exception escaping the pass used to leave the screen on
      // "מסנכרן..." forever (callers run this unawaited).
      result = SyncRunResult.failure(error.toString(), permanent: false);
    }
    _lastRunAt = _now();
    _state = _state.copyWith(clearProgress: true);
    if (result.wasConcurrentSkip) {
      // Another pass (e.g. the app-open trigger) is still running; it will
      // report its own outcome. Don't stamp a last-sync time it hasn't earned.
      _state = _state.copyWith(status: SyncStatus.idle);
    } else if (result.isError) {
      _state = _state.copyWith(
        status: SyncStatus.error,
        errorMessage: result.errorMessage,
      );
    } else {
      _state = _state.copyWith(
        status: SyncStatus.idle,
        lastSyncedAt: _lastRunAt,
        clearErrorMessage: true,
      );
    }
    _emit();
    return result;
  }

  void _onProgress(SyncProgress progress) {
    if (_disposed || _state.status != SyncStatus.syncing) {
      return;
    }
    _state = _state.copyWith(progress: progress);
    _emit();
  }

  void _subscribeToLocalChanges() {
    if (_localChangesSubscription != null) {
      return;
    }
    // Round #10: listen to the repository's user-edit signal, not to every
    // occurrence in a three-year range — that re-read thousands of events on
    // each change (imported Google events included, which also re-triggered
    // sync after every import).
    _localChangesSubscription = _repository.localEdits.listen((_) {
      if (_disposed) {
        return;
      }
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_editDebounce, () => unawaited(syncNow()));
    });
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }

  /// Cancels every subscription/timer (RULES.md §6.1) — call on sign-out.
  ///
  /// M5b: if sync was enabled, also cancels the periodic background task
  /// (task brief §2: "when disabled or signed out: cancel by unique
  /// name") — there is no signed-in user left for it to run against, and
  /// [start] re-registers it (idempotently) the next time this service is
  /// built for a (possibly different) signed-in user.
  Future<void> stop() async {
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final StreamSubscription<void>? subscription = _localChangesSubscription;
    _localChangesSubscription = null;
    await subscription?.cancel();
    if (_state.enabled) {
      await _backgroundScheduler.cancel();
    }
    await _controller.close();
  }
}

/// Whether [error] from Google sign-in / authorization means the user backed
/// out (closed the consent screen, or "back to safety" on Google's
/// unverified-app warning) rather than a real failure.
bool isUserCancellation(Object error) {
  final String text = error.toString().toLowerCase();
  return text.contains('cancel') || text.contains('[16]');
}
