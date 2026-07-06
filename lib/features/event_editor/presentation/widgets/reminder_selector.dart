import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../l10n/app_localizations.dart';

/// The reminder offsets M2a exposes (task brief §4: "none/10/30/60 minutes
/// before, as a start"). `null` represents "no reminder".
const List<int?> _reminderOptions = <int?>[null, 10, 30, 60];

/// A single-select row of chips for the event's reminder offset.
class ReminderSelector extends StatelessWidget {
  const ReminderSelector({
    required this.selectedMinutesBefore,
    required this.onChanged,
    super.key,
  });

  final int? selectedMinutesBefore;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: spacingSm,
      runSpacing: spacingXs,
      children: <Widget>[
        for (final int? option in _reminderOptions)
          ChoiceChip(
            label: Text(
              option == null
                  ? l10n.eventReminderNone
                  : l10n.eventReminderMinutesBefore(option),
            ),
            selected: selectedMinutesBefore == option,
            onSelected: (_) => onChanged(option),
          ),
      ],
    );
  }
}
