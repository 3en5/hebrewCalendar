/// JSON mapping between Google Calendar v3 event resources and our DTOs
/// (`GoogleEventWrite` out, `RemoteEventSnapshot` in) — split out of
/// `google_calendar_api_impl.dart` (RULES.md §2, 500-line limit).
library;

import '../../domain/event/event_attendee.dart';
import '../../domain/sync/remote_event_snapshot.dart';
import 'google_calendar_api.dart';

Map<String, dynamic> googleEventToJson(GoogleEventWrite event) =>
    <String, dynamic>{
      'summary': event.summary,
      'description': event.description,
      'location': event.location,
      // M10: Google's event color ("1".."11"); omitted = the calendar's color.
      if (event.colorId != null) 'colorId': event.colorId,
      // M11: Google sends the invitations (see `sendUpdates` on the request).
      // Always sent, even empty: an update is a PATCH, and a missing list
      // would leave the removed guests in Google.
      'attendees': <Map<String, String>>[
        for (final String email in event.attendeeEmails)
          <String, String>{'email': email},
      ],
      // The other kind is sent as null: a PATCH merges `start`/`end`, so an
      // all-day event made timed (or back) would otherwise keep its old
      // `date` beside the new `dateTime`, and Google rejects the update
      // (device report 2026-11-04).
      'start': _when(event.isAllDay, event.start),
      'end': _when(event.isAllDay, event.end),
      'extendedProperties': <String, dynamic>{
        'private': <String, String>{
          'hebcalEventId': event.hebcalEventId,
          'hebcalOccurrence': event.hebcalOccurrence,
        },
      },
    };

Map<String, String?> _when(bool allDay, DateTime at) => allDay
    ? <String, String?>{'date': _dateOnly(at), 'dateTime': null}
    : <String, String?>{'date': null, 'dateTime': at.toUtc().toIso8601String()};

String _dateOnly(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';

RemoteEventSnapshot googleEventFromJson(Map<String, dynamic> json) {
  final bool cancelled = json['status'] == 'cancelled';
  final Map<String, dynamic>? extendedPrivate =
      (json['extendedProperties'] as Map<String, dynamic>?)?['private']
          as Map<String, dynamic>?;
  final Map<String, dynamic>? start = json['start'] as Map<String, dynamic>?;
  final Map<String, dynamic>? end = json['end'] as Map<String, dynamic>?;
  return RemoteEventSnapshot(
    googleEventId: json['id'] as String,
    etag: json['etag'] as String? ?? '',
    updatedAt: DateTime.parse(
      json['updated'] as String? ?? DateTime.now().toIso8601String(),
    ),
    isCancelled: cancelled,
    summary: json['summary'] as String? ?? '',
    description: json['description'] as String? ?? '',
    location: json['location'] as String? ?? '',
    colorId: json['colorId'] as String?,
    attendees: _attendeesFromJson(json['attendees']),
    start: _parseEventDateTime(start),
    end: _parseEventDateTime(end),
    isAllDay: start != null && start['date'] != null,
    hebcalEventId: extendedPrivate?['hebcalEventId'] as String?,
    hebcalOccurrence: extendedPrivate?['hebcalOccurrence'] as String?,
  );
}

DateTime? _parseEventDateTime(Map<String, dynamic>? map) {
  if (map == null) {
    return null;
  }
  final String? dateTime = map['dateTime'] as String?;
  if (dateTime != null) {
    return DateTime.parse(dateTime).toLocal();
  }
  final String? date = map['date'] as String?;
  return date == null ? null : DateTime.parse(date);
}

List<EventAttendee> _attendeesFromJson(Object? raw) {
  if (raw is! List) {
    return const <EventAttendee>[];
  }
  return <EventAttendee>[
    for (final Object? item in raw)
      if (item is Map && item['email'] is String && item['self'] != true)
        EventAttendee(
          email: item['email'] as String,
          response: EventAttendee.responseFromGoogle(
            item['responseStatus'] as String?,
          ),
        ),
  ];
}
