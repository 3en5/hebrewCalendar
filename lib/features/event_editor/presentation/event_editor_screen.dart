import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/event/event_validation.dart';
import '../../../domain/event/recurrence_rule.dart';
import '../../../l10n/app_localizations.dart';
import '../application/event_editor_controller.dart';
import '../application/event_editor_state.dart';
import 'widgets/event_time_section.dart';
import 'widgets/hebrew_date_picker_field.dart';
import 'widgets/recurrence_type_selector.dart';
import 'widgets/recurrence_until_field.dart';
import 'widgets/reminder_selector.dart';

/// Create/edit screen for a single event (Google-Calendar-like, RTL).
///
/// [args] identifies create vs. edit mode — see [EventEditorArgs]. Text
/// fields are backed by [TextEditingController]s owned by this widget and
/// disposed in [dispose] (RULES.md §6.1); their authoritative value lives
/// in [EventEditorController] so validation and persistence never need to
/// reach back into the controllers.
class EventEditorScreen extends ConsumerStatefulWidget {
  const EventEditorScreen({required this.args, super.key});

  final EventEditorArgs args;

  @override
  ConsumerState<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends ConsumerState<EventEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    final EventEditorState initial = ref.read(
      eventEditorControllerProvider(widget.args),
    );
    _titleController = TextEditingController(text: initial.title);
    _descriptionController = TextEditingController(text: initial.description);
    _locationController = TextEditingController(text: initial.location);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  EventEditorController get _controller =>
      ref.read(eventEditorControllerProvider(widget.args).notifier);

  Future<void> _save() async {
    final EventEditorSaveResult result = await _controller.save();
    if (result == EventEditorSaveResult.success && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final EventEditorState state = ref.watch(
      eventEditorControllerProvider(widget.args),
    );
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isEditing = widget.args.existing != null;
    final bool editsSingleOccurrence =
        widget.args.isPartialSeriesEdit &&
        widget.args.scope == RecurringEditScope.thisOccurrence;
    final String? scopeNote = !widget.args.isPartialSeriesEdit
        ? null
        : editsSingleOccurrence
        ? l10n.eventEditorScopeThisOccurrenceNote
        : l10n.eventEditorScopeThisAndFollowingNote;

    // The save action lives in the app bar (not the scrollable body) so it
    // is always reachable regardless of scroll position or keyboard state.
    // `resizeToAvoidBottomInset` (default true, kept explicit here) shrinks
    // the body when the keyboard opens; on top of that the ListView's own
    // bottom padding must grow by `MediaQuery.viewInsets.bottom` so the last
    // field (the recurrence "until date" row) can still be scrolled fully
    // above the keyboard instead of staying cut off behind it.
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          isEditing ? l10n.eventEditorTitleEdit : l10n.eventEditorTitleNew,
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: l10n.eventSave,
            onPressed: state.isSaving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsetsDirectional.only(
          start: spacingMd,
          end: spacingMd,
          top: spacingMd,
          bottom: spacingMd + spacingXxl + keyboardInset,
        ),
        children: <Widget>[
          if (scopeNote != null)
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: spacingSm),
              child: Text(
                scopeNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.eventFieldTitleLabel,
              errorText: _titleErrorText(l10n, state),
            ),
            onChanged: _controller.setTitle,
          ),
          SizedBox(height: spacingMd),
          SwitchListTile(
            contentPadding: EdgeInsetsDirectional.zero,
            title: Text(l10n.eventAllDayLabel),
            value: state.allDay,
            onChanged: _controller.setAllDay,
          ),
          HebrewDatePickerField(
            date: state.hebrewDate,
            onChanged: _controller.setHebrewDate,
          ),
          EventTimeSection(
            allDay: state.allDay,
            startTime: state.startTime,
            endTime: state.endTime,
            onStartTimeChanged: _controller.setStartTime,
            onEndTimeChanged: _controller.setEndTime,
          ),
          if (state.hasError(EventValidationErrorType.endTimeNotAfterStartTime))
            Padding(
              padding: EdgeInsetsDirectional.only(top: spacingXs),
              child: Text(
                l10n.eventValidationEndBeforeStart,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SizedBox(height: spacingMd),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.eventFieldDescriptionLabel,
              errorText:
                  state.hasError(EventValidationErrorType.descriptionTooLong)
                  ? l10n.eventValidationDescriptionTooLong
                  : null,
            ),
            onChanged: _controller.setDescription,
          ),
          SizedBox(height: spacingMd),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: l10n.eventFieldLocationLabel,
              errorText:
                  state.hasError(EventValidationErrorType.locationTooLong)
                  ? l10n.eventValidationLocationTooLong
                  : null,
            ),
            onChanged: _controller.setLocation,
          ),
          SizedBox(height: spacingMd),
          Text(
            l10n.eventRemindersLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: spacingXs),
          ReminderSelector(
            selectedMinutesBefore: state.reminderMinutesBefore.isEmpty
                ? null
                : state.reminderMinutesBefore.first,
            onChanged: _controller.setReminderMinutesBefore,
          ),
          // M9: a single occurrence split off a series is a standalone
          // event — it has no recurrence of its own to edit.
          if (!editsSingleOccurrence) ...<Widget>[
            SizedBox(height: spacingMd),
            Text(
              l10n.eventRecurrenceLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: spacingXs),
            RecurrenceTypeSelector(
              selected: state.recurrenceType,
              onChanged: _controller.setRecurrenceType,
            ),
            if (state.recurrenceType != RecurrenceType.none)
              RecurrenceUntilField(
                until: state.recurrenceUntil,
                fallbackDate: state.hebrewDate,
                onChanged: _controller.setRecurrenceUntil,
              ),
          ],
        ],
      ),
    );
  }

  String? _titleErrorText(AppLocalizations l10n, EventEditorState state) {
    if (state.hasError(EventValidationErrorType.titleRequired)) {
      return l10n.eventValidationTitleRequired;
    }
    if (state.hasError(EventValidationErrorType.titleTooLong)) {
      return l10n.eventValidationTitleTooLong;
    }
    return null;
  }
}
