import 'dart:async';

import '../../../data/sync/google_calendar_api.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../domain/event/event_occurrence.dart';
import '../../../domain/event/event_repository.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
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
    required HebrewDateEngine hebrewEngine,
    DateTime Function() now = DateTime.now,
    Duration editDebounce = const Duration(seconds: 30),
    Duration openThrottle = const Duration(minutes: 5),
    Duration startTimeout = const Duration(seconds: 10),
    BackgroundSyncScheduler backgroundScheduler =
        const NoopBackgroundSyncScheduler(),
  }) : _engine = engine,
       _settingsStore = settingsStore,
       _api = api,
       _repository = repository,
       _hebrewEngine = hebrewEngine,
       _now = now,
       _editDebounce = editDebounce,
       _openThrottle = openThrottle,
       _startTimeout = startTimeout,
       _backgroundScheduler = backgroundScheduler;

  final SyncEngine _engine;
  final SyncSettingsStore _settingsStore;
  final GoogleCalendarApi _api;
  final EventRepository _repository;
  final HebrewDateEngine _hebrewEngine;
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
  StreamSubscription<List<EventOccurrence>>? _localChangesSubscription;
  Timer? _debounceTimer;
  bool _disposed = false;

  Stream<GoogleSyncSettingsState> get states => _controller.stream;

  GoogleSyncSettingsState get state => _state;

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
    try {
      final SyncSettings settings = await _settingsStore.load().timeout(
        _startTimeout,
      );
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
  Future<bool> enable() async {
    final bool granted = await _api.requestAccess();
    if (!granted) {
      return false;
    }
    await _settingsStore.setEnabled(true);
    _state = _state.copyWith(enabled: true);
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
  Future<void> disable() async {
    await _settingsStore.setEnabled(false);
    _state = _state.copyWith(enabled: false, status: SyncStatus.idle);
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
  Future<void> syncNow() async {
    if (!_state.enabled) {
      return;
    }
    _state = _state.copyWith(status: SyncStatus.syncing);
    _emit();
    final SyncRunResult result = await _engine.runSync();
    _lastRunAt = _now();
    if (result.isError) {
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
  }

  void _subscribeToLocalChanges() {
    if (_localChangesSubscription != null) {
      return;
    }
    final DateTime nowValue = _now();
    final HebrewDate from = _hebrewEngine.fromGregorian(
      nowValue.subtract(const Duration(days: 365)),
    );
    final HebrewDate to = _hebrewEngine.fromGregorian(
      nowValue.add(const Duration(days: 730)),
    );
    // `skip(1)`: the first emission is the current snapshot, not a change —
    // only emissions after that represent an actual local edit.
    _localChangesSubscription = _repository
        .watchOccurrencesInRange(from, to)
        .skip(1)
        .listen((_) {
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
    final StreamSubscription<List<EventOccurrence>>? subscription =
        _localChangesSubscription;
    _localChangesSubscription = null;
    await subscription?.cancel();
    if (_state.enabled) {
      await _backgroundScheduler.cancel();
    }
    await _controller.close();
  }
}
