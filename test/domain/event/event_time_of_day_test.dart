// Unit tests for the pure EventTimeOfDay value type: ordering, equality,
// copyWith and display formatting.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';

void main() {
  group('EventTimeOfDay ordering', () {
    test('minutesFromMidnight combines hour and minute', () {
      expect(
        const EventTimeOfDay(hour: 2, minute: 30).minutesFromMidnight,
        150,
      );
    });

    test('compareTo/operators order by minutesFromMidnight', () {
      const EventTimeOfDay early = EventTimeOfDay(hour: 9, minute: 0);
      const EventTimeOfDay late = EventTimeOfDay(hour: 10, minute: 30);

      expect(early.compareTo(late), lessThan(0));
      expect(early < late, isTrue);
      expect(early <= late, isTrue);
      expect(late > early, isTrue);
      expect(late >= early, isTrue);
      expect(early <= early, isTrue);
      expect(early >= early, isTrue);
    });
  });

  group('EventTimeOfDay equality', () {
    test('two times with the same hour/minute are equal', () {
      expect(
        const EventTimeOfDay(hour: 8, minute: 15),
        const EventTimeOfDay(hour: 8, minute: 15),
      );
      expect(
        const EventTimeOfDay(hour: 8, minute: 15).hashCode,
        const EventTimeOfDay(hour: 8, minute: 15).hashCode,
      );
    });

    test('differing minute makes times unequal', () {
      expect(
        const EventTimeOfDay(hour: 8, minute: 15),
        isNot(const EventTimeOfDay(hour: 8, minute: 16)),
      );
    });
  });

  group('EventTimeOfDay copyWith', () {
    test('leaves fields unchanged when no argument given', () {
      const EventTimeOfDay original = EventTimeOfDay(hour: 8, minute: 15);
      expect(original.copyWith(), original);
    });

    test('overwrites only the requested field', () {
      const EventTimeOfDay original = EventTimeOfDay(hour: 8, minute: 15);
      expect(
        original.copyWith(hour: 9),
        const EventTimeOfDay(hour: 9, minute: 15),
      );
      expect(
        original.copyWith(minute: 45),
        const EventTimeOfDay(hour: 8, minute: 45),
      );
    });
  });

  group('EventTimeOfDay toString', () {
    test('zero-pads hour and minute', () {
      expect(const EventTimeOfDay(hour: 9, minute: 5).toString(), '09:05');
      expect(const EventTimeOfDay(hour: 23, minute: 59).toString(), '23:59');
      expect(const EventTimeOfDay(hour: 0, minute: 0).toString(), '00:00');
    });
  });
}
