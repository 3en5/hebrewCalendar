/// Pure serialization of a user's full event list to/from a backup JSON
/// string (ARCHITECTURE.md §7, M7 — "manual export to a JSON file ... and
/// restore from it in the settings screen").
///
/// Mirrors the map shape `lib/data/event_firestore_mapper.dart` uses for
/// Firestore documents (same field set, same nested-map structure for
/// [HebrewDate]/[EventTimeOfDay]/[RecurrenceRule]/[GoogleSyncState]), but
/// deliberately decoupled from `cloud_firestore` types so this file has zero
/// Firebase/Flutter dependency (ARCHITECTURE.md §3 — domain stays plugin
/// free) and is unit-testable in complete isolation: every [DateTime]
/// (`createdAt`/`updatedAt`/`lastSyncedAt`) round-trips as an ISO 8601
/// string via `dart:convert`'s `jsonEncode`/`jsonDecode` instead of a
/// Firestore `Timestamp`.
library;

import 'dart:convert';

import '../event/event.dart';
import '../event/event_attendee.dart';
import '../event/event_source.dart';
import '../event/event_time_of_day.dart';
import '../event/recurrence_rule.dart';
import '../hebrew_date/hebrew_date.dart';
import '../sync/sync_state.dart';

/// The current backup file format version. Bump this whenever the JSON
/// shape below changes in a way an older build of the app can't read;
/// [decodeBackup] rejects anything newer than this with
/// [BackupFormatVersionError] rather than guessing at an unknown shape.
const int kBackupFormatVersion = 1;

/// A decoded backup file: every event plus metadata about when/by which app
/// version it was produced.
class BackupPayload {
  const BackupPayload({
    required this.formatVersion,
    required this.appVersion,
    required this.createdAt,
    required this.events,
  });

  final int formatVersion;
  final String appVersion;
  final DateTime createdAt;
  final List<Event> events;
}

/// Thrown by [decodeBackup] when the file's `formatVersion` is newer than
/// [kBackupFormatVersion] — e.g. a backup made by a future version of the
/// app being restored on an older install that doesn't know its shape yet.
/// Typed (rather than a generic [FormatException]) so
/// `lib/data/backup/backup_service.dart` can show a specific Hebrew message
/// instead of a generic "couldn't read this file" one.
class BackupFormatVersionError implements Exception {
  const BackupFormatVersionError({
    required this.foundVersion,
    required this.maxSupportedVersion,
  });

  final int foundVersion;
  final int maxSupportedVersion;

  @override
  String toString() =>
      'BackupFormatVersionError(found: $foundVersion, '
      'maxSupported: $maxSupportedVersion)';
}

/// Encodes [events] (the signed-in user's full event list, as returned by
/// `EventRepository.getAllForSync`) to a JSON string.
String encodeBackup({
  required List<Event> events,
  required String appVersion,
  DateTime? createdAt,
}) {
  final Map<String, dynamic> root = <String, dynamic>{
    'formatVersion': kBackupFormatVersion,
    'appVersion': appVersion,
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    'events': events.map(_eventToBackupMap).toList(),
  };
  return jsonEncode(root);
}

/// Decodes a backup JSON [source] string produced by [encodeBackup].
///
/// Throws [BackupFormatVersionError] if `formatVersion` is newer than
/// [kBackupFormatVersion]. Throws [FormatException]/a type error for
/// malformed JSON (not a backup file produced by this app at all) —
/// `backup_service.dart` catches those broadly and surfaces a generic
/// "couldn't read this file" error.
BackupPayload decodeBackup(String source) {
  final Map<String, dynamic> root = Map<String, dynamic>.from(
    jsonDecode(source) as Map<dynamic, dynamic>,
  );
  final int formatVersion = root['formatVersion'] as int;
  if (formatVersion > kBackupFormatVersion) {
    throw BackupFormatVersionError(
      foundVersion: formatVersion,
      maxSupportedVersion: kBackupFormatVersion,
    );
  }
  final List<dynamic> rawEvents =
      root['events'] as List<dynamic>? ?? const <dynamic>[];
  return BackupPayload(
    formatVersion: formatVersion,
    appVersion: root['appVersion'] as String? ?? '',
    createdAt: DateTime.parse(root['createdAt'] as String),
    events: rawEvents
        .map(
          (dynamic raw) => _eventFromBackupMap(
            Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
          ),
        )
        .toList(),
  );
}

Map<String, dynamic> _eventToBackupMap(Event event) => <String, dynamic>{
  'id': event.id,
  'ownerUid': event.ownerUid,
  'calendarId': event.calendarId,
  'title': event.title,
  'description': event.description,
  'location': event.location,
  'colorId': event.colorId,
  'attendees': attendeesToMaps(event.attendees),
  'hebrewDate': _hebrewDateToMap(event.hebrewDate),
  'allDay': event.allDay,
  'startTime': event.startTime == null ? null : _timeToMap(event.startTime!),
  'endTime': event.endTime == null ? null : _timeToMap(event.endTime!),
  'reminderMinutesBefore': event.reminderMinutesBefore,
  'recurrence': _recurrenceToMap(event.recurrence),
  'createdAt': event.createdAt.toIso8601String(),
  'updatedAt': event.updatedAt.toIso8601String(),
  'source': event.source.name,
  'googleSync': _syncStateToMap(event.googleSync),
  'googleInstanceSync': event.googleInstanceSync.map(
    (String key, GoogleSyncState value) =>
        MapEntry<String, dynamic>(key, _syncStateToMap(value)),
  ),
};

