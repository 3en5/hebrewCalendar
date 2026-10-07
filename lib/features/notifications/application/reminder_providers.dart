/// The Riverpod wiring for M4's reminder orchestrator (ARCHITECTURE.md §6):
/// constructs the real [NotificationScheduler]/[ReminderSyncService] from
/// the app's existing repository/engine providers. `ReminderSyncService`
/// itself (and the pure planner/diff it calls into) stays Riverpod-free and
/// is tested directly with fakes — this file only exists to hand it real
/// dependencies and hook it into provider lifecycles.
library;

import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/notifications/local_notification_scheduler.dart';
import '../../../domain/notifications/notification_scheduler.dart';
import '../../../l10n/app_localizations_he.dart';
import '../../calendar/application/hebrew_date_engine_provider.dart';
import '../../event_editor/application/event_repository_provider.dart';
import 'reminder_sync_service.dart';

/// The app's single [NotificationScheduler]. Not `autoDispose`, matching
/// `eventRepositoryProvider`/`authRepositoryProvider` (RULES.md §6.3 scopes
/// screen-level state, not an app-wide service) — its underlying plugin
/// instance and persisted "what's scheduled" bookkeeping should outlive any
/// one screen.
///
/// The channel name is Hebrew ARB text (`notificationsChannelName`), read
/// via the generated `AppLocalizationsHe` directly rather than
/// `AppLocalizations.of(context)`: this app only ever runs with the Hebrew
/// locale (`main.dart` hard-codes `Locale('he')`), and a `BuildContext` is
/// not available where Riverpod constructs this provider.
final Provider<NotificationScheduler> notificationSchedulerProvider =
    Provider<NotificationScheduler>((Ref ref) {
      return LocalNotificationScheduler(
        channelName: AppLocalizationsHe().notificationsChannelName,
      );
    });

/// Connects the signed-in user's occurrences to reminder scheduling.
///
/// `autoDispose`: this is started from `CalendarShellScreen` (the only
/// screen shown while signed in) and torn down — subscription cancelled,
/// every scheduled notification cancelled — once nothing watches it
/// anymore (RULES.md §6.1/§6.2), i.e. on sign-out when `AuthGate` swaps
/// back to `SignInScreen`.
final Provider<ReminderSyncService> reminderSyncServiceProvider =
    Provider.autoDispose<ReminderSyncService>((Ref ref) {
      final ReminderSyncService service = ReminderSyncService(
        repository: ref.watch(eventRepositoryProvider),
        scheduler: ref.watch(notificationSchedulerProvider),
        engine: ref.watch(hebrewDateEngineProvider),
      );
      unawaited(service.start());
      ref.onDispose(() => unawaited(service.stop()));
      return service;
    });

/// Whether we've already asked the OS for notification permission at least
/// once (persisted — RULES.md-style "ask once" UX, not on every app open).
const String _kPermissionRequestedPrefsKey =
    'notifications_permission_requested_v1';

/// Requests notification permission the first time the calendar is shown,
/// exactly once ever (per task brief §4). Resolves to whether permission is
/// granted, so `CalendarShellScreen` can show a Hebrew rationale snackbar
/// when it's denied. Never throws: a `SharedPreferences`/plugin failure
/// (e.g. no platform channel registered under `flutter test`) is treated as
/// "already handled" so it never surfaces a spurious snackbar.
class ReminderPermissionController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kPermissionRequestedPrefsKey) ?? false) {
        return true;
      }
      final NotificationScheduler scheduler = ref.watch(
        notificationSchedulerProvider,
      );
      final bool granted = await scheduler.requestPermissions();
      await prefs.setBool(_kPermissionRequestedPrefsKey, true);
      return granted;
    } catch (_) {
      return true;
    }
  }
}

final AsyncNotifierProvider<ReminderPermissionController, bool>
reminderPermissionProvider =
    AsyncNotifierProvider.autoDispose<ReminderPermissionController, bool>(
      ReminderPermissionController.new,
    );
