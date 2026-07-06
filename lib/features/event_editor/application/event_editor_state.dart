import '../../../domain/event/event.dart';
import '../../../domain/event/event_time_of_day.dart';
import '../../../domain/event/event_validation.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';

/// Immutable UI state for the event editor screen, covering both create
/// and edit mode. Text fields (title/description/location) are mirrored
/// here as plain strings so [EventEditorController.save] can validate and
/// persist without reaching into the screen's `TextEditingController`s.
class EventEditorState {
  const EventEditorState({
    required this.hebrewDate,
    this.title = '',
    this.description = '',
    this.location = '',
    this.allDay = true,
    this.startTime,
    this.endTime,
    this.reminderMinutesBefore = const <int>[],
    this.errors = const <EventValidationErrorType>[],
    this.isSaving = false,
  });

  /// The initial state for creating a new event on [initialDate].
  factory EventEditorState.blank(HebrewDate initialDate) =>
      EventEditorState(hebrewDate: initialDate);

  /// The initial state for editing an existing [event].
  factory EventEditorState.fromEvent(Event event) => EventEditorState(
    hebrewDate: event.hebrewDate,
    title: event.title,
    description: event.description,
    location: event.location,
    allDay: event.allDay,
    startTime: event.startTime,
    endTime: event.endTime,
    reminderMinutesBefore: event.reminderMinutesBefore,
  );

  final HebrewDate hebrewDate;
  final String title;
  final String description;
  final String location;
  final bool allDay;
  final EventTimeOfDay? startTime;
  final EventTimeOfDay? endTime;
  final List<int> reminderMinutesBefore;
  final List<EventValidationErrorType> errors;
  final bool isSaving;

  bool hasError(EventValidationErrorType type) => errors.contains(type);

  EventEditorState copyWith({
    HebrewDate? hebrewDate,
    String? title,
    String? description,
    String? location,
    bool? allDay,
    EventTimeOfDay? startTime,
    bool clearStartTime = false,
    EventTimeOfDay? endTime,
    bool clearEndTime = false,
    List<int>? reminderMinutesBefore,
    List<EventValidationErrorType>? errors,
    bool? isSaving,
  }) => EventEditorState(
    hebrewDate: hebrewDate ?? this.hebrewDate,
    title: title ?? this.title,
    description: description ?? this.description,
    location: location ?? this.location,
    allDay: allDay ?? this.allDay,
    startTime: clearStartTime ? null : (startTime ?? this.startTime),
    endTime: clearEndTime ? null : (endTime ?? this.endTime),
    reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
    errors: errors ?? this.errors,
    isSaving: isSaving ?? this.isSaving,
  );
}
