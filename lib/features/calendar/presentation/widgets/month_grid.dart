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
import '../../../zmanim/application/zmanim_settings.dart';
import '../../../zmanim/presentation/shabbat_times.dart';
import 'day_cell.dart';
import 'day_pop_stack.dart';
import 'day_swipe_area.dart';
import 'month_grid_data.dart';
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
/// it; swiping the agenda moves a day ([DaySwipeArea]). Days borrowed from
/// adjacent months render as empty cells.
class MonthGrid extends ConsumerWidget {
  const MonthGrid({
    required this.displayedMonth,
    this.gregorian = false,
    super.key,
  });

  /// The month being displayed. Its `day` is the fallback selected day when
  /// the shell's focused date is in a different month (a neighbor page).
  /// In the Gregorian display, any day of the Gregorian month shown.
  final HebrewDate displayedMonth;

  /// Lay the page out by Gregorian months, the Gregorian day first (M23).
  final bool gregorian;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final HebrewDate today = engine.fromGregorian(DateTime.now());
    final HebrewDate focused = ref.watch(
      calendarViewProvider.select((CalendarViewState s) => s.focusedDate),
    );
    final MonthGridData data = gregorian
        ? gregorianMonthData(ref, engine, displayedMonth)
        : hebrewMonthData(ref, engine, displayedMonth);
    final HebrewDate selected = data.contains(focused)
        ? focused
        : displayedMonth;
    final List<HebrewDate?> cells = data.cells;
    final int rowCount = cells.length ~/ _daysPerWeek;
    final ZmanimSettings zmanimSettings = ref.watch(zmanimSettingsProvider);

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
                    // The tapped day pops over the grid and the agenda.
                    return DayPopStack(
                      child: Column(
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
                                      child: Builder(
                                        builder: (BuildContext cellContext) =>
                                            _buildCell(
                                              cellContext,
                                              ref,
                                              cells[row * _daysPerWeek + col],
                                              col: col,
                                              today: today,
                                              selected: selected,
                                              data: data,
                                              zmanimSettings: zmanimSettings,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: DaySwipeArea(
                              date: selected,
                              child: MonthDayAgenda(
                                date: selected,
                                labels:
                                    data.labels[selected] ??
                                    const <JewishDayLabel>[],
                                occurrences:
                                    data.occurrences[selected] ??
                                    const <EventOccurrence>[],
                              ),
                            ),
                          ),
                        ],
                      ),
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
    required MonthGridData data,
    required ZmanimSettings zmanimSettings,
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
    final DateTime gregorianDate = engine.toGregorian(cellDate);
    DayCell cell({required bool isSelected, required bool endLine}) => DayCell(
      hebrewDay: cellDate.day,
      gregorianDay: gregorianDate.day,
      gregorianPrimary: gregorian,
      isToday: cellDate == today,
      isSelected: isSelected,
      isShabbat: col == _daysPerWeek - 1,
      drawEndLine: endLine,
      eventColors: <Color>[
        for (final EventOccurrence o
            in data.occurrences[cellDate] ?? const <EventOccurrence>[])
          eventColor(o.event.colorId, Theme.of(context).colorScheme),
      ],
      // Labels are ordered most important first, parsha last.
      label: data.labels[cellDate]?.first,
      shabbatTime: shabbatTimeFor(zmanimSettings, gregorianDate),
      onTap: () {
        ref.read(calendarViewProvider.notifier).setFocusedDate(cellDate);
        DayPopStack.maybeOf(
          context,
        )?.pop(context, cell(isSelected: true, endLine: false));
      },
    );
    return cell(isSelected: cellDate == selected, endLine: drawEndLine);
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
