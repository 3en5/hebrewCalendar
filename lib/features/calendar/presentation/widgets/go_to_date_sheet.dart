import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../event_editor/presentation/widgets/hebrew_date_picker_sheet.dart';
import '../../application/calendar_view_provider.dart';
import '../../application/hebrew_date_engine_provider.dart';

/// "Go to date" (M12): today, a Hebrew date, or a Gregorian date. The picked
/// day becomes the shell's focused date, so every view jumps to it (and the
/// month view selects it).
Future<void> showGoToDateSheet(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final _GoToChoice? choice = await showModalBottomSheet<_GoToChoice>(
    context: context,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.today),
            title: Text(l10n.calendarTodayTooltip),
            onTap: () => Navigator.of(sheetContext).pop(_GoToChoice.today),
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: Text(l10n.goToHebrewDate),
            onTap: () => Navigator.of(sheetContext).pop(_GoToChoice.hebrew),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text(l10n.goToGregorianDate),
            onTap: () => Navigator.of(sheetContext).pop(_GoToChoice.gregorian),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) {
    return;
  }
  final CalendarViewNotifier notifier = ref.read(calendarViewProvider.notifier);
  final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
  final HebrewDate focused = ref.read(calendarViewProvider).focusedDate;
  switch (choice) {
    case _GoToChoice.today:
      notifier.goToToday();
    case _GoToChoice.hebrew:
      final HebrewDate? picked = await showModalBottomSheet<HebrewDate>(
        context: context,
        builder: (_) => HebrewDatePickerSheet(initialDate: focused),
      );
      if (picked != null) {
        notifier.setFocusedDate(picked);
      }
    case _GoToChoice.gregorian:
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: engine.toGregorian(focused),
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
      );
      if (picked != null) {
        notifier.setFocusedDate(engine.fromGregorian(picked));
      }
  }
}

enum _GoToChoice { today, hebrew, gregorian }

/// Convenience for an `onPressed` callback.
void openGoToDateSheet(BuildContext context, WidgetRef ref) =>
    unawaited(showGoToDateSheet(context, ref));
