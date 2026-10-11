/// JSON mapping between Google Calendar v3 event resources and our DTOs
/// (`GoogleEventWrite` out, `RemoteEventSnapshot` in) — split out of
/// `google_calendar_api_impl.dart` (RULES.md §2, 500-line limit).
library;

import '../../domain/sync/remote_event_snapshot.dart';
import 'google_calendar_api.dart';

Map<String, dynamic> googleEventToJson(GoogleEventWrite event) =>
    <String, dynamic>{
      'summary': event.summary,
      'description': event.description,
      'location': event.location,
      // M10: Google's event color ("1".."11"); omitted = the calendar's color.
      if (event.colorId != null) 'colorId': event.colorId,
      'start': event.isAllDay
          ? <String, String>{'date': _dateOnly(event.start)}
          : <String, String>{'dateTime': event.start.toUtc().toIso8601String()},
      'end': event.isAllDay
          ? <String, String>{'date': _dateOnly(event.end)}
          : <String, String>{'dateTime': event.end.toUtc().toIso8601String()},
      'extendedProperties': <String, dynamic>{
        'private': <String, String>{
          'hebcalEventId': event.hebcalEventId,
          'hebcalOccurrence': event.hebcalOccurrence,
        },
      },
    };

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
