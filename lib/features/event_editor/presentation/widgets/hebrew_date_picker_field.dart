import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../calendar/application/hebrew_date_engine_provider.dart';
import 'hebrew_date_picker_sheet.dart';

/// A tappable field showing the event's Hebrew date; tapping opens
/// [HebrewDatePickerSheet] as a bottom sheet.
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
      subtitle: Text(label),
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
