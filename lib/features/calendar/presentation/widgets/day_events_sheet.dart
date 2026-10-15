import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/linkified_text.dart';
import '../../../../domain/event/event.dart';
import '../../../../domain/event/event_attendee.dart';
import '../../../../domain/event/event_occurrence.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../event_editor/application/event_editor_controller.dart';
import '../../../event_editor/presentation/delete_event_flow.dart';
import '../../../event_editor/presentation/event_editor_screen.dart';
import '../../../event_editor/presentation/recurring_scope_dialog.dart';
import '../../application/hebrew_date_engine_provider.dart';
import 'event_attendees_list.dart';
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
    final TextStyle? titleStyle = Theme.of(context).textTheme.titleMedium;

    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacingMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Owner request 2026-10-15: the Gregorian date too, small, on
            // the same line at the far end, for orientation.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Expanded(child: Text(dateLabel, style: titleStyle)),
                SizedBox(width: spacingSm),
                Text(
                  DateFormat.yMMMMd('he').format(engine.toGregorian(date)),
                  key: const ValueKey<String>('day-sheet-gregorian'),
                  style: titleStyle?.copyWith(
                    fontSize: (titleStyle.fontSize ?? titleRem) * 0.6,
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
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
    if (location.isEmpty && description.isEmpty && _event.attendees.isEmpty) {
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
        if (_event.attendees.isNotEmpty)
          EventAttendeesList(attendees: _event.attendees),
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
    final bool deleted = await confirmAndDeleteEvent(
      context,
      ref,
      event: _event,
      occurrenceDate: occurrence.occurrenceDate,
    );
    if (deleted && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
