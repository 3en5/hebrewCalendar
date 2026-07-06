import '../event/event.dart';
import '../event/event_occurrence.dart';
import '../hebrew_date/hebrew_date.dart';
import '../hebrew_date/hebrew_date_engine.dart';
import '../hebrew_date/hebrew_numerals.dart';
import 'planned_notification.dart';

/// The default reminder-planning horizon (ARCHITECTURE.md §6): how far into
/// the future [planReminders] considers occurrences, matching how far
/// ahead `ReminderSyncService` (features/notifications) queries the
/// repository for.
const Duration kDefaultReminderHorizon = Duration(days: 60);

/// Android's OS-level budget for exact alarms is finite in practice (battery
/// scheduling limits on some OEMs); capping well under it keeps every
/// planned reminder schedulable without the app needing to detect a
/// per-device limit.
const int kMaxPlannedNotifications = 60;

/// All-day events have no time-of-day of their own (`Event.startTime` is
/// null), so a reminder for one is anchored to a fixed local time on the
/// occurrence day — 09:00, matching the task brief's "all-day events fire
/// at 09:00 local on the occurrence day minus minutesBefore" rule — before
/// the `minutesBefore` offset is subtracted.
const int kAllDayReminderHour = 9;

/// Builds a deterministic notification plan from a set of event
/// [occurrences] (recurring events already expanded to concrete dates by
/// `recurrence_expander.dart` — this function does not expand recurrence
/// itself), relative to [now].
///
/// Pure Dart, no Flutter/plugin dependency (ARCHITECTURE.md §6 — this is the
/// "pure domain planner", the fully unit-tested core of M4; scheduling it
/// via `flutter_local_notifications` is a thin, separately-tested adapter
/// in `lib/data/notifications/`).
///
/// Rules:
/// - Every [minutesBefore] offset in `Event.reminderMinutesBefore` produces
///   at most one [PlannedNotification] per occurrence.
/// - A reminder whose computed fire time has already passed (before [now])
///   is skipped — never surface a stale "should have fired" notification.
/// - A reminder whose fire time falls beyond [now] + [horizon] is also
///   skipped; callers are expected to query occurrences for roughly that
///   same window (`ReminderSyncService`), but the planner enforces it
///   independently so it stays correct even given a wider input list.
/// - The result is capped to the [maxPlanned] reminders nearest to [now]
///   (Android's practical exact-alarm budget — see [kMaxPlannedNotifications]).
/// - The result is sorted by [PlannedNotification.fireAt], ascending.
List<PlannedNotification> planReminders({
  required List<EventOccurrence> occurrences,
  required DateTime now,
  required HebrewDateEngine engine,
  Duration horizon = kDefaultReminderHorizon,
  int maxPlanned = kMaxPlannedNotifications,
}) {
  final DateTime horizonEnd = now.add(horizon);
  final List<PlannedNotification> planned = <PlannedNotification>[];

  for (final EventOccurrence occurrence in occurrences) {
    final Event event = occurrence.event;
    for (final int minutesBefore in event.reminderMinutesBefore) {
      final DateTime fireAt = _fireAt(occurrence, minutesBefore, engine);
      if (fireAt.isBefore(now) || fireAt.isAfter(horizonEnd)) {
        continue;
      }
      planned.add(
        PlannedNotification(
          stableId: computeStableNotificationId(
            eventId: event.id,
            occurrenceDate: occurrence.occurrenceDate,
            minutesBefore: minutesBefore,
          ),
          fireAt: fireAt,
          title: _title,
          body: _formatBody(event, occurrence.occurrenceDate, engine),
        ),
      );
    }
  }

  planned.sort((PlannedNotification a, PlannedNotification b) {
    return a.fireAt.compareTo(b.fireAt);
  });

  if (planned.length <= maxPlanned) {
    return planned;
  }
  return planned.sublist(0, maxPlanned);
}

/// Fixed Hebrew notification title (there is no `BuildContext`/ARB access
/// from this pure-domain layer — see `hebrew_date_engine.dart`'s month
/// names for the same precedent of hard-coded Hebrew text in `lib/domain`).
/// The specific reminder detail (event title, Hebrew date, time) lives in
/// the body, so this stays a short, constant label.
const String _title = 'תזכורת';

DateTime _fireAt(
  EventOccurrence occurrence,
  int minutesBefore,
  HebrewDateEngine engine,
) {
  final DateTime day = engine.toGregorian(occurrence.occurrenceDate);
  final Event event = occurrence.event;
  final DateTime eventMoment = (event.allDay || event.startTime == null)
      ? DateTime(day.year, day.month, day.day, kAllDayReminderHour)
      : DateTime(
          day.year,
          day.month,
          day.day,
          event.startTime!.hour,
          event.startTime!.minute,
        );
  return eventMoment.subtract(Duration(minutes: minutesBefore));
}

String _formatBody(
  Event event,
  HebrewDate occurrenceDate,
  HebrewDateEngine engine,
) {
  final String dateStr =
      '${hebrewDayNumeral(occurrenceDate.day)} ב${engine.monthName(occurrenceDate.month)} '
      '${hebrewYearNumeral(occurrenceDate.year)}';
  if (event.allDay || event.startTime == null) {
    return '${event.title} · $dateStr';
  }
  return '${event.title} · $dateStr, ${event.startTime}';
}

/// Derives a stable, deterministic 31-bit non-negative notification id from
/// [eventId] + [occurrenceDate] + [minutesBefore].
///
/// Must NOT use [Object.hash]/`hashCode`: those are only guaranteed stable
/// within a single isolate run (they may vary between app launches, e.g.
/// due to hash-seed randomization or object identity), which would make
/// every replan after an app restart cancel and reschedule every existing
/// reminder instead of recognizing it as unchanged. Instead this is a
/// plain FNV-1a 32-bit hash over a plain-text key built only from the three
/// stable inputs — the same key always produces the same digest, in this
/// run or any future one, on any platform.
///
/// The digest is masked to 31 bits (`& 0x7FFFFFFF`) because
/// `flutter_local_notifications` uses the id as a native Android
/// notification/alarm id, which is a signed 32-bit int; masking off the
/// sign bit keeps it always non-negative.
int computeStableNotificationId({
  required String eventId,
  required HebrewDate occurrenceDate,
  required int minutesBefore,
}) {
  final String key =
      '$eventId|${occurrenceDate.year}|${occurrenceDate.month.index}|'
      '${occurrenceDate.day}|$minutesBefore';
  int hash = 0x811c9dc5;
  for (int i = 0; i < key.length; i++) {
    hash ^= key.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
