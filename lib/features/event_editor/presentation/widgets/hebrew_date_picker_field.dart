import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../calendar/application/hebrew_date_engine_provider.dart';
import 'gregorian_date_entry.dart';
import 'hebrew_date_picker_sheet.dart';

/// A tappable field showing the event's Hebrew date (and, small, the
/// Gregorian date it falls on); tapping opens [HebrewDatePickerSheet] as a
/// bottom sheet. M16: the trailing button sets it from a Gregorian date
/// instead, asking whether it was before or after sunset.
class HebrewDatePickerField extends ConsumerWidget {
  const HebrewDatePickerField({
    required this.date,
    required this.onChanged,
    super.key,
  });

  final HebrewDate date;
  final ValueChanged<HebrewDate> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String label =
        '${hebrewDayNumeral(date.day)} ${engine.monthName(date.month)} '
        '${hebrewYearNumeral(date.year)}';

    return ListTile(
      contentPadding: EdgeInsetsDirectional.zero,
      leading: const Icon(Icons.event),
      title: Text(l10n.eventHebrewDateLabel),
      subtitle: Text(
        '$label · ${DateFormat.yMMMMd('he').format(engine.toGregorian(date))}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit_calendar),
        tooltip: l10n.eventPickByGregorianDate,
        onPressed: () async {
          final HebrewDate? picked = await pickHebrewDateFromGregorian(
            context: context,
            engine: engine,
            initial: date,
          );
          if (picked != null) {
            onChanged(picked);
          }
        },
      ),
      onTap: () async {
        final HebrewDate? picked = await showModalBottomSheet<HebrewDate>(
          context: context,
          builder: (_) => HebrewDatePickerSheet(initialDate: date),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
    );
  }
}
