// Unit tests for the pure Event <-> Firestore-map mapping functions and the
// Hebrew-month -> Gregorian range helper (docs/TESTING_AND_DEPLOY.md:
// domain-adjacent conversion logic gets full unit coverage). None of this
// touches a live Firestore instance — only value types (Timestamp).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/event_firestore_mapper.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_attendee.dart';
import 'package:hebrew_calendar/domain/event/event_source.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/sync/sync_state.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

/// 5784 is a Hebrew leap year (has Adar I/Adar II); 5786 is not (has plain
/// Adar) — see `test/domain/hebrew_date/hebrew_date_engine_test.dart`.
/// [_baseEvent] picks whichever year makes [month] valid.
int _yearFor(HebrewMonth month) {
  switch (month) {
    case HebrewMonth.adarI:
    case HebrewMonth.adarII:
      return 5784;
    default:
      return 5786;
  }
}

Event _baseEvent({
  HebrewMonth month = HebrewMonth.tishrei,
  bool allDay = true,
  EventTimeOfDay? startTime,
  EventTimeOfDay? endTime,
  List<int> reminderMinutesBefore = const <int>[],
  RecurrenceRule recurrence = const RecurrenceRule(),
  String description = '',
  String location = '',
}) {
  // Local (not UTC) to match how the app actually produces createdAt/
  // updatedAt (`DateTime.now()`, always local) — `Timestamp.fromDate` /
  // `.toDate()` preserve the instant but always return a local `DateTime`,
  // so round-tripping a UTC fixture here would spuriously fail `DateTime`
  // equality (which, unlike `isAtSameMomentAs`, also compares the
  // UTC/local flag).
  final DateTime timestamp = DateTime(2026, 1, 1, 12, 30);
  return Event(
    id: 'event-1',
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: 'יום הולדת',
    description: description,
    location: location,
    hebrewDate: HebrewDate(year: _yearFor(month), month: month, day: 10),
    allDay: allDay,
    startTime: startTime,
    endTime: endTime,
    reminderMinutesBefore: reminderMinutesBefore,
    recurrence: recurrence,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

void main() {
  group('eventToFirestoreData / eventFromFirestoreData round trip', () {
    for (final HebrewMonth month in HebrewMonth.values) {
      test('round-trips an all-day event in ${month.name}', () {
        final Event original = _baseEvent(month: month);
        final Map<String, dynamic> data = eventToFirestoreData(
          event: original,
          engine: _engine,
        );
        final Event restored = eventFromFirestoreData(original.id, data);
        expect(restored, original);
      });
    }

    test('round-trips participants and their replies (M11)', () {
      final Event original = _baseEvent(month: HebrewMonth.cheshvan).copyWith(
        attendees: const <EventAttendee>[
          EventAttendee(email: 'a@example.com'),
          EventAttendee(
            email: 'b@example.com',
            response: AttendeeResponse.declined,
          ),
        ],
      );
      final Event restored = eventFromFirestoreData(
        original.id,
        eventToFirestoreData(event: original, engine: _engine),
      );
      expect(restored.attendees, original.attendees);
      expect(restored, original);
    });

    test('round-trips an event color (M10)', () {
      final Event original = _baseEvent(
        month: HebrewMonth.cheshvan,
      ).copyWith(colorId: '11');
      final Event restored = eventFromFirestoreData(
        original.id,
        eventToFirestoreData(event: original, engine: _engine),
      );
      expect(restored.colorId, '11');
      expect(restored, original);
    });

    test('round-trips start/end times and reminders', () {
      final Event original = _baseEvent(
        allDay: false,
        startTime: const EventTimeOfDay(hour: 9, minute: 5),
        endTime: const EventTimeOfDay(hour: 10, minute: 45),
        reminderMinutesBefore: const <int>[10, 30, 60],
      );
      final Map<String, dynamic> data = eventToFirestoreData(
        event: original,
        engine: _engine,
      );

      expect(data['startTime'], <String, dynamic>{'hour': 9, 'minute': 5});
      expect(data['endTime'], <String, dynamic>{'hour': 10, 'minute': 45});
      expect(data['reminderMinutesBefore'], <int>[10, 30, 60]);

      final Event restored = eventFromFirestoreData(original.id, data);
      expect(restored, original);
    });

    test('round-trips a recurrence rule with until and exceptions', () {
      final Event original = _baseEvent(
        recurrence: RecurrenceRule(
          type: RecurrenceType.hebrewYearly,
          until: const HebrewDate(
            year: 5790,
            month: HebrewMonth.tishrei,
            day: 10,
          ),
          exceptions: const <HebrewDate>[
            HebrewDate(year: 5787, month: HebrewMonth.tishrei, day: 10),
            HebrewDate(year: 5788, month: HebrewMonth.tishrei, day: 10),
          ],
        ),
      );
      final Map<String, dynamic> data = eventToFirestoreData(
        event: original,
        engine: _engine,
      );
      expect(data['isRecurring'], isTrue);
      expect(data['recurrence'], <String, dynamic>{
        'type': 'hebrewYearly',
        'until': <String, dynamic>{'year': 5790, 'month': 'tishrei', 'day': 10},
        'exceptions': <Map<String, dynamic>>[
          <String, dynamic>{'year': 5787, 'month': 'tishrei', 'day': 10},
          <String, dynamic>{'year': 5788, 'month': 'tishrei', 'day': 10},
        ],
      });
      final Event restored = eventFromFirestoreData(original.id, data);
      expect(restored, original);
      expect(restored.recurrence.exceptions, hasLength(2));
    });

    test('isRecurring is false for a non-recurring (none) event', () {
      final Event original = _baseEvent();
      final Map<String, dynamic> data = eventToFirestoreData(
        event: original,
        engine: _engine,
      );
      expect(data['isRecurring'], isFalse);
    });

    for (final RecurrenceType type in RecurrenceType.values) {
      test('isRecurring reflects RecurrenceType.${type.name}', () {
        final Event original = _baseEvent(
          recurrence: RecurrenceRule(type: type),
        );
        final Map<String, dynamic> data = eventToFirestoreData(
          event: original,
          engine: _engine,
        );
        expect(data['isRecurring'], type != RecurrenceType.none);
        // isRecurring is derived/write-only: reading it back never affects
        // the reconstructed Event, whose recurrence.type is the single
        // source of truth.
        final Event restored = eventFromFirestoreData(original.id, data);
        expect(restored.recurrence.type, type);
      });
    }

    test('handles null startTime/endTime and an empty recurrence', () {
      final Event original = _baseEvent();
      final Map<String, dynamic> data = eventToFirestoreData(
        event: original,
        engine: _engine,
      );

      expect(data['startTime'], isNull);
      expect(data['endTime'], isNull);
      expect(data['recurrence'], <String, dynamic>{
        'type': 'none',
        'until': null,
        'exceptions': <Map<String, dynamic>>[],
      });

      final Event restored = eventFromFirestoreData(original.id, data);
      expect(restored.startTime, isNull);
      expect(restored.endTime, isNull);
      expect(restored.recurrence, const RecurrenceRule());
    });

    test('round-trips description and location text', () {
      final Event original = _baseEvent(
        description: 'תיאור מפורט של האירוע',
        location: 'בית הכנסת המרכזי',
      );
      final Map<String, dynamic> data = eventToFirestoreData(
        event: original,
        engine: _engine,
      );
      final Event restored = eventFromFirestoreData(original.id, data);
      expect(restored, original);
    });

    test('falls back to now() when createdAt/updatedAt are still pending', () {
      final Event original = _baseEvent();
      final Map<String, dynamic> data = eventToFirestoreData(
        event: original,
        engine: _engine,
      )..['createdAt'] = null;
      data['updatedAt'] = null;

      final Event restored = eventFromFirestoreData(original.id, data);
      expect(restored.createdAt, isNotNull);
      expect(restored.updatedAt, isNotNull);
    });

    test('gregorianStart/End are Timestamps derived from the Hebrew date', () {
      final Event original = _baseEvent(
        allDay: false,
        startTime: const EventTimeOfDay(hour: 8, minute: 0),
        endTime: const EventTimeOfDay(hour: 9, minute: 0),
      );
      final Map<String, dynamic> data = eventToFirestoreData(
        event: original,
        engine: _engine,
      );

      final DateTime expectedDay = _engine.toGregorian(original.hebrewDate);
      final Timestamp start = data['gregorianStart'] as Timestamp;
      final Timestamp end = data['gregorianEnd'] as Timestamp;
      expect(
        start.toDate(),
        DateTime(expectedDay.year, expectedDay.month, expectedDay.day, 8),
      );
      expect(
        end.toDate(),
        DateTime(expectedDay.year, expectedDay.month, expectedDay.day, 9),
      );
    });

    test(
      'gregorianEnd is one day after gregorianStart for an all-day event',
      () {
        final Event original = _baseEvent();
        final Map<String, dynamic> data = eventToFirestoreData(
          event: original,
          engine: _engine,
        );
        final Timestamp start = data['gregorianStart'] as Timestamp;
        final Timestamp end = data['gregorianEnd'] as Timestamp;
        expect(
          end.toDate().difference(start.toDate()),
          const Duration(days: 1),
        );
      },
    );
  });

  group('M5a Google sync fields', () {
    test('round-trips a non-default source/googleSync/googleInstanceSync', () {
      final Event original = _baseEvent().copyWith(
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
      final Map<String, dynamic> data = eventToFirestoreData(
        event: original,
        engine: _engine,
      );
      expect(data['source'], 'google');
      final Event restored = eventFromFirestoreData(original.id, data);
      expect(restored, original);
      expect(restored.source, EventSource.google);
      expect(restored.googleSync.googleEventId, 'g-1');
      expect(restored.googleSync.dirty, isTrue);
      expect(
        restored.googleInstanceSync['5786-tishrei-10']?.googleEventId,
        'g-2',
      );
    });

    test(
      'defaults source to app and sync state to empty when missing from the map',
      () {
        final Event original = _baseEvent();
        final Map<String, dynamic> data =
            eventToFirestoreData(event: original, engine: _engine)
              ..remove('source')
              ..remove('googleSync')
              ..remove('googleInstanceSync');

        final Event restored = eventFromFirestoreData(original.id, data);
        expect(restored.source, EventSource.app);
        expect(restored.googleSync, const GoogleSyncState());
        expect(restored.googleInstanceSync, isEmpty);
      },
    );
  });

  group('hebrewMonthGregorianRange', () {
    test('spans exactly one Hebrew month, start to next month start', () {
      const int year = 5786;
      const HebrewMonth month = HebrewMonth.tishrei;
      final ({DateTime start, DateTime endExclusive}) range =
          hebrewMonthGregorianRange(_engine, year, month);

      expect(
        range.start,
        _engine.toGregorian(HebrewDate(year: year, month: month, day: 1)),
      );
      expect(
        range.endExclusive,
        _engine.toGregorian(
          _engine.nextMonth(HebrewDate(year: year, month: month, day: 1)),
        ),
      );
      expect(range.endExclusive.isAfter(range.start), isTrue);
    });

    test('handles the Adar I/Adar II split in a leap year', () {
      const int leapYear = 5784;
      expect(_engine.isLeapYear(leapYear), isTrue);

      final ({DateTime start, DateTime endExclusive}) adarI =
          hebrewMonthGregorianRange(_engine, leapYear, HebrewMonth.adarI);
      final ({DateTime start, DateTime endExclusive}) adarII =
          hebrewMonthGregorianRange(_engine, leapYear, HebrewMonth.adarII);

      // Adar II starts exactly where Adar I ends — no gap, no overlap.
      expect(adarI.endExclusive, adarII.start);
    });

    test('handles the year boundary (Elul -> Tishrei of the next year)', () {
      const int year = 5786;
      final ({DateTime start, DateTime endExclusive}) elul =
          hebrewMonthGregorianRange(_engine, year, HebrewMonth.elul);
      final ({DateTime start, DateTime endExclusive}) nextTishrei =
          hebrewMonthGregorianRange(_engine, year + 1, HebrewMonth.tishrei);

      expect(elul.endExclusive, nextTishrei.start);
    });
  });
}
