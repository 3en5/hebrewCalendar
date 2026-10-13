import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/theme/event_colors.dart';
import '../../../../domain/event/recurrence_rule.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/event_editor_controller.dart';
import '../../application/event_editor_state.dart';
import 'event_color_picker.dart';
import 'recurrence_until_field.dart';
import 'yearly_options_section.dart';

/// The compact editor's choice sheets (owner-approved sketches 5-7,
/// 2026-10-13): each editor row shows its current value, and tapping it
/// opens one of these bottom sheets. The sheets edit the same
/// [eventEditorControllerProvider] state live, so closing one needs no
/// "apply" step.

/// Reminder offsets offered in the sheet, in minutes before the event.
const List<int> kReminderPresets = <int>[0, 10, 30, 60, 1440, 10080];

/// At most this many reminders per event.
const int kMaxReminders = 5;

String reminderLabel(AppLocalizations l10n, int minutes) {
  if (minutes == 0) {
    return l10n.eventReminderAtEventTime;
  }
  if (minutes % 10080 == 0) {
    return l10n.eventReminderWeeksBefore(minutes ~/ 10080);
  }
  if (minutes % 1440 == 0) {
    return l10n.eventReminderDaysBefore(minutes ~/ 1440);
  }
  if (minutes % 60 == 0) {
    return l10n.eventReminderHoursBefore(minutes ~/ 60);
  }
  return l10n.eventReminderMinutesBefore(minutes);
}

/// The reminder row's summary, e.g. "30 דקות לפני, יום לפני".
String remindersSummary(AppLocalizations l10n, List<int> minutes) =>
    minutes.isEmpty
    ? l10n.eventReminderNone
    : minutes.map((int m) => reminderLabel(l10n, m)).join(', ');

String recurrenceTypeLabel(AppLocalizations l10n, RecurrenceType type) =>
    switch (type) {
      RecurrenceType.none => l10n.recurrenceTypeNone,
      RecurrenceType.hebrewYearly => l10n.recurrenceTypeYearly,
      RecurrenceType.hebrewMonthly => l10n.recurrenceTypeMonthly,
      RecurrenceType.weekly => l10n.recurrenceTypeWeekly,
      RecurrenceType.daily => l10n.recurrenceTypeDaily,
    };

String colorLabel(AppLocalizations l10n, String? colorId) =>
    colorId == null ? l10n.eventColorDefault : l10n.eventColorOption(colorId);

Future<void> _openSheet(BuildContext context, Widget sheet) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            spacingMd,
            0,
            spacingMd,
            spacingMd,
          ),
          child: sheet,
        ),
      ),
    );

void showRecurrenceSheet(BuildContext context, EventEditorArgs args) =>
    unawaited(_openSheet(context, _RecurrenceSheet(args: args)));

void showRemindersSheet(BuildContext context, EventEditorArgs args) =>
    unawaited(_openSheet(context, _RemindersSheet(args: args)));

void showColorSheet(BuildContext context, EventEditorArgs args) =>
    unawaited(_openSheet(context, _ColorSheet(args: args)));

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(bottom: spacingSm),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _DoneButton extends StatelessWidget {
  const _DoneButton();

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(AppLocalizations.of(context).editorSheetDone),
    ),
  );
}

class _RecurrenceSheet extends ConsumerWidget {
  const _RecurrenceSheet({required this.args});

  final EventEditorArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final EventEditorState state = ref.watch(
      eventEditorControllerProvider(args),
    );
    final EventEditorController controller = ref.read(
      eventEditorControllerProvider(args).notifier,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SheetTitle(l10n.eventRecurrenceLabel),
        for (final RecurrenceType type in RecurrenceType.values)
          ListTile(
            contentPadding: EdgeInsetsDirectional.zero,
            title: Text(recurrenceTypeLabel(l10n, type)),
            trailing: state.recurrenceType == type
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            selected: state.recurrenceType == type,
            onTap: () => controller.setRecurrenceType(type),
          ),
        if (state.recurrenceType == RecurrenceType.hebrewYearly &&
            YearlyOptionsSection.appliesTo(state.hebrewDate))
          YearlyOptionsSection(
            anchor: state.hebrewDate,
            rule: RecurrenceRule(
              type: state.recurrenceType,
              leapAdar: state.recurrenceLeapAdar,
              shortMonth: state.recurrenceShortMonth,
            ),
            onLeapAdarChanged: controller.setLeapAdar,
            onShortMonthChanged: controller.setShortMonth,
          ),
        if (state.recurrenceType != RecurrenceType.none)
          RecurrenceUntilField(
            until: state.recurrenceUntil,
            fallbackDate: state.hebrewDate,
            onChanged: controller.setRecurrenceUntil,
          ),
        const _DoneButton(),
      ],
    );
  }
}

