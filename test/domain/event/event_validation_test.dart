import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';
import 'package:hebrew_calendar/domain/event/event_validation.dart';

void main() {
  group('validateEvent', () {
    test('is valid for a minimal title-only event', () {
      final EventValidationResult result = validateEvent(title: 'מסיבה');
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('requires a non-empty title', () {
      final EventValidationResult result = validateEvent(title: '');
      expect(result.isValid, isFalse);
      expect(result.has(EventValidationErrorType.titleRequired), isTrue);
    });

    test('requires a non-whitespace-only title', () {
      final EventValidationResult result = validateEvent(title: '   ');
      expect(result.has(EventValidationErrorType.titleRequired), isTrue);
    });

    test('rejects a title over the max length', () {
      final String longTitle = 'א' * (kEventTitleMaxLength + 1);
      final EventValidationResult result = validateEvent(title: longTitle);
      expect(result.has(EventValidationErrorType.titleTooLong), isTrue);
    });

    test('accepts a title exactly at the max length', () {
      final String maxTitle = 'א' * kEventTitleMaxLength;
      final EventValidationResult result = validateEvent(title: maxTitle);
      expect(result.isValid, isTrue);
    });

    test('rejects a description over the max length', () {
      final String longDescription = 'א' * (kEventDescriptionMaxLength + 1);
      final EventValidationResult result = validateEvent(
        title: 'כותרת',
        description: longDescription,
      );
      expect(result.has(EventValidationErrorType.descriptionTooLong), isTrue);
    });

    test('rejects a location over the max length', () {
      final String longLocation = 'א' * (kEventLocationMaxLength + 1);
      final EventValidationResult result = validateEvent(
        title: 'כותרת',
        location: longLocation,
      );
      expect(result.has(EventValidationErrorType.locationTooLong), isTrue);
    });

    test('accepts an end time strictly after the start time', () {
      final EventValidationResult result = validateEvent(
        title: 'כותרת',
        startTime: const EventTimeOfDay(hour: 9, minute: 0),
        endTime: const EventTimeOfDay(hour: 10, minute: 0),
      );
      expect(result.isValid, isTrue);
    });

    test('rejects an end time equal to the start time', () {
      final EventValidationResult result = validateEvent(
        title: 'כותרת',
        startTime: const EventTimeOfDay(hour: 9, minute: 0),
        endTime: const EventTimeOfDay(hour: 9, minute: 0),
      );
      expect(
        result.has(EventValidationErrorType.endTimeNotAfterStartTime),
        isTrue,
      );
    });

    test('rejects an end time before the start time', () {
      final EventValidationResult result = validateEvent(
        title: 'כותרת',
        startTime: const EventTimeOfDay(hour: 10, minute: 0),
        endTime: const EventTimeOfDay(hour: 9, minute: 0),
      );
      expect(
        result.has(EventValidationErrorType.endTimeNotAfterStartTime),
        isTrue,
      );
    });

    test('collects multiple simultaneous errors', () {
      final EventValidationResult result = validateEvent(
        title: '',
        startTime: const EventTimeOfDay(hour: 10, minute: 0),
        endTime: const EventTimeOfDay(hour: 9, minute: 0),
      );
      expect(result.errors, hasLength(2));
      expect(result.has(EventValidationErrorType.titleRequired), isTrue);
      expect(
        result.has(EventValidationErrorType.endTimeNotAfterStartTime),
        isTrue,
      );
    });
  });
}
