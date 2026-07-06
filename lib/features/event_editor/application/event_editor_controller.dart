import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../domain/event/event.dart';
import '../../../domain/event/event_time_of_day.dart';
import '../../../domain/event/event_validation.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import 'event_editor_state.dart';
import 'event_repository_provider.dart';

/// Placeholder identity used until Firebase Auth lands in M2b (ARCHITECTURE
/// §9 — M2 is split; M2a has no signed-in user yet).
const String kLocalOwnerUid = 'local-user';

/// Placeholder calendar id used until per-user calendars (ARCHITECTURE §4,
/// `users/{uid}/calendars/{calId}`) land alongside Firebase Auth in M2b.
const String kDefaultCalendarId = 'default';

/// Identifies which event the editor is working on: a blank [initialDate]
/// to create a new event, or an [existing] event to edit.
///
/// A record gets free structural equality, which is exactly what
/// `NotifierProvider.autoDispose.family` needs to key provider instances
/// (two screens opened with equal args share one controller instance).
typedef EventEditorArgs = ({HebrewDate initialDate, Event? existing});

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
    return existing != null
        ? EventEditorState.fromEvent(existing)
        : EventEditorState.blank(_args.initialDate);
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
    );

    final repository = ref.read(eventRepositoryProvider);
    if (existing == null) {
      await repository.create(draft);
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
