import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../domain/event/default_calendar_id.dart';
import '../../../domain/event/event.dart';
import '../../../domain/event/event_time_of_day.dart';
import '../../../domain/event/event_validation.dart';
import '../../../domain/event/recurrence_rule.dart';
import '../../../domain/event/recurring_edit.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../calendar/application/hebrew_date_engine_provider.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import 'event_editor_state.dart';
import 'event_repository_provider.dart';

export '../../../domain/event/default_calendar_id.dart' show kDefaultCalendarId;
export '../../../domain/event/recurring_edit.dart' show RecurringEditScope;

/// Placeholder identity used until Firebase Auth lands in M2b (ARCHITECTURE
/// §9 — M2 is split; M2a has no signed-in user yet).
const String kLocalOwnerUid = 'local-user';

/// Identifies which event the editor is working on: a blank [initialDate]
/// to create a new event, or an [existing] event to edit.
///
/// Value equality (hand-written: it used to be a record) is what
/// `NotifierProvider.autoDispose.family` needs to key provider instances
/// (two screens opened with equal args share one controller instance).
class EventEditorArgs {
  const EventEditorArgs({
    required this.initialDate,
    this.existing,
    this.scope = RecurringEditScope.allEvents,
    this.occurrenceDate,
  });

  /// The date a new event starts on (ignored when editing).
  final HebrewDate initialDate;

  /// The event being edited, or null to create one.
  final Event? existing;

  /// M9: for a recurring [existing], which occurrences the edit applies to.
  final RecurringEditScope scope;

  /// M9: the occurrence the user opened the editor from (required for
  /// [RecurringEditScope.thisOccurrence] / [RecurringEditScope.thisAndFollowing]).
  final HebrewDate? occurrenceDate;

  /// Whether this edit splits a recurring series rather than rewriting it.
  bool get isPartialSeriesEdit =>
      existing != null &&
      existing!.recurrence.type != RecurrenceType.none &&
      occurrenceDate != null &&
      scope != RecurringEditScope.allEvents;

  @override
  bool operator ==(Object other) =>
      other is EventEditorArgs &&
      other.initialDate == initialDate &&
      other.existing == existing &&
      other.scope == scope &&
      other.occurrenceDate == occurrenceDate;

  @override
  int get hashCode => Object.hash(initialDate, existing, scope, occurrenceDate);
}

/// The outcome of [EventEditorController.save]: whether the screen should
/// pop (success) or keep showing the now-populated inline errors (invalid).
enum EventEditorSaveResult { success, invalid }

/// Holds and mutates the in-progress state of the event editor, validating
/// and persisting on [save].
///
/// `autoDispose.family`: a fresh controller per editor screen instance,
/// discarded once that screen is popped (RULES.md §6.3) — edits are never
/// silently kept around after the user navigates away without saving.
class EventEditorController extends Notifier<EventEditorState> {
  EventEditorController(this._args);

  final EventEditorArgs _args;

  @override
  EventEditorState build() {
    final Event? existing = _args.existing;
    if (existing == null) {
      return EventEditorState.blank(_args.initialDate);
    }
    final EventEditorState fromEvent = EventEditorState.fromEvent(existing);
    if (!_args.isPartialSeriesEdit) {
      return fromEvent;
    }
    // M9: editing from a specific occurrence starts on that occurrence's
    // Hebrew date; "this occurrence only" also drops the recurrence (it
    // becomes a standalone event).
    final EventEditorState onOccurrence = fromEvent.copyWith(
      hebrewDate: _args.occurrenceDate,
    );
    return _args.scope == RecurringEditScope.thisOccurrence
        ? onOccurrence.copyWith(
            recurrenceType: RecurrenceType.none,
            clearRecurrenceUntil: true,
          )
        : onOccurrence;
  }

  void setTitle(String value) => state = state.copyWith(title: value);

  void setDescription(String value) =>
      state = state.copyWith(description: value);

  void setLocation(String value) => state = state.copyWith(location: value);

  void setHebrewDate(HebrewDate date) =>
      state = state.copyWith(hebrewDate: date);

  void setAllDay(bool value) {
    state = value
        ? state.copyWith(allDay: true, clearStartTime: true, clearEndTime: true)
        : state.copyWith(allDay: false);
  }

