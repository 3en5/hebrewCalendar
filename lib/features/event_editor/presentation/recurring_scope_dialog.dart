import 'package:flutter/material.dart';

import '../../../domain/event/event.dart';
import '../../../domain/event/event_occurrence.dart';
import '../../../l10n/app_localizations.dart';
import '../application/event_editor_controller.dart';
import 'event_editor_screen.dart';

/// Asks which occurrences of a recurring series an edit ([forDelete] false)
/// or delete applies to (M9). Returns null when the user cancels.
Future<RecurringEditScope?> askRecurringScope(
  BuildContext context, {
  required bool forDelete,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return showDialog<RecurringEditScope>(
    context: context,
    builder: (BuildContext dialogContext) {
      Widget option(RecurringEditScope scope, String label) =>
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(scope),
            child: Text(label),
          );
      return SimpleDialog(
        title: Text(
          forDelete
              ? l10n.eventDeleteRecurringChoiceMessage
              : l10n.eventEditRecurringChoiceMessage,
        ),
        children: <Widget>[
          option(
            RecurringEditScope.thisOccurrence,
            l10n.eventDeleteThisOccurrenceOnly,
          ),
          option(
            RecurringEditScope.thisAndFollowing,
            l10n.eventScopeThisAndFollowing,
          ),
          option(RecurringEditScope.allEvents, l10n.eventDeleteWholeSeries),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
        ],
      );
    },
  );
}

/// Opens the editor for [occurrence]. For a recurring event it first asks
/// whether to change only this occurrence, this and the following ones, or
/// the whole series (M9); a plain event opens directly.
Future<void> openEventEditorForOccurrence(
  BuildContext context,
  EventOccurrence occurrence,
) async {
  final Event event = occurrence.event;
  RecurringEditScope scope = RecurringEditScope.allEvents;
  if (occurrence.isRecurring) {
    final RecurringEditScope? chosen = await askRecurringScope(
      context,
      forDelete: false,
    );
    if (chosen == null || !context.mounted) {
      return;
    }
    scope = chosen;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EventEditorScreen(
        args: EventEditorArgs(
          initialDate: event.hebrewDate,
          existing: event,
          scope: scope,
          occurrenceDate: occurrence.occurrenceDate,
        ),
      ),
    ),
  );
}
