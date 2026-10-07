import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/notifications/notification_scheduler.dart';
import '../../domain/notifications/planned_notification.dart';
import '../../domain/notifications/scheduled_notification_diff.dart';

/// The one Android notification channel this app uses for reminders.
const String kReminderChannelId = 'reminders';

/// `flutter_local_notifications`-backed [NotificationScheduler].
///
/// This is the "thin plugin adapter" ARCHITECTURE.md §6 calls for: it does
/// no planning/diffing decisions of its own (that's `reminder_planner.dart`
/// and `scheduled_notification_diff.dart`, both pure and unit-tested) —
/// just mapping [PlannedNotification]s to plugin calls, so it is
/// deliberately NOT unit-tested directly (the task brief's own words); it
/// is exercised indirectly, through `ReminderSyncService` tests that use a
/// fake [NotificationScheduler] instead.
///
/// Every plugin call is wrapped so a missing/denied permission, a platform
/// quirk, or (in widget tests) the plugin simply not being registered on
/// the test binary's method channel can never crash the app or a test —
/// "graceful degradation... never crash" (task brief §3).
class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({
    required this.channelName,
    this.channelId = kReminderChannelId,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// The Android notification channel's display name — the caller passes
  /// in the Hebrew ARB string (`notificationsChannelName`) at construction
  /// time, since this data-layer class itself must not depend on a
  /// `BuildContext` (task brief §3).
  final String channelName;
  final String channelId;
  final FlutterLocalNotificationsPlugin _plugin;

  static const String _signaturesPrefsKey = 'reminder_scheduler_signatures_v1';

  bool _timeZoneReady = false;

  @override
  Future<void> initialize() async {
    await _ensureTimeZone();
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
      );
      await _plugin.initialize(settings: settings);
      await _androidPlugin()?.createNotificationChannel(
        AndroidNotificationChannel(channelId, channelName),
      );
    } catch (_) {
      // Missing platform channel (e.g. running under `flutter test`) or a
      // plugin-side failure — reminders are best-effort, never fatal.
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _androidPlugin();
      final bool? granted = await android?.requestNotificationsPermission();
      // Best-effort: exact alarms have their own permission on Android 12+;
      // `showScheduled` already falls back to inexact scheduling if this
      // was never granted, so the result here doesn't gate anything.
      await android?.requestExactAlarmsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showScheduled(List<PlannedNotification> planned) async {
    try {
      final Map<int, String> previous = await _loadSignatures();
      final NotificationDiff diff = diffScheduledNotifications(
        previouslyScheduledSignatures: previous,
        planned: planned,
      );
      for (final int id in diff.toCancel) {
        await _plugin.cancel(id: id);
      }
      for (final PlannedNotification notification in diff.toSchedule) {
        await _scheduleOne(notification);
      }
      await _saveSignatures(<int, String>{
        for (final PlannedNotification notification in planned)
          notification.stableId: signatureForPlannedNotification(notification),
      });
    } catch (_) {
      // Best-effort — see class doc.
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      await _saveSignatures(<int, String>{});
    } catch (_) {
      // Best-effort — see class doc.
    }
  }

  Future<void> _scheduleOne(PlannedNotification notification) async {
    await _ensureTimeZone();
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      notification.fireAt,
      tz.local,
    );
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(channelId, channelName),
    );
    try {
      await _plugin.zonedSchedule(
        id: notification.stableId,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: notification.title,
        body: notification.body,
      );
    } catch (_) {
      // Exact alarms unavailable/unpermitted on this device — fall back to
      // an inexact schedule rather than dropping the reminder entirely
      // (task brief §3: "never crash", degrade gracefully instead).
      try {
        await _plugin.zonedSchedule(
          id: notification.stableId,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: notification.title,
          body: notification.body,
        );
      } catch (_) {
        // Even the inexact fallback failed (e.g. no plugin registered under
        // `flutter test`) — drop this one reminder silently.
      }
    }
  }

  Future<void> _ensureTimeZone() async {
    if (_timeZoneReady) {
      return;
    }
    try {
      tzdata.initializeTimeZones();
      final TimezoneInfo local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
      _timeZoneReady = true;
    } catch (_) {
      // Leaves the timezone package's own UTC default in place.
    }
  }

  AndroidFlutterLocalNotificationsPlugin? _androidPlugin() => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<Map<int, String>> _loadSignatures() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_signaturesPrefsKey);
    if (raw == null || raw.isEmpty) {
      return <int, String>{};
    }
    final Map<String, dynamic> decoded =
        jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (String key, dynamic value) => MapEntry(int.parse(key), value as String),
    );
  }

  Future<void> _saveSignatures(Map<int, String> signatures) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, String> encoded = signatures.map(
      (int key, String value) => MapEntry(key.toString(), value),
    );
    await prefs.setString(_signaturesPrefsKey, jsonEncode(encoded));
  }
}
