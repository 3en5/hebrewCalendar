/// Turning a Google event ([RemoteEventSnapshot]) into local [Event]
/// fields — shared by both repositories' import path and by
/// `own_export_changes.dart` (M17).
library;

import '../../domain/event/event.dart';
import '../../domain/event/event_time_of_day.dart';
import '../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../domain/sync/remote_event_snapshot.dart';
import '../../domain/sync/sync_state.dart';

/// The start time of a timed Google event, or null for an all-day one.
EventTimeOfDay? remoteStartTime(RemoteEventSnapshot remote) {
  final DateTime? start = remote.start;
  if (remote.isAllDay || start == null) {
    return null;
  }
  return EventTimeOfDay(hour: start.hour, minute: start.minute);
}

/// The end time of a timed Google event that ends later the same day, else
/// null (the app's events have one Hebrew date, so an end past midnight is
/// left out rather than misread as earlier than the start).
EventTimeOfDay? remoteEndTime(RemoteEventSnapshot remote) {
  final DateTime? start = remote.start;
  final DateTime? end = remote.end;
  if (remote.isAllDay || start == null || end == null || !end.isAfter(start)) {
    return null;
  }
  if (end.year != start.year ||
      end.month != start.month ||
      end.day != start.day) {
    return null;
  }
  return EventTimeOfDay(hour: end.hour, minute: end.minute);
}

/// [base] with the content Google reports for it: title, description,
/// location, color, date and times. Everything else (reminders, source,
/// recurrence, participants' list) stays as it is in [base]; the Google
/// sync state records [remote]'s id and etag, not dirty.
Event withRemoteContent(
  Event base,
  RemoteEventSnapshot remote,
  HebrewDateEngine engine,
  DateTime now,
) {
  final EventTimeOfDay? startTime = remoteStartTime(remote);
  final EventTimeOfDay? endTime = remoteEndTime(remote);
  return base.copyWith(
    title: remote.summary,
    description: remote.description,
    location: remote.location,
    colorId: remote.colorId,
    clearColorId: remote.colorId == null,
    hebrewDate: engine.fromGregorian(remote.start ?? now),
    allDay: remote.isAllDay,
    startTime: startTime,
    clearStartTime: startTime == null,
    endTime: endTime,
    clearEndTime: endTime == null,
    attendees: remote.attendees.isEmpty ? null : remote.attendees,
    updatedAt: remote.updatedAt,
    googleSync: GoogleSyncState(
      googleEventId: remote.googleEventId,
      etag: remote.etag,
      lastSyncedAt: now,
    ),
  );
}
