import 'event_time_of_day.dart';

/// Maximum event title length. Mirrored by Firestore Security Rules once
/// M2b lands (RULES.md §5.5 — client validation is never trusted alone).
const int kEventTitleMaxLength = 200;

/// Maximum event description length (see [kEventTitleMaxLength]).
const int kEventDescriptionMaxLength = 2000;

/// Maximum event location length (see [kEventTitleMaxLength]).
const int kEventLocationMaxLength = 500;

/// A single validation failure kind. Typed rather than a raw string so the
/// UI layer can map each one to a localized message, and so the same enum
/// can eventually be cross-checked against the Firestore rules test suite.
enum EventValidationErrorType {
  titleRequired,
  titleTooLong,
  descriptionTooLong,
  locationTooLong,
  endTimeNotAfterStartTime,
}

/// The outcome of [validateEvent]: zero or more [errors].
class EventValidationResult {
  const EventValidationResult(this.errors);

  final List<EventValidationErrorType> errors;

  bool get isValid => errors.isEmpty;

  bool has(EventValidationErrorType type) => errors.contains(type);
}

/// Validates event fields, pure and side-effect free so it can be reused
/// by both the event editor UI and (mirrored, not shared — rules can't run
/// Dart) the Firestore Security Rules.
///
/// [startTime]/[endTime] are only compared when both are provided; the
/// caller (e.g. the editor) is responsible for passing null for both when
/// the event is all-day.
EventValidationResult validateEvent({
  required String title,
  String description = '',
  String location = '',
  EventTimeOfDay? startTime,
  EventTimeOfDay? endTime,
}) {
  final List<EventValidationErrorType> errors = <EventValidationErrorType>[];

  final String trimmedTitle = title.trim();
  if (trimmedTitle.isEmpty) {
    errors.add(EventValidationErrorType.titleRequired);
  } else if (title.length > kEventTitleMaxLength) {
    errors.add(EventValidationErrorType.titleTooLong);
  }

  if (description.length > kEventDescriptionMaxLength) {
    errors.add(EventValidationErrorType.descriptionTooLong);
  }

  if (location.length > kEventLocationMaxLength) {
    errors.add(EventValidationErrorType.locationTooLong);
  }

  if (startTime != null && endTime != null && !(endTime > startTime)) {
    errors.add(EventValidationErrorType.endTimeNotAfterStartTime);
  }

  return EventValidationResult(errors);
}
