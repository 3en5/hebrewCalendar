/// Pure Event <-> Firestore-map conversion functions (ARCHITECTURE.md §4
/// schema) plus the Hebrew-month -> Gregorian range helper used to query
/// them. Kept separate from `firestore_event_repository.dart` so it is
/// unit-testable without a live Firestore instance/emulator — everything
/// here only touches value types from `cloud_firestore` ([Timestamp]),
/// never a [FirebaseFirestore] connection.
///
/// `createdAt`/`updatedAt` round-trip as plain [Timestamp]s here; the
/// repository is responsible for swapping in `FieldValue.serverTimestamp()`
/// for the fields actually written to the server on create/update (see its
/// doc comment for why).
///
/// `isRecurring` (M3a) is a derived, write-only convenience field: always
/// recomputed from `event.recurrence.type` on write so it can never drift
/// from the recurrence it summarizes, and never read back into [Event] on
/// [eventFromFirestoreData] (the [RecurrenceRule] read from `recurrence` is
/// the single source of truth). It exists purely so
/// `FirestoreEventRepository` can query "all of this user's recurring
/// events" as a plain equality filter instead of inspecting every event's
/// full recurrence map.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/event/event.dart';
import '../domain/event/event_source.dart';
import '../domain/event/event_time_of_day.dart';
import '../domain/event/recurrence_rule.dart';
import '../domain/hebrew_date/hebrew_date.dart';
import '../domain/hebrew_date/hebrew_date_engine.dart';
import '../domain/sync/sync_state.dart';

/// Converts [event] to the map shape stored at `events/{eventId}`.
Map<String, dynamic> eventToFirestoreData({
  required Event event,
  required HebrewDateEngine engine,
}) {
  final DateTime gregorianStart = _gregorianStart(event, engine);
  final DateTime gregorianEnd = _gregorianEnd(event, engine, gregorianStart);
  return <String, dynamic>{
    'ownerUid': event.ownerUid,
    'calendarId': event.calendarId,
    'title': event.title,
    'description': event.description,
    'location': event.location,
    'hebrewDate': _hebrewDateToMap(event.hebrewDate),
    'gregorianStart': Timestamp.fromDate(gregorianStart),
    'gregorianEnd': Timestamp.fromDate(gregorianEnd),
    'allDay': event.allDay,
    'startTime': event.startTime == null ? null : _timeToMap(event.startTime!),
    'endTime': event.endTime == null ? null : _timeToMap(event.endTime!),
    'reminderMinutesBefore': event.reminderMinutesBefore,
    'recurrence': _recurrenceToMap(event.recurrence),
    'isRecurring': event.recurrence.type != RecurrenceType.none,
    'createdAt': Timestamp.fromDate(event.createdAt),
    'updatedAt': Timestamp.fromDate(event.updatedAt),
    'source': event.source.name,
    'googleSync': syncStateToMap(event.googleSync),
    'googleInstanceSync': event.googleInstanceSync.map(
      (String key, GoogleSyncState value) =>
          MapEntry<String, dynamic>(key, syncStateToMap(value)),
    ),
  };
}

/// Reconstructs an [Event] with the given [id] from a raw Firestore
/// document [data] map (as returned by `DocumentSnapshot.data()`).
///
/// Missing/null optional fields fall back to the same defaults [Event]'s
/// constructor uses. `createdAt`/`updatedAt` fall back to [DateTime.now] if
/// the stored value is a still-pending `FieldValue.serverTimestamp()` (reads
/// as null in a local snapshot before the server acknowledges the write).
Event eventFromFirestoreData(String id, Map<String, dynamic> data) {
  final Map<String, dynamic>? startMap = _asStringMap(data['startTime']);
  final Map<String, dynamic>? endMap = _asStringMap(data['endTime']);
  final List<dynamic> remindersRaw =
      data['reminderMinutesBefore'] as List<dynamic>? ?? const <dynamic>[];

  return Event(
    id: id,
    ownerUid: data['ownerUid'] as String? ?? '',
    calendarId: data['calendarId'] as String? ?? '',
    title: data['title'] as String? ?? '',
    description: data['description'] as String? ?? '',
    location: data['location'] as String? ?? '',
    hebrewDate: _hebrewDateFromMap(_asStringMap(data['hebrewDate'])!),
    allDay: data['allDay'] as bool? ?? true,
    startTime: startMap == null ? null : _timeFromMap(startMap),
    endTime: endMap == null ? null : _timeFromMap(endMap),
    reminderMinutesBefore: remindersRaw
        .map((dynamic minutes) => (minutes as num).toInt())
        .toList(),
    recurrence: _recurrenceFromMap(_asStringMap(data['recurrence'])),
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    source: EventSource.values.byName(
      data['source'] as String? ?? EventSource.app.name,
    ),
    googleSync: syncStateFromMap(_asStringMap(data['googleSync'])),
    googleInstanceSync: instanceSyncFromMap(
      data['googleInstanceSync'] as Map<String, dynamic>?,
    ),
  );
}

