import 'planned_notification.dart';

/// Abstract local-notification scheduling, defined purely in terms of
/// domain types (mirrors `EventRepository`'s split: this interface lives in
/// `lib/domain`, the `flutter_local_notifications`-backed implementation in
/// `lib/data/notifications/local_notification_scheduler.dart` — the "thin
/// plugin adapter" ARCHITECTURE.md §6 calls for, kept separate from the
/// pure planner so the planner never needs a real plugin to be tested).
abstract class NotificationScheduler {
  /// One-time setup: platform notification channel, timezone database, etc.
  /// Safe to call more than once (implementations are idempotent).
  Future<void> initialize();

  /// Requests whatever OS permission is needed to show notifications
  /// (Android 13+ POST_NOTIFICATIONS). Returns whether it was granted.
  /// Never throws — callers may call this eagerly without a try/catch.
  Future<bool> requestPermissions();

  /// Brings the set of actually-scheduled notifications in line with
  /// [planned]: cancels ones no longer present, (re)schedules new or
  /// changed ones, and leaves unchanged ones untouched (diff-based —
  /// ARCHITECTURE.md §6, avoids cancel-all-then-reschedule churn).
  Future<void> showScheduled(List<PlannedNotification> planned);

  /// Cancels every currently-scheduled notification (e.g. on sign-out).
  Future<void> cancelAll();
}