Event _eventFromBackupMap(Map<String, dynamic> map) {
  final Map<String, dynamic>? startMap = _asStringMap(map['startTime']);
  final Map<String, dynamic>? endMap = _asStringMap(map['endTime']);
  final List<dynamic> remindersRaw =
      map['reminderMinutesBefore'] as List<dynamic>? ?? const <dynamic>[];
  return Event(
    id: map['id'] as String? ?? '',
    ownerUid: map['ownerUid'] as String? ?? '',
    calendarId: map['calendarId'] as String? ?? '',
    title: map['title'] as String? ?? '',
    description: map['description'] as String? ?? '',
    location: map['location'] as String? ?? '',
    colorId: map['colorId'] as String?,
    attendees: attendeesFromMaps(map['attendees']),
    hebrewDate: _hebrewDateFromMap(_asStringMap(map['hebrewDate'])!),
    allDay: map['allDay'] as bool? ?? true,
    startTime: startMap == null ? null : _timeFromMap(startMap),
    endTime: endMap == null ? null : _timeFromMap(endMap),
    reminderMinutesBefore: remindersRaw
        .map((dynamic minutes) => (minutes as num).toInt())
        .toList(),
    recurrence: _recurrenceFromMap(_asStringMap(map['recurrence'])),
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
    source: EventSource.values.byName(
      map['source'] as String? ?? EventSource.app.name,
    ),
    googleSync: _syncStateFromMap(_asStringMap(map['googleSync'])),
    googleInstanceSync: _instanceSyncFromMap(
      _asStringMap(map['googleInstanceSync']),
    ),
  );
}

Map<String, dynamic> _hebrewDateToMap(HebrewDate date) => <String, dynamic>{
  'year': date.year,
  'month': date.month.name,
  'day': date.day,
};

HebrewDate _hebrewDateFromMap(Map<String, dynamic> map) => HebrewDate(
  year: map['year'] as int,
  month: HebrewMonth.values.byName(map['month'] as String),
  day: map['day'] as int,
);

Map<String, dynamic> _timeToMap(EventTimeOfDay time) => <String, dynamic>{
  'hour': time.hour,
  'minute': time.minute,
};

EventTimeOfDay _timeFromMap(Map<String, dynamic> map) =>
    EventTimeOfDay(hour: map['hour'] as int, minute: map['minute'] as int);

Map<String, dynamic> _recurrenceToMap(RecurrenceRule recurrence) =>
    <String, dynamic>{
      'type': recurrence.type.name,
      'until': recurrence.until == null
          ? null
          : _hebrewDateToMap(recurrence.until!),
      'exceptions': recurrence.exceptions
          .map(_hebrewDateToMap)
          .toList(growable: false),
    };

RecurrenceRule _recurrenceFromMap(Map<String, dynamic>? map) {
  if (map == null) {
    return const RecurrenceRule();
  }
  final Map<String, dynamic>? untilMap = _asStringMap(map['until']);
  final List<dynamic> exceptionsRaw =
      map['exceptions'] as List<dynamic>? ?? const <dynamic>[];
  return RecurrenceRule(
    type: RecurrenceType.values.byName(
      map['type'] as String? ?? RecurrenceType.none.name,
    ),
    until: untilMap == null ? null : _hebrewDateFromMap(untilMap),
    exceptions: exceptionsRaw
        .map(
          (dynamic exception) => _hebrewDateFromMap(
            Map<String, dynamic>.from(exception as Map<dynamic, dynamic>),
          ),
        )
        .toList(),
  );
}

Map<String, dynamic> _syncStateToMap(GoogleSyncState state) =>
    <String, dynamic>{
      'googleEventId': state.googleEventId,
      'etag': state.etag,
      'lastSyncedAt': state.lastSyncedAt?.toIso8601String(),
      'dirty': state.dirty,
    };

GoogleSyncState _syncStateFromMap(Map<String, dynamic>? map) {
  if (map == null) {
    return const GoogleSyncState();
  }
  final String? lastSyncedAt = map['lastSyncedAt'] as String?;
  return GoogleSyncState(
    googleEventId: map['googleEventId'] as String?,
    etag: map['etag'] as String?,
    lastSyncedAt: lastSyncedAt == null ? null : DateTime.parse(lastSyncedAt),
    dirty: map['dirty'] as bool? ?? false,
  );
}

Map<String, GoogleSyncState> _instanceSyncFromMap(Map<String, dynamic>? map) {
  if (map == null) {
    return const <String, GoogleSyncState>{};
  }
  return map.map(
    (String key, dynamic value) => MapEntry<String, GoogleSyncState>(
      key,
      _syncStateFromMap(_asStringMap(value)),
    ),
  );
}

/// `jsonDecode` returns nested objects typed `Map<String, dynamic>` already,
/// but values coming out of a `List` (recurrence exceptions,
/// `googleInstanceSync` entries) are typed `dynamic` — this re-asserts the
/// shape defensively rather than trusting the cast to always succeed,
/// mirroring `event_firestore_mapper.dart`'s `_asStringMap`.
Map<String, dynamic>? _asStringMap(Object? value) {
  if (value == null) {
    return null;
  }
  return Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
}
