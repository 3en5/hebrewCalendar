import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../calendar/application/hebrew_date_engine_provider.dart';

/// How many years on either side of the initial year the year dropdown
/// offers — comfortably beyond any realistic event date, while keeping the
/// dropdown list short enough to stay usable (task brief §4: "keep it
/// simple").
const int _yearRangeRadius = 100;

/// A bottom sheet that picks a [HebrewDate] via three dropdowns (year,
/// month, day), Hebrew-native: years and days are shown in gematria, month
/// names include אדר א׳/אדר ב׳ in leap years. Returns the picked date via
/// `Navigator.pop`, or null if dismissed.
class HebrewDatePickerSheet extends ConsumerStatefulWidget {
  const HebrewDatePickerSheet({required this.initialDate, super.key});

  final HebrewDate initialDate;

  @override
  ConsumerState<HebrewDatePickerSheet> createState() =>
      _HebrewDatePickerSheetState();
}

class _HebrewDatePickerSheetState extends ConsumerState<HebrewDatePickerSheet> {
  late int _year;
  late HebrewMonth _month;
  late int _day;

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _month = widget.initialDate.month;
    _day = widget.initialDate.day;
  }

  @override
  Widget build(BuildContext context) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);

    final List<HebrewMonth> months = engine.monthsInYear(_year);
    if (!months.contains(_month)) {
      // A leap <-> non-leap year change makes plain אדר / אדר א׳/ב׳
      // mutually exclusive; fall back to the first month of the new year.
      _month = months.first;
    }
    final int maxDay = engine.daysInMonth(_year, _month);
    if (_day > maxDay) {
      _day = maxDay;
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacingMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.eventHebrewDateLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: spacingMd),
            Row(
              children: <Widget>[
                Expanded(child: _yearDropdown(l10n)),
                SizedBox(width: spacingSm),
                Expanded(child: _monthDropdown(engine, months, l10n)),
                SizedBox(width: spacingSm),
                Expanded(child: _dayDropdown(maxDay, l10n)),
              ],
            ),
            SizedBox(height: spacingMd),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(HebrewDate(year: _year, month: _month, day: _day)),
              child: Text(l10n.hebrewDatePickerConfirm),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yearDropdown(AppLocalizations l10n) {
    final int rangeStart = widget.initialDate.year - _yearRangeRadius;
    final int rangeEnd = widget.initialDate.year + _yearRangeRadius;
    return DropdownButtonFormField<int>(
      value: _year,
      decoration: InputDecoration(labelText: l10n.hebrewDatePickerYearLabel),
      items: <DropdownMenuItem<int>>[
        for (int year = rangeStart; year <= rangeEnd; year++)
          DropdownMenuItem<int>(
            value: year,
            child: Text(hebrewYearNumeral(year)),
          ),
      ],
      onChanged: (int? value) {
        if (value != null) {
          setState(() => _year = value);
        }
      },
    );
  }

  Widget _monthDropdown(
    HebrewDateEngine engine,
    List<HebrewMonth> months,
    AppLocalizations l10n,
  ) {
    return DropdownButtonFormField<HebrewMonth>(
      value: _month,
      decoration: InputDecoration(labelText: l10n.hebrewDatePickerMonthLabel),
      items: <DropdownMenuItem<HebrewMonth>>[
        for (final HebrewMonth month in months)
          DropdownMenuItem<HebrewMonth>(
            value: month,
            child: Text(engine.monthName(month)),
          ),
      ],
      onChanged: (HebrewMonth? value) {
        if (value != null) {
          setState(() => _month = value);
        }
      },
    );
  }

  Widget _dayDropdown(int maxDay, AppLocalizations l10n) {
    return DropdownButtonFormField<int>(
      value: _day,
      decoration: InputDecoration(labelText: l10n.hebrewDatePickerDayLabel),
      items: <DropdownMenuItem<int>>[
        for (int day = 1; day <= maxDay; day++)
          DropdownMenuItem<int>(value: day, child: Text(hebrewDayNumeral(day))),
      ],
      onChanged: (int? value) {
        if (value != null) {
          setState(() => _day = value);
        }
      },
    );
  }
}
