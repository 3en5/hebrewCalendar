// Unit tests for the pure Event entity: equality and copyWith, including
// the "clear" flags that let a caller explicitly null out startTime/
// endTime (a plain `startTime: null` argument means "leave unchanged").

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';

Event _buildEvent({
  String id = 'event-1',
  String title = 'יום הולדת',
  List<int> reminderMinutesBefore = const <int>[10],
  EventTimeOfDay? startTime,
  EventTimeOfDay? endTime,
}) {
  final DateTime timestamp = DateTime(2026, 1, 1);
  return Event(
    id: id,
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: title,
    description: 'תיאור',
    location: 'בית',
    hebrewDate: const HebrewDate(
      year: 5786,
      month: HebrewMonth.tishrei,
      day: 5,
    ),
    startTime: startTime,
    endTime: endTime,
    reminderMinutesBefore: reminderMinutesBefore,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

void main() {
  group('Event equality', () {
    test('two events with identical fields are equal', () {
      expect(_buildEvent(), _buildEvent());
      expect(_buildEvent().hashCode, _buildEvent().hashCode);
    });

    test('differing title makes events unequal', () {
      expect(_buildEvent(title: 'א'), isNot(_buildEvent(title: 'ב')));
    });

    test('differing reminder lists make events unequal', () {
      expect(
        _buildEvent(reminderMinutesBefore: const <int>[10]),
        isNot(_buildEvent(reminderMinutesBefore: const <int>[30])),
      );
      expect(
        _buildEvent(reminderMinutesBefore: const <int>[10]),
        isNot(_buildEvent(reminderMinutesBefore: const <int>[10, 30])),
      );
    });

    test('default allDay event has no start/end time', () {
      final Event event = _buildEvent();
      expect(event.allDay, isTrue);
      expect(event.startTime, isNull);
      expect(event.endTime, isNull);
    });

    test('a timed event is equal to another with the same times', () {
      const EventTimeOfDay start = EventTimeOfDay(hour: 9, minute: 0);
      const EventTimeOfDay end = EventTimeOfDay(hour: 10, minute: 0);
      expect(
        _buildEvent(startTime: start, endTime: end),
        _buildEvent(startTime: start, endTime: end),
      );
    });
  });

  group('Event copyWith', () {
    test('leaves fields unchanged when no argument given', () {
      final Event original = _buildEvent();
      expect(original.copyWith(), original);
    });

    test('overwrites the requested field only', () {
      final Event original = _buildEvent();
      final Event updated = original.copyWith(title: 'עדכון');
      expect(updated.title, 'עדכון');
      expect(updated.description, original.description);
    });

    test('clearStartTime/clearEndTime null out the times', () {
      final Event timed = _buildEvent(
        startTime: const EventTimeOfDay(hour: 9, minute: 0),
        endTime: const EventTimeOfDay(hour: 10, minute: 0),
      );
      final Event cleared = timed.copyWith(
        clearStartTime: true,
        clearEndTime: true,
      );
      expect(cleared.startTime, isNull);
      expect(cleared.endTime, isNull);
    });

    test('passing a new startTime without clearStartTime updates it', () {
      final Event original = _buildEvent(
        startTime: const EventTimeOfDay(hour: 9, minute: 0),
      );
      const EventTimeOfDay newStart = EventTimeOfDay(hour: 11, minute: 30);
      final Event updated = original.copyWith(startTime: newStart);
      expect(updated.startTime, newStart);
    });

    test('recurrence defaults to type none and can be overridden', () {
      final Event original = _buildEvent();
      expect(original.recurrence, const RecurrenceRule());
      final Event updated = original.copyWith(
        recurrence: const RecurrenceRule(type: RecurrenceType.weekly),
      );
      expect(updated.recurrence.type, RecurrenceType.weekly);
    });
  });
}
