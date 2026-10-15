import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/linkified_text.dart';
import '../../../../domain/event/event.dart';
import '../../../../domain/event/event_attendee.dart';
import '../../../../domain/event/event_occurrence.dart';
import '../../../../domain/event/event_repository.dart';
import '../../../../domain/event/recurring_edit.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../event_editor/application/event_editor_controller.dart';
import '../../../event_editor/application/event_repository_provider.dart';
import '../../../event_editor/presentation/event_editor_screen.dart';
import '../../../event_editor/presentation/recurring_scope_dialog.dart';
import '../../application/hebrew_date_engine_provider.dart';
import 'location_actions.dart';

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

    final Widget tile = ListTile(
      contentPadding: EdgeInsetsDirectional.zero,
      title: LinkifiedText(_event.title),
      subtitle: Text(
        _event.attendees.isEmpty
            ? timeLabel
            : '$timeLabel · ${l10n.eventAttendeesSummary(_event.attendees.length, _event.attendees.where((EventAttendee a) => a.response == AttendeeResponse.accepted).length)}',
      ),
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
    final String location = _event.location.trim();
    final String description = _event.description.trim();
    if (location.isEmpty && description.isEmpty) {
      return tile;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        tile,
        // Owner request 2026-10-15: the description, with its numbers,
        // emails and links tappable.
        if (description.isNotEmpty)
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: spacingSm),
            child: LinkifiedText(
              description,
              style: TextStyle(
                fontSize: bodySmallRem,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (location.isNotEmpty) LocationActions(location: location),
      ],
    );
  }

  /// M9: a recurring event first asks which occurrences to change (this
  /// one, this and the following, or all), then opens the editor on this
  /// occurrence's Hebrew date (or the series anchor, for "all").
  Future<void> _edit(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    RecurringEditScope scope = RecurringEditScope.allEvents;
    if (occurrence.isRecurring) {
      final RecurringEditScope? chosen = await askRecurringScope(
        context,
        forDelete: false,
      );
      if (chosen == null) {
        return;
      }
      scope = chosen;
    }
    final EventEditorArgs args = EventEditorArgs(
      initialDate: _event.hebrewDate,
      existing: _event,
      scope: scope,
      occurrenceDate: occurrence.occurrenceDate,
    );
    navigator.pop();
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => EventEditorScreen(args: args)),
      ),
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

  /// Recurring event (M9): "this occurrence only" (adds it to the
  /// exceptions), "this and following" (the series ends the day before) or
  /// "the whole series" (deleted) — each option doubles as the confirmation.
  Future<void> _confirmDeleteRecurringOccurrence(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final RecurringEditScope? scope = await askRecurringScope(
      context,
      forDelete: true,
    );
    if (scope == null) {
      return;
    }
    final RecurringChangePlan plan = planRecurringDelete(
      series: _event,
      occurrenceDate: occurrence.occurrenceDate,
      scope: scope,
      engine: ref.read(hebrewDateEngineProvider),
    );
    final EventRepository repository = ref.read(eventRepositoryProvider);
    if (plan.deleteSeries) {
      await repository.delete(_event.id);
    } else if (plan.updatedSeries != null) {
      await repository.update(plan.updatedSeries!);
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
