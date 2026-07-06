import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/event/event.dart';
import '../../../../domain/event/event_occurrence.dart';
import '../../../../domain/event/event_repository.dart';
import '../../../../domain/event/recurrence_rule.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../event_editor/application/event_editor_controller.dart';
import '../../../event_editor/application/event_repository_provider.dart';
import '../../../event_editor/presentation/event_editor_screen.dart';
import '../../application/hebrew_date_engine_provider.dart';

/// Bottom sheet listing the event occurrences on a single Hebrew day (title,
/// time), with edit and delete actions — the Google-Calendar-like "day
/// agenda" popup opened by tapping a day cell that has events.
class DayEventsSheet extends ConsumerWidget {
  const DayEventsSheet({
    required this.date,
    required this.occurrences,
    super.key,
  });

  final HebrewDate date;
  final List<EventOccurrence> occurrences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final String dateLabel =
        '${hebrewDayNumeral(date.day)} ${engine.monthName(date.month)} '
        '${hebrewYearNumeral(date.year)}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacingMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(dateLabel, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: spacingSm),
            for (final EventOccurrence occurrence in occurrences)
              _DayEventTile(occurrence: occurrence),
          ],
        ),
      ),
    );
  }
}

/// The user's choice when deleting a recurring event's occurrence.
enum _RecurringDeleteChoice { thisOccurrenceOnly, wholeSeries }

class _DayEventTile extends ConsumerWidget {
  const _DayEventTile({required this.occurrence});

  final EventOccurrence occurrence;

  Event get _event => occurrence.event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String timeLabel = _event.allDay
        ? l10n.eventAllDayLabel
        : (_event.startTime?.toString() ?? '');

    return ListTile(
      contentPadding: EdgeInsetsDirectional.zero,
      title: Text(_event.title),
      subtitle: Text(timeLabel),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l10n.eventEditAction,
            onPressed: () => _edit(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: l10n.eventDeleteAction,
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context) {
    // Editing always opens the series' anchor date (`Event.hebrewDate`), not
    // whichever occurrence date was tapped: per the task brief, editing a
    // recurring event edits the whole series, and the anchor date is the
    // series' defining field.
    final EventEditorArgs args = (
      initialDate: _event.hebrewDate,
      existing: _event,
    );
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EventEditorScreen(args: args)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!occurrence.isRecurring) {
      await _confirmDeleteWholeEvent(context, ref);
      return;
    }
    await _confirmDeleteRecurringOccurrence(context, ref);
  }

  /// Non-recurring event: a single confirm/cancel dialog, as before M3a.
  Future<void> _confirmDeleteWholeEvent(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.eventDeleteConfirmTitle),
        content: Text(l10n.eventDeleteConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.eventDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(eventRepositoryProvider).delete(_event.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  /// Recurring event: a single dialog offering "this occurrence only" (adds
  /// [EventOccurrence.occurrenceDate] to [RecurrenceRule.exceptions] and
  /// updates the event) or "the whole series" (deletes the event outright),
  /// alongside cancel — each action button doubles as that path's
  /// confirmation, per the task brief.
  Future<void> _confirmDeleteRecurringOccurrence(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final _RecurringDeleteChoice? choice =
        await showDialog<_RecurringDeleteChoice>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(l10n.eventDeleteConfirmTitle),
            content: Text(l10n.eventDeleteRecurringChoiceMessage),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_RecurringDeleteChoice.thisOccurrenceOnly),
                child: Text(l10n.eventDeleteThisOccurrenceOnly),
              ),
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_RecurringDeleteChoice.wholeSeries),
                child: Text(l10n.eventDeleteWholeSeries),
              ),
            ],
          ),
        );
    if (choice == null) {
      return;
    }
    final EventRepository repository = ref.read(eventRepositoryProvider);
    switch (choice) {
      case _RecurringDeleteChoice.thisOccurrenceOnly:
        final RecurrenceRule updatedRecurrence = _event.recurrence.copyWith(
          exceptions: <HebrewDate>[
            ..._event.recurrence.exceptions,
            occurrence.occurrenceDate,
          ],
        );
        await repository.update(_event.copyWith(recurrence: updatedRecurrence));
      case _RecurringDeleteChoice.wholeSeries:
        await repository.delete(_event.id);
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
