import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/theme/event_colors.dart';
import '../../../../domain/event/event_occurrence.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/jewish_day_info.dart';
import '../../application/calendar_view_provider.dart';
import '../../application/hebrew_date_engine_provider.dart';
import '../../application/jewish_day_labels_provider.dart';
import '../../application/month_events_provider.dart';
import 'day_cell.dart';
import 'month_day_agenda.dart';

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

const int _daysPerWeek = 7;

/// Share of the vertical space below the weekday header given to the grid;
/// the rest goes to the selected day's agenda. Owner feedback: the calendar
/// itself should get the larger part.
const double _gridHeightShare = 0.64;

/// Renders one Hebrew month (owner-approved design): a weekday header row,
/// a grid of thin-lined day cells (only as many weeks as the month spans,
/// RTL-laid-out via the ambient Hebrew [Directionality], week starts
/// Sunday), and below it [MonthDayAgenda] for the selected day — the
/// shell's focused date when it falls in this month. Tapping a day selects
/// it. Days borrowed from adjacent months render as empty cells.
class MonthGrid extends ConsumerWidget {
  const MonthGrid({required this.displayedMonth, super.key});

  /// The month being displayed. Its `day` is the fallback selected day when
  /// the shell's focused date is in a different month (a neighbor page).
  final HebrewDate displayedMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final HebrewDate today = engine.fromGregorian(DateTime.now());
    // Provider keys use the month's first day: `displayedMonth.day` follows
    // the selected day, and keying on it re-ran the month's queries on every
    // tap (round #10).
    final HebrewDate firstOfMonth = HebrewDate(
      year: displayedMonth.year,
      month: displayedMonth.month,
      day: 1,
    );
    final HebrewDate focused = ref.watch(
      calendarViewProvider.select((CalendarViewState s) => s.focusedDate),
    );
    final HebrewDate selected = _isSameMonth(focused, displayedMonth)
        ? focused
        : displayedMonth;
    final List<HebrewDate?> cells = _buildCells(engine, displayedMonth);
    final int rowCount = cells.length ~/ _daysPerWeek;
    final List<EventOccurrence> monthOccurrences =
        ref.watch(monthEventsProvider(firstOfMonth)).value ??
        const <EventOccurrence>[];
    final Map<int, List<JewishDayLabel>> labelsByDay = ref.watch(
      monthDayLabelsProvider(firstOfMonth),
    );
    final Map<int, List<EventOccurrence>> occurrencesByDay =
        <int, List<EventOccurrence>>{};
    for (final EventOccurrence occurrence in monthOccurrences) {
      occurrencesByDay
          .putIfAbsent(occurrence.occurrenceDate.day, () => <EventOccurrence>[])
          .add(occurrence);
    }

    // Device feedback: pulling the screen down syncs with Google (the
    // shell's RefreshIndicator). The month page itself isn't scrollable, so
    // it sits in an always-scrollable view exactly one screen tall to let
    // the pull gesture start anywhere on it.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewport) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: viewport.maxHeight,
          child: Column(
            children: <Widget>[
              const _WeekdayHeaderRow(),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double rowHeight =
                        (constraints.maxHeight * _gridHeightShare / rowCount)
                            .clamp(rem(2.75), rem(4.5));
                    return Column(
                      children: <Widget>[
                        for (int row = 0; row < rowCount; row++)
                          SizedBox(
                            height: rowHeight,
                            child: Row(
                              // Stretch so empty (out-of-month) cells, which have
                              // no child to size them, still fill the row and
                              // their grid lines line up with the day cells'.
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                for (int col = 0; col < _daysPerWeek; col++)
                                  Expanded(
                                    child: _buildCell(
                                      context,
                                      ref,
                                      cells[row * _daysPerWeek + col],
                                      col: col,
                                      today: today,
                                      selected: selected,
                                      occurrencesByDay: occurrencesByDay,
                                      labelsByDay: labelsByDay,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: MonthDayAgenda(
                            date: selected,
                            labels:
                                labelsByDay[selected.day] ??
                                const <JewishDayLabel>[],
                            occurrences:
                                occurrencesByDay[selected.day] ??
                                const <EventOccurrence>[],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    WidgetRef ref,
    HebrewDate? cellDate, {
    required int col,
    required HebrewDate today,
    required HebrewDate selected,
    required Map<int, List<EventOccurrence>> occurrencesByDay,
    required Map<int, List<JewishDayLabel>> labelsByDay,
  }) {
    final bool drawEndLine = col < _daysPerWeek - 1;
    if (cellDate == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: monthGridLineBorder(context, drawEndLine: drawEndLine),
        ),
      );
    }
    final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
    return DayCell(
      hebrewDay: cellDate.day,
      gregorianDay: engine.toGregorian(cellDate).day,
      isToday: cellDate == today,
      isSelected: cellDate == selected,
      isShabbat: col == _daysPerWeek - 1,
      drawEndLine: drawEndLine,
      eventColors: <Color>[
        for (final EventOccurrence o
            in occurrencesByDay[cellDate.day] ?? const <EventOccurrence>[])
          eventColor(o.event.colorId, Theme.of(context).colorScheme),
      ],
      // Labels are ordered most important first, parsha last.
      label: labelsByDay[cellDate.day]?.first,
      onTap: () =>
          ref.read(calendarViewProvider.notifier).setFocusedDate(cellDate),
    );
  }

  static bool _isSameMonth(HebrewDate a, HebrewDate b) =>
      a.year == b.year && a.month == b.month;

  /// Builds the grid cells for [month] as whole Sunday-to-Saturday weeks,
  /// only as many as the month spans (5 or 6): `null` for the leading/trailing slots outside the
  /// month, which render as empty cells (device feedback: adjacent-month
  /// days cluttered the view).
  static List<HebrewDate?> _buildCells(
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

    final List<HebrewDate?> cells = <HebrewDate?>[
      for (int i = 0; i < firstWeekday; i++) null,
      for (int day = 1; day <= daysInMonth; day++)
        HebrewDate(year: month.year, month: month.month, day: day),
    ];
    while (cells.length % _daysPerWeek != 0) {
      cells.add(null);
    }
    return cells;
  }
}

class _WeekdayHeaderRow extends StatelessWidget {
  const _WeekdayHeaderRow();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextStyle? style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant);

    return Container(
      padding: EdgeInsetsDirectional.symmetric(vertical: spacingXs),
      // The grid's top line; each cell draws its own bottom/end lines.
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _weekdayLetters.length; i++)
            Expanded(
              child: Center(
                child: Text(
                  _weekdayLetters[i],
                  // Shabbat's letter in the accent color, matching the
                  // tinted Shabbat column below it.
                  style: i == _weekdayLetters.length - 1
                      ? style?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        )
                      : style,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
