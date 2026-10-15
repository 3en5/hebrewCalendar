import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/event/event.dart';
import '../../../domain/event/event_repository.dart';
import '../../../domain/event/recurrence_rule.dart';
import '../../../domain/event/recurring_edit.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/application/hebrew_date_engine_provider.dart';
import '../application/event_repository_provider.dart';
import 'recurring_scope_dialog.dart';

/// Asks before deleting [event], then deletes it; shared by the month
/// view's event sheet and the editor (owner request 2026-10-15: delete from
/// every view). A single event gets a confirm dialog; a recurring one asks
/// "this occurrence" (the one on [occurrenceDate]), "this and following" or
/// "the whole series" (M9), each choice doubling as the confirmation.
/// Returns whether anything was deleted.
Future<bool> confirmAndDeleteEvent(
  BuildContext context,
  WidgetRef ref, {
  required Event event,
  required HebrewDate occurrenceDate,
}) async {
  final EventRepository repository = ref.read(eventRepositoryProvider);
  if (event.recurrence.type == RecurrenceType.none) {
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
    if (!(confirmed ?? false)) {
      return false;
    }
    await repository.delete(event.id);
    return true;
  }
  final RecurringEditScope? scope = await askRecurringScope(
    context,
    forDelete: true,
  );
  if (scope == null) {
    return false;
  }
  final RecurringChangePlan plan = planRecurringDelete(
    series: event,
    occurrenceDate: occurrenceDate,
    scope: scope,
    engine: ref.read(hebrewDateEngineProvider),
  );
  if (plan.deleteSeries) {
    await repository.delete(event.id);
  } else if (plan.updatedSeries != null) {
    await repository.update(plan.updatedSeries!);
  }
  return true;
}