class _RemindersSheet extends ConsumerWidget {
  const _RemindersSheet({required this.args});

  final EventEditorArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<int> selected = ref
        .watch(eventEditorControllerProvider(args))
        .reminderMinutesBefore;
    final EventEditorController controller = ref.read(
      eventEditorControllerProvider(args).notifier,
    );
    final List<int> options = <int>{...kReminderPresets, ...selected}.toList()
      ..sort();
    final bool full = selected.length >= kMaxReminders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SheetTitle(l10n.eventRemindersSheetTitle),
        for (final int minutes in options)
          CheckboxListTile(
            contentPadding: EdgeInsetsDirectional.zero,
            title: Text(reminderLabel(l10n, minutes)),
            value: selected.contains(minutes),
            onChanged: full && !selected.contains(minutes)
                ? null
                : (_) => controller.toggleReminder(minutes),
          ),
        ListTile(
          contentPadding: EdgeInsetsDirectional.zero,
          leading: const Icon(Icons.add),
          title: Text(l10n.eventReminderCustom),
          enabled: !full,
          onTap: () async {
            final int? minutes = await _askCustomReminder(context, l10n);
            if (minutes != null) {
              controller.addReminder(minutes);
            }
          },
        ),
        const _DoneButton(),
      ],
    );
  }
}

enum _ReminderUnit { minutes, hours, days, weeks }

/// A small dialog for a custom reminder: a number and a unit.
Future<int?> _askCustomReminder(BuildContext context, AppLocalizations l10n) =>
    showDialog<int>(
      context: context,
      builder: (_) => _CustomReminderDialog(l10n: l10n),
    );

/// Owns its text controller, disposed with the dialog itself (after its
/// closing animation — disposing it when `showDialog` returns is too early).
class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  final TextEditingController _amount = TextEditingController(text: '2');
  _ReminderUnit _unit = _ReminderUnit.hours;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final int? n = int.tryParse(_amount.text.trim());
    if (n == null || n <= 0) {
      return;
    }
    final int factor = switch (_unit) {
      _ReminderUnit.minutes => 1,
      _ReminderUnit.hours => 60,
      _ReminderUnit.days => 1440,
      _ReminderUnit.weeks => 10080,
    };
    Navigator.of(context).pop(n * factor);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.eventReminderCustom),
      content: Row(
        children: <Widget>[
          SizedBox(
            width: rem(4),
            child: TextField(
              key: const ValueKey<String>('custom-reminder-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ),
          SizedBox(width: spacingSm),
          Expanded(
            child: DropdownButton<_ReminderUnit>(
              value: _unit,
              isExpanded: true,
              onChanged: (_ReminderUnit? value) =>
                  setState(() => _unit = value ?? _unit),
              items: <DropdownMenuItem<_ReminderUnit>>[
                for (final _ReminderUnit u in _ReminderUnit.values)
                  DropdownMenuItem<_ReminderUnit>(
                    value: u,
                    child: Text(switch (u) {
                      _ReminderUnit.minutes => l10n.eventReminderUnitMinutes,
                      _ReminderUnit.hours => l10n.eventReminderUnitHours,
                      _ReminderUnit.days => l10n.eventReminderUnitDays,
                      _ReminderUnit.weeks => l10n.eventReminderUnitWeeks,
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

class _ColorSheet extends ConsumerWidget {
  const _ColorSheet({required this.args});

  final EventEditorArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? colorId = ref
        .watch(eventEditorControllerProvider(args))
        .colorId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SheetTitle(l10n.eventColorLabel),
        EventColorPicker(
          selectedColorId: colorId,
          onChanged: (String? id) {
            ref
                .read(eventEditorControllerProvider(args).notifier)
                .setColorId(id);
            Navigator.of(context).pop();
          },
        ),
        SizedBox(height: spacingMd),
      ],
    );
  }
}

/// The small colored dot leading the color row.
class EventColorDot extends StatelessWidget {
  const EventColorDot({required this.colorId, super.key});

  final String? colorId;

  @override
  Widget build(BuildContext context) => Container(
    width: rem(1.25),
    height: rem(1.25),
    decoration: BoxDecoration(
      color: eventColor(colorId, Theme.of(context).colorScheme),
      shape: BoxShape.circle,
    ),
  );
}