  void setStartTime(EventTimeOfDay? time) {
    state = time == null
        ? state.copyWith(clearStartTime: true)
        : state.copyWith(startTime: time);
  }

  void setEndTime(EventTimeOfDay? time) {
    state = time == null
        ? state.copyWith(clearEndTime: true)
        : state.copyWith(endTime: time);
  }

  /// Sets the single reminder offset, or clears it when [minutesBefore] is
  /// null. M2a only exposes one reminder slot (task brief §4 — "as a
  /// start"); [Event.reminderMinutesBefore] is already a list so adding
  /// multiple reminders later needs no data-shape change.
  void setReminderMinutesBefore(int? minutesBefore) {
    state = state.copyWith(
      reminderMinutesBefore: minutesBefore == null
          ? const <int>[]
          : <int>[minutesBefore],
    );
  }

  /// Sets the recurrence type (M3a). Switching to [RecurrenceType.none]
  /// also clears any "repeat until" date — it would otherwise linger
  /// invisibly and reappear if the user picks a repeating type again.
  void setRecurrenceType(RecurrenceType type) {
    state = type == RecurrenceType.none
        ? state.copyWith(recurrenceType: type, clearRecurrenceUntil: true)
        : state.copyWith(recurrenceType: type);
  }

  /// Sets (or, when [until] is null, clears) the "repeat until" date.
  void setColorId(String? colorId) => state = colorId == null
      ? state.copyWith(clearColorId: true)
      : state.copyWith(colorId: colorId);

  void setRecurrenceUntil(HebrewDate? until) {
    state = until == null
        ? state.copyWith(clearRecurrenceUntil: true)
        : state.copyWith(recurrenceUntil: until);
  }

  Future<EventEditorSaveResult> save() async {
    final EventValidationResult result = validateEvent(
      title: state.title,
      description: state.description,
      location: state.location,
      startTime: state.allDay ? null : state.startTime,
      endTime: state.allDay ? null : state.endTime,
    );
    if (!result.isValid) {
      state = state.copyWith(errors: result.errors);
      return EventEditorSaveResult.invalid;
    }

    state = state.copyWith(
      errors: const <EventValidationErrorType>[],
      isSaving: true,
    );

    final Event? existing = _args.existing;
    final DateTime now = DateTime.now();
    final Event base =
        existing ??
        Event(
          id: '',
          ownerUid: kLocalOwnerUid,
          calendarId: kDefaultCalendarId,
          title: state.title.trim(),
          hebrewDate: state.hebrewDate,
          createdAt: now,
          updatedAt: now,
        );
    final Event draft = base.copyWith(
      title: state.title.trim(),
      description: state.description,
      location: state.location,
      hebrewDate: state.hebrewDate,
      allDay: state.allDay,
      startTime: state.allDay ? null : state.startTime,
      clearStartTime: state.allDay || state.startTime == null,
      endTime: state.allDay ? null : state.endTime,
      clearEndTime: state.allDay || state.endTime == null,
      reminderMinutesBefore: state.reminderMinutesBefore,
      colorId: state.colorId,
      clearColorId: state.colorId == null,
      recurrence: RecurrenceRule(
        type: state.recurrenceType,
        until: state.recurrenceType == RecurrenceType.none
            ? null
            : state.recurrenceUntil,
        exceptions: state.recurrenceExceptions,
      ),
    );

    final repository = ref.read(eventRepositoryProvider);
    if (existing == null) {
      await repository.create(draft);
    } else if (_args.isPartialSeriesEdit) {
      final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
      final RecurringChangePlan plan = planRecurringEdit(
        series: existing,
        edited: draft,
        occurrenceDate: _args.occurrenceDate!,
        scope: _args.scope,
        engine: engine,
      );
      if (plan.updatedSeries != null) {
        await repository.update(plan.updatedSeries!);
      }
      if (plan.newEvent != null) {
        await repository.create(plan.newEvent!);
      }
    } else {
      await repository.update(draft);
    }

    state = state.copyWith(isSaving: false);
    return EventEditorSaveResult.success;
  }
}

/// The event editor's Riverpod state, one instance per [EventEditorArgs].
final NotifierProviderFamily<
  EventEditorController,
  EventEditorState,
  EventEditorArgs
>
eventEditorControllerProvider = NotifierProvider.autoDispose
    .family<EventEditorController, EventEditorState, EventEditorArgs>(
      EventEditorController.new,
    );
