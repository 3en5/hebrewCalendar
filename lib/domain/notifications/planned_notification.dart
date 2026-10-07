/// A single locally-scheduled reminder notification, computed by
/// `reminder_planner.dart` from an [EventOccurrence]'s
/// `Event.reminderMinutesBefore` offsets.
///
/// This is a pure value object — no Flutter/plugin dependency — so the
/// planner that produces it stays fully unit-testable (ARCHITECTURE.md §6:
/// "pure domain planner" is the core of M4, tested without ever touching
/// `flutter_local_notifications`).
class PlannedNotification {
  const PlannedNotification({
    required this.stableId,
    required this.fireAt,
    required this.title,
    required this.body,
  });

  /// A 31-bit non-negative id, stable across replans as long as the
  /// (event id, occurrence date, minutes-before) triple is unchanged — see
  /// `reminder_planner.dart`'s `computeStableNotificationId` for the exact
  /// derivation. This is what `flutter_local_notifications` uses as the
  /// Android notification/alarm id, so the same reminder must always map to
  /// the same id (to be replaced/cancelled correctly) and different
  /// reminders must not collide.
  final int stableId;

  /// The local date-time the notification should fire at.
  final DateTime fireAt;

  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlannedNotification &&
          other.stableId == stableId &&
          other.fireAt == fireAt &&
          other.title == title &&
          other.body == body);

  @override
  int get hashCode => Object.hash(stableId, fireAt, title, body);

  @override
  String toString() =>
      'PlannedNotification(stableId: $stableId, fireAt: $fireAt, '
      'title: $title, body: $body)';
}
