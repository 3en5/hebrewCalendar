/// M5b: the periodic WorkManager registration/cancellation boundary — the
/// *only* other file (besides `background_sync_bootstrap.dart`) that
/// imports `package:workmanager` (task brief M5b §2 "the workmanager plugin
/// boundary stays thin"). `google_sync_trigger_service.dart` depends only
/// on the abstract [BackgroundSyncScheduler], so it stays unit-testable
/// with `FakeBackgroundSyncScheduler` — the real plugin needs an actual
/// Android WorkManager to do anything, unavailable under `flutter test`
/// (no Android SDK/emulator in this dev environment, docs/LESSONS.md).
library;

import 'package:workmanager/workmanager.dart';

/// The registered periodic task's unique name — used both to register it
/// (with `existingWorkPolicy: keep`, so re-registering while already
/// registered is a safe no-op) and to cancel it.
const String kGoogleCalendarSyncTaskUniqueName =
    'google-calendar-periodic-sync';

/// The task's *type* name, distinct from [kGoogleCalendarSyncTaskUniqueName]
/// — `background_sync_bootstrap.dart`'s `callbackDispatcher` dispatches on
/// this.
const String kGoogleCalendarSyncTaskName = 'googleCalendarPeriodicSync';

/// M5b task brief §2: "frequency 6 hours". Configurable frequency is
/// WISHLIST scope (see docs/WISHLIST.md) — not implemented here.
const Duration kGoogleCalendarSyncFrequency = Duration(hours: 6);

/// Thin abstraction over `package:workmanager`'s periodic-task API so the
/// rest of the app (`google_sync_trigger_service.dart`) never touches the
/// plugin directly.
abstract class BackgroundSyncScheduler {
  /// Registers the periodic Google Calendar sync task (network-connected +
  /// battery-not-low constraints — no wakelocks, relying entirely on
  /// WorkManager's own battery-friendly scheduling) if it isn't already
  /// registered.
  Future<void> registerPeriodic();

  /// Cancels the periodic task by its unique name.
  Future<void> cancel();
}

/// The real [BackgroundSyncScheduler], backed by `package:workmanager`.
class WorkmanagerBackgroundSyncScheduler implements BackgroundSyncScheduler {
  const WorkmanagerBackgroundSyncScheduler();

  @override
  Future<void> registerPeriodic() {
    return Workmanager().registerPeriodicTask(
      kGoogleCalendarSyncTaskUniqueName,
      kGoogleCalendarSyncTaskName,
      frequency: kGoogleCalendarSyncFrequency,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  @override
  Future<void> cancel() =>
      Workmanager().cancelByUniqueName(kGoogleCalendarSyncTaskUniqueName);
}

/// A no-op [BackgroundSyncScheduler] — the default for callers that don't
/// care about background registration (e.g. `google_sync_trigger_service_test.dart`'s
/// existing M5a tests, predating M5b, which construct the service directly
/// without this dependency in mind).
class NoopBackgroundSyncScheduler implements BackgroundSyncScheduler {
  const NoopBackgroundSyncScheduler();

  @override
  Future<void> registerPeriodic() async {}

  @override
  Future<void> cancel() async {}
}
