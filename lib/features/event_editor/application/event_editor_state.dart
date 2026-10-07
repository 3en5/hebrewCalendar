import '../../../domain/event/event.dart';
import '../../../domain/event/event_time_of_day.dart';
import '../../../domain/event/event_validation.dart';
import '../../../domain/event/recurrence_rule.dart';
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
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceUntil,
    this.recurrenceExceptions = const <HebrewDate>[],
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
    recurrenceType: event.recurrence.type,
    recurrenceUntil: event.recurrence.until,
    recurrenceExceptions: event.recurrence.exceptions,
  );

  final HebrewDate hebrewDate;
  final String title;
  final String description;
  final String location;
  final bool allDay;
  final EventTimeOfDay? startTime;
  final EventTimeOfDay? endTime;
  final List<int> reminderMinutesBefore;

  /// How the event repeats (M3a). [RecurrenceType.none] means it doesn't.
  final RecurrenceType recurrenceType;

  /// The inclusive date the series stops at, or null to repeat
  /// indefinitely. Meaningless (and ignored on save) when [recurrenceType]
  /// is [RecurrenceType.none].
  final HebrewDate? recurrenceUntil;

  /// Occurrences excluded from the series (e.g. via the day sheet's "this
  /// occurrence only" delete). Not directly editable in this screen — just
  /// carried through unchanged from the [Event] being edited so saving
  /// never silently drops previously-recorded exceptions.
  final List<HebrewDate> recurrenceExceptions;

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
    RecurrenceType? recurrenceType,
    HebrewDate? recurrenceUntil,
    bool clearRecurrenceUntil = false,
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
    recurrenceType: recurrenceType ?? this.recurrenceType,
    recurrenceUntil: clearRecurrenceUntil
        ? null
        : (recurrenceUntil ?? this.recurrenceUntil),
    recurrenceExceptions: recurrenceExceptions,
    errors: errors ?? this.errors,
    isSaving: isSaving ?? this.isSaving,
  );
}
