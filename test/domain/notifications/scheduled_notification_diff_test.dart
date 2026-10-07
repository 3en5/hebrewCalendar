// Unit tests for the pure diffing logic `LocalNotificationScheduler` uses
// to avoid cancel-all-then-reschedule churn (ARCHITECTURE.md §6): unchanged
// reminders are left alone, changed ones are rescheduled, removed ones are
// cancelled.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/notifications/planned_notification.dart';
import 'package:hebrew_calendar/domain/notifications/scheduled_notification_diff.dart';

PlannedNotification _notification(int id, {DateTime? fireAt, String? body}) =>
    PlannedNotification(
      stableId: id,
      fireAt: fireAt ?? DateTime(2026, 1, 10, 9),
      title: 'תזכורת',
      body: body ?? 'body-$id',
    );

void main() {
  test('an unchanged reminder is neither cancelled nor rescheduled', () {
    final PlannedNotification notification = _notification(1);
    final NotificationDiff diff = diffScheduledNotifications(
      previouslyScheduledSignatures: <int, String>{
        1: signatureForPlannedNotification(notification),
      },
      planned: <PlannedNotification>[notification],
    );

    expect(diff.toCancel, isEmpty);
    expect(diff.toSchedule, isEmpty);
  });

  test('a brand new reminder is scheduled, nothing is cancelled', () {
    final PlannedNotification notification = _notification(1);
    final NotificationDiff diff = diffScheduledNotifications(
      previouslyScheduledSignatures: <int, String>{},
      planned: <PlannedNotification>[notification],
    );

    expect(diff.toCancel, isEmpty);
    expect(diff.toSchedule, <PlannedNotification>[notification]);
  });

  test('a reminder whose fire time changed is rescheduled (same id)', () {
    final PlannedNotification before = _notification(
      1,
      fireAt: DateTime(2026, 1, 10, 9),
    );
    final PlannedNotification after = _notification(
      1,
      fireAt: DateTime(2026, 1, 10, 10),
    );
    final NotificationDiff diff = diffScheduledNotifications(
      previouslyScheduledSignatures: <int, String>{
        1: signatureForPlannedNotification(before),
      },
      planned: <PlannedNotification>[after],
    );

    expect(diff.toCancel, isEmpty);
    expect(diff.toSchedule, <PlannedNotification>[after]);
  });

  test('a reminder no longer in the plan is cancelled', () {
    final NotificationDiff diff = diffScheduledNotifications(
      previouslyScheduledSignatures: <int, String>{
        1: signatureForPlannedNotification(_notification(1)),
        2: signatureForPlannedNotification(_notification(2)),
      },
      planned: <PlannedNotification>[_notification(1)],
    );

    expect(diff.toCancel, <int>[2]);
    expect(diff.toSchedule, isEmpty);
  });

  test('a mix of unchanged/changed/new/removed is diffed correctly', () {
    final PlannedNotification unchanged = _notification(1);
    final PlannedNotification changedBefore = _notification(2, body: 'old');
    final PlannedNotification changedAfter = _notification(2, body: 'new');
    final PlannedNotification brandNew = _notification(3);

    final NotificationDiff diff = diffScheduledNotifications(
      previouslyScheduledSignatures: <int, String>{
        1: signatureForPlannedNotification(unchanged),
        2: signatureForPlannedNotification(changedBefore),
        4: signatureForPlannedNotification(_notification(4)),
      },
      planned: <PlannedNotification>[unchanged, changedAfter, brandNew],
    );

    expect(diff.toCancel, <int>[4]);
    expect(diff.toSchedule, <PlannedNotification>[changedAfter, brandNew]);
  });
}
