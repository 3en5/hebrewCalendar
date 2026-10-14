import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../l10n/app_localizations.dart';

/// M24 (owner report 2026-10-14): a Gregorian date as three dropdowns
/// (day, month, year) right on the screen. The date picker's typed field
/// was unusable on a phone whose number keyboard has no dot, and a
/// birth year decades back is slow to reach in its calendar.
///
/// Calls [onChanged] with the full date once all three are chosen (a day
/// the month lacks moves to its last day), or null while one is missing.
class GregorianDateDropdowns extends StatefulWidget {
  const GregorianDateDropdowns({
    required this.onChanged,
    this.firstYear = 1900,
    super.key,
  });

  final ValueChanged<DateTime?> onChanged;
  final int firstYear;

  @override
  State<GregorianDateDropdowns> createState() => _GregorianDateDropdownsState();
}

class _GregorianDateDropdownsState extends State<GregorianDateDropdowns> {
  int? _day;
  int? _month;
  int? _year;

  void _update({int? day, int? month, int? year}) {
    setState(() {
      _day = day ?? _day;
      _month = month ?? _month;
      _year = year ?? _year;
      final int? d = _day;
      final int? m = _month;
      final int? y = _year;
      if (d != null && m != null && y != null) {
        final int last = DateTime(y, m + 1, 0).day;
        if (d > last) {
          _day = last;
        }
      }
    });
    final int? d = _day;
    final int? m = _month;
    final int? y = _year;
    widget.onChanged(
      d != null && m != null && y != null ? DateTime(y, m, d) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateFormat monthName = DateFormat.MMMM('he');
    final int thisYear = DateTime.now().year;
    InputDecoration decoration(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacingSm,
        vertical: spacingSm,
      ),
    );
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            key: const ValueKey<String>('significant-day'),
            value: _day,
            isExpanded: true,
            decoration: decoration(l10n.significantDayLabel),
            menuMaxHeight: rem(20),
            items: <DropdownMenuItem<int>>[
              for (int d = 1; d <= 31; d++)
                DropdownMenuItem<int>(value: d, child: Text('$d')),
            ],
            onChanged: (int? v) => _update(day: v),
          ),
        ),
        SizedBox(width: spacingSm),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            key: const ValueKey<String>('significant-month'),
            value: _month,
            isExpanded: true,
            decoration: decoration(l10n.significantMonthLabel),
            menuMaxHeight: rem(20),
            items: <DropdownMenuItem<int>>[
              for (int m = 1; m <= 12; m++)
                DropdownMenuItem<int>(
                  value: m,
                  child: Text(monthName.format(DateTime(2000, m))),
                ),
            ],
            onChanged: (int? v) => _update(month: v),
          ),
        ),
        SizedBox(width: spacingSm),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            key: const ValueKey<String>('significant-year'),
            value: _year,
            isExpanded: true,
            decoration: decoration(l10n.significantYearLabel),
            menuMaxHeight: rem(20),
            items: <DropdownMenuItem<int>>[
              for (int y = thisYear; y >= widget.firstYear; y--)
                DropdownMenuItem<int>(value: y, child: Text('$y')),
            ],
            onChanged: (int? v) => _update(year: v),
          ),
        ),
      ],
    );
  }
}
