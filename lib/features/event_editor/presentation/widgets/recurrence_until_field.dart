import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../calendar/application/hebrew_date_engine_provider.dart';
import 'hebrew_date_picker_sheet.dart';

/// A tappable field for a recurring event's optional [RecurrenceRule.until]
/// date: shows "no end date" when null, opens the (reused) Hebrew date
/// picker sheet on tap, and offers a clear button to go back to "repeats
/// indefinitely" once a date is set.
class RecurrenceUntilField extends ConsumerWidget {
  const RecurrenceUntilField({
    required this.until,
    required this.fallbackDate,
    required this.onChanged,
    super.key,
  });

  /// The current "repeat until" date, or null for "repeats indefinitely".
  final HebrewDate? until;

  /// The date to open the picker sheet on when [until] is null (the event's
  /// own Hebrew date is the natural starting point).
  final HebrewDate fallbackDate;

  final ValueChanged<HebrewDate?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final HebrewDate? current = until;
    final String subtitle = current == null
        ? l10n.recurrenceUntilNone
        : '${hebrewDayNumeral(current.day)} ${engine.monthName(current.month)} '
              '${hebrewYearNumeral(current.year)}';

    return ListTile(
      contentPadding: EdgeInsetsDirectional.zero,
      leading: const Icon(Icons.event_busy),
      title: Text(l10n.recurrenceUntilLabel),
      subtitle: Text(subtitle),
      trailing: current == null
          ? null
          : IconButton(
              icon: const Icon(Icons.clear),
              tooltip: l10n.recurrenceUntilClearTooltip,
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final HebrewDate? picked = await showModalBottomSheet<HebrewDate>(
          context: context,
          builder: (_) =>
              HebrewDatePickerSheet(initialDate: current ?? fallbackDate),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
    );
  }
}
