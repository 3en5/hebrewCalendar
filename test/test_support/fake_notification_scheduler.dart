import 'package:hebrew_calendar/domain/notifications/notification_scheduler.dart';
import 'package:hebrew_calendar/domain/notifications/planned_notification.dart';

/// An in-memory [NotificationScheduler] test double.
///
/// Records every call instead of touching a real
/// `flutter_local_notifications` plugin, so widget tests that render
/// `CalendarShellScreen` (which watches `reminderSyncServiceProvider`, M4)
/// never hit a missing platform channel, and `ReminderSyncService` unit
/// tests can assert exactly what was scheduled/cancelled.
class FakeNotificationScheduler implements NotificationScheduler {
  int initializeCallCount = 0;
  int requestPermissionsCallCount = 0;
  int cancelAllCallCount = 0;
  bool permissionsGranted = true;

  /// The most recent plan passed to [showScheduled], in call order.
  final List<List<PlannedNotification>> showScheduledCalls =
      <List<PlannedNotification>>[];

  /// The current plan as of the last [showScheduled] call, or empty after
  /// [cancelAll] — mirrors what a real scheduler would actually have
  /// pending, for assertions that only care about the end state.
  List<PlannedNotification> currentlyScheduled = const <PlannedNotification>[];

  @override
  Future<void> initialize() async {
    initializeCallCount++;
  }

  @override
  Future<bool> requestPermissions() async {
    requestPermissionsCallCount++;
    return permissionsGranted;
  }

  @override
  Future<void> showScheduled(List<PlannedNotification> planned) async {
    showScheduledCalls.add(planned);
    currentlyScheduled = planned;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCallCount++;
    currentlyScheduled = const <PlannedNotification>[];
  }
}
