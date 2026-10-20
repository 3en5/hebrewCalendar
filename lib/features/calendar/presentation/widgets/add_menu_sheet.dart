import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// M24: the "+" button's choice between a regular event and the
/// significant-date tool (a birthday, yahrzeit or anniversary from a
/// Gregorian date). Calls the chosen callback after the sheet closes.
Future<void> showAddMenuSheet(
  BuildContext context, {
  required VoidCallback onNewEvent,
  required VoidCallback onSignificantDate,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final VoidCallback? chosen = await showModalBottomSheet<VoidCallback>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            key: const ValueKey<String>('add-menu-new-event'),
            leading: const Icon(Icons.event),
            title: Text(l10n.addMenuNewEvent),
            subtitle: Text(l10n.addMenuNewEventHint),
            onTap: () => Navigator.of(sheetContext).pop(onNewEvent),
          ),
          ListTile(
            key: const ValueKey<String>('add-menu-significant-date'),
            leading: const Icon(Icons.swap_horiz),
            title: Text(l10n.addMenuSignificantDate),
            subtitle: Text(l10n.addMenuSignificantDateHint),
            onTap: () => Navigator.of(sheetContext).pop(onSignificantDate),
          ),
        ],
      ),
    ),
  );
  chosen?.call();
}
