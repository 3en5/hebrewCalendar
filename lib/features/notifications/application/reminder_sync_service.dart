import 'dart:async';

import '../../../domain/event/event_occurrence.dart';
import '../../../domain/event/event_repository.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../domain/notifications/notification_scheduler.dart';
import '../../../domain/notifications/planned_notification.dart';
import '../../../domain/notifications/reminder_planner.dart';

/// The orchestrator ARCHITECTURE.md §6 calls for: connects
/// `EventRepository.watchOccurrencesInRange` -> `planReminders` (pure
/// domain) -> `NotificationScheduler` (thin plugin adapter). Depends only on
/// domain-friendly interfaces, so it's fully testable with fakes (task
/// brief §6) — no Riverpod, no Flutter, no real plugin involved here; the
/// Riverpod wiring that constructs this with real dependencies lives in
/// `reminder_providers.dart`.
class ReminderSyncService {
  ReminderSyncService({
    required EventRepository repository,
    required NotificationScheduler scheduler,
    required HebrewDateEngine engine,
    DateTime Function() now = DateTime.now,
    Duration horizon = kDefaultReminderHorizon,
    Duration debounce = const Duration(milliseconds: 500),
  }) : _repository = repository,
       _scheduler = scheduler,
       _engine = engine,
       _now = now,
       _horizon = horizon,
       _debounce = debounce;

  final EventRepository _repository;
  final NotificationScheduler _scheduler;
  final HebrewDateEngine _engine;
  final DateTime Function() _now;
  final Duration _horizon;
  final Duration _debounce;

  /// Cancelled in [stop] (RULES.md §6.1) — the `cancel_subscriptions` lint
  /// only recognizes cancellation of local variables, not fields, hence the
  /// `ignore:` immediately below.
  // ignore: cancel_subscriptions
  StreamSubscription<List<EventOccurrence>>? _subscription;
  Timer? _debounceTimer;
  bool _disposed = false;

  /// Starts watching occurrences for `[now, now + horizon]` and (re)plans
  /// reminders, debounced, whenever that set changes. Safe to call once per
  /// instance; call [stop] before starting a new instance for a different
  /// user (RULES.md §6 — one focused subscription, not a leaked one).
  Future<void> start() async {
    await _scheduler.initialize();
    if (_disposed) {
      return;
    }
    final DateTime nowValue = _now();
    final HebrewDate from = _engine.fromGregorian(nowValue);
    final HebrewDate to = _engine.fromGregorian(nowValue.add(_horizon));
    _subscription = _repository
        .watchOccurrencesInRange(from, to)
        .listen(_onOccurrences);
  }

  void _onOccurrences(List<EventOccurrence> occurrences) {
    if (_disposed) {
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      unawaited(_replan(occurrences));
    });
  }

  Future<void> _replan(List<EventOccurrence> occurrences) async {
    if (_disposed) {
      return;
    }
    final List<PlannedNotification> plan = planReminders(
      occurrences: occurrences,
      now: _now(),
      engine: _engine,
      horizon: _horizon,
    );
    await _scheduler.showScheduled(plan);
  }

  /// Cancels the subscription (RULES.md §6.1: every `StreamSubscription`
  /// disposed) and any pending debounce timer, then cancels every
  /// already-scheduled notification — called on sign-out so a previous
  /// user's reminders never keep firing for whoever signs in next.
  Future<void> stop() async {
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final StreamSubscription<List<EventOccurrence>>? subscription =
        _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _scheduler.cancelAll();
  }
}
