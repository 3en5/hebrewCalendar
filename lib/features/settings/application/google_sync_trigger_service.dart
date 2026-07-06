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
  }) : _engine = engine,
       _settingsStore = settingsStore,
       _api = api,
       _repository = repository,
       _hebrewEngine = hebrewEngine,
       _now = now,
       _editDebounce = editDebounce,
       _openThrottle = openThrottle;

  final SyncEngine _engine;
  final SyncSettingsStore _settingsStore;
  final GoogleCalendarApi _api;
  final EventRepository _repository;
  final HebrewDateEngine _hebrewEngine;
  final DateTime Function() _now;
  final Duration _editDebounce;
  final Duration _openThrottle;

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
  /// starts watching for local edits. Call once when the settings feature
  /// is first wired up (mirrors `ReminderSyncService.start`).
  Future<void> start() async {
    final SyncSettings settings = await _settingsStore.load();
    _lastRunAt = settings.lastSyncedAt;
    _state = GoogleSyncSettingsState(
      enabled: settings.enabled,
      lastSyncedAt: settings.lastSyncedAt,
    );
    _emit();
    if (settings.enabled) {
      _subscribeToLocalChanges();
    }
  }

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
    unawaited(syncNow());
    return true;
  }

  /// Disables sync and stops watching for local edits (the sync token and
  /// per-event Google sync state are left as-is, so re-enabling later
  /// resumes incrementally instead of a full resync).
  Future<void> disable() async {
    await _settingsStore.setEnabled(false);
    _state = _state.copyWith(enabled: false, status: SyncStatus.idle);
    _emit();
    await _localChangesSubscription?.cancel();
    _localChangesSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
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
  Future<void> stop() async {
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final StreamSubscription<List<EventOccurrence>>? subscription =
        _localChangesSubscription;
    _localChangesSubscription = null;
    await subscription?.cancel();
    await _controller.close();
  }
}
