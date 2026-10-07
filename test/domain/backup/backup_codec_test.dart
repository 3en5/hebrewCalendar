// Unit tests for the pure backup JSON codec (ARCHITECTURE.md §7, M7):
// round-trips every field shape Event/RecurrenceRule/GoogleSyncState can
// take, and rejects a backup format version newer than this build
// understands. No Flutter/Firebase involved (docs/RULES.md §3 domain rule).

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/backup/backup_codec.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_source.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/sync/sync_state.dart';

// Local (not UTC) to match how the app actually produces createdAt/updatedAt
// (`DateTime.now()`, always local) — see docs/LESSONS.md on
// `Timestamp.toDate()` always being local; the same reasoning applies here
// to `DateTime.parse`, which returns local for a string with no `Z`/offset
// suffix (exactly what a local `DateTime.toIso8601String()` produces).
final DateTime _timestamp = DateTime(2026, 1, 1, 12, 30);

Event _baseEvent({
  String id = 'event-1',
  bool allDay = true,
  EventTimeOfDay? startTime,
  EventTimeOfDay? endTime,
  List<int> reminderMinutesBefore = const <int>[],
  RecurrenceRule recurrence = const RecurrenceRule(),
  EventSource source = EventSource.app,
  GoogleSyncState googleSync = const GoogleSyncState(),
  Map<String, GoogleSyncState> googleInstanceSync =
      const <String, GoogleSyncState>{},
}) => Event(
  id: id,
  ownerUid: 'uid-1',
  calendarId: 'default',
  title: 'יום הולדת',
  description: 'תיאור',
  location: 'בית',
  hebrewDate: const HebrewDate(year: 5786, month: HebrewMonth.tishrei, day: 10),
  allDay: allDay,
  startTime: startTime,
  endTime: endTime,
  reminderMinutesBefore: reminderMinutesBefore,
  recurrence: recurrence,
  createdAt: _timestamp,
  updatedAt: _timestamp,
  source: source,
  googleSync: googleSync,
  googleInstanceSync: googleInstanceSync,
);

BackupPayload _roundTrip(List<Event> events) => decodeBackup(
  encodeBackup(events: events, appVersion: '1.0.0', createdAt: _timestamp),
);

void main() {
  group('encodeBackup / decodeBackup round trip', () {
    test('round-trips a plain all-day event', () {
      final Event original = _baseEvent();
      final BackupPayload payload = _roundTrip(<Event>[original]);

      expect(payload.formatVersion, kBackupFormatVersion);
      expect(payload.appVersion, '1.0.0');
      expect(payload.createdAt, _timestamp);
      expect(payload.events, <Event>[original]);
    });

    test('round-trips start/end times and multiple reminders', () {
      final Event original = _baseEvent(
        allDay: false,
        startTime: const EventTimeOfDay(hour: 9, minute: 5),
        endTime: const EventTimeOfDay(hour: 10, minute: 45),
        reminderMinutesBefore: const <int>[0, 10, 30, 60, 1440],
      );
      final BackupPayload payload = _roundTrip(<Event>[original]);
      expect(payload.events.single, original);
    });

    test('round-trips a recurrence rule with until and exceptions', () {
      final Event original = _baseEvent(
        recurrence: const RecurrenceRule(
          type: RecurrenceType.hebrewYearly,
          until: HebrewDate(year: 5790, month: HebrewMonth.tishrei, day: 10),
          exceptions: <HebrewDate>[
            HebrewDate(year: 5787, month: HebrewMonth.tishrei, day: 10),
            HebrewDate(year: 5788, month: HebrewMonth.tishrei, day: 10),
          ],
        ),
      );
      final BackupPayload payload = _roundTrip(<Event>[original]);
      final Event restored = payload.events.single;
      expect(restored, original);
      expect(restored.recurrence.exceptions, hasLength(2));
    });

    for (final RecurrenceType type in RecurrenceType.values) {
      test('round-trips RecurrenceType.${type.name}', () {
        final Event original = _baseEvent(
          recurrence: RecurrenceRule(type: type),
        );
        final BackupPayload payload = _roundTrip(<Event>[original]);
        expect(payload.events.single.recurrence.type, type);
      });
    }

    test('round-trips a non-default source/googleSync/googleInstanceSync', () {
      final Event original = _baseEvent(
        source: EventSource.google,
        googleSync: GoogleSyncState(
          googleEventId: 'g-1',
          etag: 'etag-1',
          lastSyncedAt: DateTime(2026, 2, 1, 8),
          dirty: true,
        ),
        googleInstanceSync: <String, GoogleSyncState>{
          '5786-tishrei-10': const GoogleSyncState(googleEventId: 'g-2'),
        },
      );
      final BackupPayload payload = _roundTrip(<Event>[original]);
      final Event restored = payload.events.single;
      expect(restored, original);
      expect(restored.source, EventSource.google);
      expect(restored.googleSync.dirty, isTrue);
      expect(
        restored.googleInstanceSync['5786-tishrei-10']?.googleEventId,
        'g-2',
      );
    });

    test('round-trips default (empty) sync state and app source', () {
      final Event original = _baseEvent();
      final BackupPayload payload = _roundTrip(<Event>[original]);
      final Event restored = payload.events.single;
      expect(restored.source, EventSource.app);
      expect(restored.googleSync, const GoogleSyncState());
      expect(restored.googleInstanceSync, isEmpty);
    });

    test('handles null startTime/endTime and an empty recurrence', () {
      final Event original = _baseEvent();
      final BackupPayload payload = _roundTrip(<Event>[original]);
      final Event restored = payload.events.single;
      expect(restored.startTime, isNull);
      expect(restored.endTime, isNull);
      expect(restored.recurrence, const RecurrenceRule());
    });

    test('round-trips multiple events, preserving order', () {
      final Event first = _baseEvent(id: 'event-1');
      final Event second = _baseEvent(id: 'event-2');
      final BackupPayload payload = _roundTrip(<Event>[first, second]);
      expect(payload.events.map((Event e) => e.id), <String>[
        'event-1',
        'event-2',
      ]);
    });

    test('round-trips an empty event list', () {
      final BackupPayload payload = _roundTrip(<Event>[]);
      expect(payload.events, isEmpty);
      expect(payload.formatVersion, kBackupFormatVersion);
    });
  });

  group('format version rejection', () {
    test('decodeBackup accepts the current format version', () {
      final String json = encodeBackup(
        events: <Event>[_baseEvent()],
        appVersion: '1.0.0',
      );
      expect(() => decodeBackup(json), returnsNormally);
    });

    test(
      'decodeBackup throws BackupFormatVersionError for a newer version',
      () {
        final String json =
            encodeBackup(
              events: <Event>[_baseEvent()],
              appVersion: '1.0.0',
            ).replaceFirst(
              '"formatVersion":$kBackupFormatVersion',
              '"formatVersion":${kBackupFormatVersion + 1}',
            );
        expect(
          () => decodeBackup(json),
          throwsA(isA<BackupFormatVersionError>()),
        );
      },
    );

    test('an older format version is still accepted', () {
      final String json =
          encodeBackup(
            events: <Event>[_baseEvent()],
            appVersion: '1.0.0',
          ).replaceFirst(
            '"formatVersion":$kBackupFormatVersion',
            '"formatVersion":0',
          );
      final BackupPayload payload = decodeBackup(json);
      expect(payload.formatVersion, 0);
    });
  });
}
