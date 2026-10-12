import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../l10n/app_localizations.dart';

/// M16 (owner decision 2026-10-12): sets the event's Hebrew date from a
/// Gregorian date. The Hebrew day starts at sunset, so after picking the
/// day the user says whether it was before or after sunset; after sunset
/// is the next Hebrew day (e.g. someone born at night). Returns null when
/// the user cancels.
Future<HebrewDate?> pickHebrewDateFromGregorian({
  required BuildContext context,
  required HebrewDateEngine engine,
  required HebrewDate initial,
}) async {
  final DateTime? day = await showDatePicker(
    context: context,
    initialDate: engine.toGregorian(initial),
    firstDate: DateTime(1900),
    lastDate: DateTime(2200),
  );
  if (day == null || !context.mounted) {
    return null;
  }
  final HebrewDate before = engine.fromGregorian(day);
  final HebrewDate after = engine.addDays(before, 1);
  final AppLocalizations l10n = AppLocalizations.of(context);
  String label(HebrewDate d) =>
      '${hebrewDayNumeral(d.day)} ${engine.monthName(d.month)} '
      '${hebrewYearNumeral(d.year)}';

  return showDialog<HebrewDate>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(DateFormat.yMMMMd('he').format(day)),
      content: Text(l10n.eventSunsetQuestion),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(before),
          child: Text(l10n.eventBeforeSunset(label(before))),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(after),
          child: Text(l10n.eventAfterSunset(label(after))),
        ),
      ],
    ),
  );
}
