import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/event/event.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../event_editor/application/event_editor_controller.dart';
import '../../../event_editor/application/event_repository_provider.dart';
import '../../../event_editor/presentation/event_editor_screen.dart';
import '../../application/hebrew_date_engine_provider.dart';

/// Bottom sheet listing the events on a single Hebrew day (title, time),
/// with edit and delete actions — the Google-Calendar-like "day agenda"
/// popup opened by tapping a day cell that has events.
class DayEventsSheet extends ConsumerWidget {
  const DayEventsSheet({required this.date, required this.events, super.key});

  final HebrewDate date;
  final List<Event> events;

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
            for (final Event event in events) _DayEventTile(event: event),
          ],
        ),
      ),
    );
  }
}

class _DayEventTile extends ConsumerWidget {
  const _DayEventTile({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String timeLabel = event.allDay
        ? l10n.eventAllDayLabel
        : (event.startTime?.toString() ?? '');

    return ListTile(
      contentPadding: EdgeInsetsDirectional.zero,
      title: Text(event.title),
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
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context) {
    final EventEditorArgs args = (
      initialDate: event.hebrewDate,
      existing: event,
    );
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EventEditorScreen(args: args)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
      await ref.read(eventRepositoryProvider).delete(event.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
