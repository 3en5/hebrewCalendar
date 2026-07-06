import 'package:hebrew_calendar/features/settings/application/background_sync_scheduler.dart';

/// An in-memory [BackgroundSyncScheduler] test double (M5b) — records call
/// counts instead of touching the real `workmanager` plugin, which has no
/// channel handler under `flutter test` (mirrors `FakeNotificationScheduler`'s
/// role for M4 and `FakeGoogleCalendarApi`'s for M5a — see docs/LESSONS.md).
class FakeBackgroundSyncScheduler implements BackgroundSyncScheduler {
  int registerPeriodicCallCount = 0;
  int cancelCallCount = 0;

  @override
  Future<void> registerPeriodic() async {
    registerPeriodicCallCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCallCount++;
  }
}
