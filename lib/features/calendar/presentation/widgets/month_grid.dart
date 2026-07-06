import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/event/event_occurrence.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../application/hebrew_date_engine_provider.dart';
import '../../application/month_events_provider.dart';
import 'day_cell.dart';
import 'day_events_sheet.dart';

/// Sunday-first single-letter weekday abbreviations (א׳..ש׳). Saturday uses
/// ש for Shabbat rather than the number 7, per Hebrew calendar convention.
const List<String> _weekdayLetters = <String>[
  'א׳',
  'ב׳',
  'ג׳',
  'ד׳',
  'ה׳',
  'ו׳',
  'ש׳',
];

/// Number of cells in the grid: always 6 full Sunday-to-Saturday weeks, the
/// same fixed layout Google Calendar's month view uses.
const int _gridCellCount = 42;
const int _daysPerWeek = 7;

/// Renders one Hebrew month as a Google-Calendar-like grid: a weekday
/// header row followed by a 6-week day grid (RTL-laid-out via the ambient
/// Hebrew [Directionality], week starts Sunday). Leading/trailing days
/// borrowed from adjacent months are dimmed; today is highlighted.
class MonthGrid extends ConsumerWidget {
  const MonthGrid({required this.displayedMonth, super.key});

  /// The month being displayed (the `day` field is ignored).
  final HebrewDate displayedMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final HebrewDate today = engine.fromGregorian(DateTime.now());
    final List<HebrewDate> cells = _buildCells(engine, displayedMonth);
    final List<EventOccurrence> monthOccurrences =
        ref.watch(monthEventsProvider(displayedMonth)).value ??
        const <EventOccurrence>[];
    final Map<int, List<EventOccurrence>> occurrencesByDay =
        <int, List<EventOccurrence>>{};
    for (final EventOccurrence occurrence in monthOccurrences) {
      occurrencesByDay
          .putIfAbsent(occurrence.occurrenceDate.day, () => <EventOccurrence>[])
          .add(occurrence);
    }

    return Column(
      children: <Widget>[
        _WeekdayHeaderRow(),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsetsDirectional.all(spacingSm),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _daysPerWeek,
            ),
            itemCount: cells.length,
            itemBuilder: (BuildContext context, int index) {
              final HebrewDate cellDate = cells[index];
              final bool inDisplayedMonth =
                  cellDate.year == displayedMonth.year &&
                  cellDate.month == displayedMonth.month;
              final DateTime gregorianDate = engine.toGregorian(cellDate);
              final List<EventOccurrence> dayOccurrences = inDisplayedMonth
                  ? (occurrencesByDay[cellDate.day] ??
                        const <EventOccurrence>[])
                  : const <EventOccurrence>[];
              return DayCell(
                hebrewDay: cellDate.day,
                gregorianDay: gregorianDate.day,
                isInDisplayedMonth: inDisplayedMonth,
                isToday: cellDate == today,
                hasEvents: dayOccurrences.isNotEmpty,
                onTap: dayOccurrences.isEmpty
                    ? null
                    : () => _showDayEvents(context, cellDate, dayOccurrences),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDayEvents(
    BuildContext context,
    HebrewDate date,
    List<EventOccurrence> occurrences,
  ) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DayEventsSheet(date: date, occurrences: occurrences),
      ),
    );
  }

  /// Builds the fixed 42-cell (6-week) grid for [month]: leading days
  /// borrowed from the previous Hebrew month, the month's own days, then
  /// trailing days borrowed from the next Hebrew month.
  static List<HebrewDate> _buildCells(
    HebrewDateEngine engine,
    HebrewDate month,
  ) {
    final HebrewDate firstOfMonth = HebrewDate(
      year: month.year,
      month: month.month,
      day: 1,
    );
    final int firstWeekday = engine.weekdayIndex(firstOfMonth);
    final int daysInMonth = engine.daysInMonth(month.year, month.month);

    final HebrewDate previousMonth = engine.previousMonth(firstOfMonth);
    final int previousMonthDays = engine.daysInMonth(
      previousMonth.year,
      previousMonth.month,
    );
    final HebrewDate nextMonth = engine.nextMonth(firstOfMonth);

    final List<HebrewDate> cells = <HebrewDate>[];

    for (int i = firstWeekday - 1; i >= 0; i--) {
      cells.add(
        HebrewDate(
          year: previousMonth.year,
          month: previousMonth.month,
          day: previousMonthDays - i,
        ),
      );
    }
    for (int day = 1; day <= daysInMonth; day++) {
      cells.add(HebrewDate(year: month.year, month: month.month, day: day));
    }
    final int trailingDays = _gridCellCount - cells.length;
    for (int day = 1; day <= trailingDays; day++) {
      cells.add(
        HebrewDate(year: nextMonth.year, month: nextMonth.month, day: day),
      );
    }

    return cells;
  }
}

class _WeekdayHeaderRow extends StatelessWidget {
  const _WeekdayHeaderRow();

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: spacingXs),
      child: Row(
        children: <Widget>[
          for (final String letter in _weekdayLetters)
            Expanded(
              child: Center(child: Text(letter, style: style)),
            ),
        ],
      ),
    );
  }
}