/// The Gregorian `[start, endExclusive)` range spanned by Hebrew [month] of
/// [year], used to query `events` by `gregorianStart`
/// (`ownerUid`+`gregorianStart` composite index — ARCHITECTURE.md §4).
({DateTime start, DateTime endExclusive}) hebrewMonthGregorianRange(
  HebrewDateEngine engine,
  int year,
  HebrewMonth month,
) {
  final HebrewDate firstDayOfMonth = HebrewDate(
    year: year,
    month: month,
    day: 1,
  );
  final HebrewDate firstDayOfNextMonth = engine.nextMonth(firstDayOfMonth);
  return (
    start: engine.toGregorian(firstDayOfMonth),
    endExclusive: engine.toGregorian(firstDayOfNextMonth),
  );
}

DateTime _gregorianStart(Event event, HebrewDateEngine engine) {
  final DateTime day = engine.toGregorian(event.hebrewDate);
  final EventTimeOfDay? startTime = event.startTime;
  if (event.allDay || startTime == null) {
    return day;
  }
  return DateTime(
    day.year,
    day.month,
    day.day,
    startTime.hour,
    startTime.minute,
  );
}

DateTime _gregorianEnd(Event event, HebrewDateEngine engine, DateTime start) {
  final EventTimeOfDay? endTime = event.endTime;
  if (endTime != null) {
    final DateTime day = engine.toGregorian(event.hebrewDate);
    return DateTime(day.year, day.month, day.day, endTime.hour, endTime.minute);
  }
  // All-day events use an exclusive end boundary one day after the start,
  // matching Google Calendar's all-day event convention.
  return event.allDay ? start.add(const Duration(days: 1)) : start;
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
          (dynamic exception) => _hebrewDateFromMap(_asStringMap(exception)!),
        )
        .toList(),
  );
}

/// Firestore returns nested maps as `Map<String, dynamic>` on every
/// supported platform, but values coming back out of a `List` are typed
/// `dynamic` — this re-asserts the shape defensively rather than trusting
/// the cast to always succeed.
Map<String, dynamic>? _asStringMap(Object? value) {
  if (value == null) {
    return null;
  }
  return Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
}

Map<String, dynamic> syncStateToMap(GoogleSyncState state) => <String, dynamic>{
  'googleEventId': state.googleEventId,
  'etag': state.etag,
  'lastSyncedAt': state.lastSyncedAt == null
      ? null
      : Timestamp.fromDate(state.lastSyncedAt!),
  'dirty': state.dirty,
};

GoogleSyncState syncStateFromMap(Map<String, dynamic>? map) {
  if (map == null) {
    return const GoogleSyncState();
  }
  return GoogleSyncState(
    googleEventId: map['googleEventId'] as String?,
    etag: map['etag'] as String?,
    lastSyncedAt: (map['lastSyncedAt'] as Timestamp?)?.toDate(),
    dirty: map['dirty'] as bool? ?? false,
  );
}

Map<String, GoogleSyncState> instanceSyncFromMap(Map<String, dynamic>? map) {
  if (map == null) {
    return const <String, GoogleSyncState>{};
  }
  return map.map(
    (String key, dynamic value) => MapEntry<String, GoogleSyncState>(
      key,
      syncStateFromMap(_asStringMap(value)),
    ),
  );
}
