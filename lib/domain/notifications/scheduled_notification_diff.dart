import 'planned_notification.dart';

/// A signature capturing everything about a [PlannedNotification] that
/// would require it to actually be rescheduled if it changed (fire time,
/// title, body — not just its id). Used both to persist "what's currently
/// scheduled" and to detect "did this particular reminder change" without
/// re-scheduling reminders whose content is identical to last time.
String signatureForPlannedNotification(PlannedNotification notification) =>
    '${notification.fireAt.toIso8601String()}|${notification.title}|'
    '${notification.body}';

/// The result of comparing a previous "what's scheduled" snapshot against a
/// fresh [planReminders] output.
class NotificationDiff {
  const NotificationDiff({required this.toCancel, required this.toSchedule});

  /// Ids that were scheduled before but are no longer in the plan (event/
  /// reminder deleted, or its fire time moved out of the horizon) — these
  /// must be cancelled with the plugin.
  final List<int> toCancel;

  /// Notifications that are new, or whose signature changed since last
  /// time (same id, different fire time/title/body) — these must be
  /// (re)scheduled with the plugin.
  final List<PlannedNotification> toSchedule;
}

/// Pure diffing logic shared by `LocalNotificationScheduler.showScheduled`
/// (ARCHITECTURE.md §6 — "diff-based scheduling: cancel ids no longer
/// planned, schedule new/changed only, avoid cancelAll+reschedule churn").
///
/// Kept in `lib/domain` (unlike the plugin adapter that calls it) precisely
/// so this logic — the part with actual decisions to get right — is
/// unit-tested without a real `flutter_local_notifications` plugin.
NotificationDiff diffScheduledNotifications({
  required Map<int, String> previouslyScheduledSignatures,
  required List<PlannedNotification> planned,
}) {
  final Map<int, PlannedNotification> plannedById = <int, PlannedNotification>{
    for (final PlannedNotification notification in planned)
      notification.stableId: notification,
  };

  final List<int> toCancel = <int>[
    for (final int id in previouslyScheduledSignatures.keys)
      if (!plannedById.containsKey(id)) id,
  ];

  final List<PlannedNotification> toSchedule = <PlannedNotification>[
    for (final PlannedNotification notification in planned)
      if (previouslyScheduledSignatures[notification.stableId] !=
          signatureForPlannedNotification(notification))
        notification,
  ];

  return NotificationDiff(toCancel: toCancel, toSchedule: toSchedule);
}
