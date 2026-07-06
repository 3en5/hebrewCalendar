import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../l10n/app_localizations.dart';

/// The reminder offsets exposed by the editor (M4 task brief §5: "none/at
/// time of event/10/30/60 minutes/1 day before"). `null` represents "no
/// reminder"; `0` represents "at the event's own start time"; `1440`
/// (minutes in a day) represents "1 day before". Multiple reminders per
/// event remain out of scope — see docs/WISHLIST.md.
const List<int?> _reminderOptions = <int?>[null, 0, 10, 30, 60, 1440];

/// Minutes-before value meaning "1 day before" — kept as a named constant
/// since `1440` alone reads as an arbitrary magic number at call sites.
const int oneDayBeforeMinutes = 1440;

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
            label: Text(_label(l10n, option)),
            selected: selectedMinutesBefore == option,
            onSelected: (_) => onChanged(option),
          ),
      ],
    );
  }

  String _label(AppLocalizations l10n, int? option) {
    if (option == null) {
      return l10n.eventReminderNone;
    }
    if (option == 0) {
      return l10n.eventReminderAtEventTime;
    }
    if (option == oneDayBeforeMinutes) {
      return l10n.eventReminderOneDayBefore;
    }
    return l10n.eventReminderMinutesBefore(option);
  }
}
