import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/event/recurrence_rule.dart';
import '../../../../l10n/app_localizations.dart';

/// A single-select row of chips for the event's [RecurrenceType] (M3a):
/// none / every Hebrew year / every Hebrew month / every week / every day.
class RecurrenceTypeSelector extends StatelessWidget {
  const RecurrenceTypeSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final RecurrenceType selected;
  final ValueChanged<RecurrenceType> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: spacingSm,
      runSpacing: spacingXs,
      children: <Widget>[
        for (final RecurrenceType type in RecurrenceType.values)
          ChoiceChip(
            label: Text(_label(l10n, type)),
            selected: selected == type,
            onSelected: (_) => onChanged(type),
          ),
      ],
    );
  }

  String _label(AppLocalizations l10n, RecurrenceType type) => switch (type) {
    RecurrenceType.none => l10n.recurrenceTypeNone,
    RecurrenceType.hebrewYearly => l10n.recurrenceTypeYearly,
    RecurrenceType.hebrewMonthly => l10n.recurrenceTypeMonthly,
    RecurrenceType.weekly => l10n.recurrenceTypeWeekly,
    RecurrenceType.daily => l10n.recurrenceTypeDaily,
  };
}
