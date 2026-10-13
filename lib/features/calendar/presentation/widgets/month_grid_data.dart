import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/event/event_occurrence.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/jewish_day_info.dart';
import '../../application/jewish_day_labels_provider.dart';
import '../../application/month_events_provider.dart';
import '../../application/range_events_provider.dart';

const int _daysPerWeek = 7;

/// What one month page shows (M23): its cells as whole Sunday-to-Saturday
/// weeks (`null` = a slot outside the month), and the occurrences and
/// holiday labels of its days. A Hebrew month page and a Gregorian month
/// page differ only in how these are gathered.
class MonthGridData {
  const MonthGridData({
    required this.cells,
    required this.occurrences,
    required this.labels,
  });

  final List<HebrewDate?> cells;
  final Map<HebrewDate, List<EventOccurrence>> occurrences;
  final Map<HebrewDate, List<JewishDayLabel>> labels;

  bool contains(HebrewDate date) => cells.contains(date);
}

List<HebrewDate?> _weeks(List<HebrewDate> days, int firstWeekday) {
  final List<HebrewDate?> cells = <HebrewDate?>[
    for (int i = 0; i < firstWeekday; i++) null,
    ...days,
  ];
  while (cells.length % _daysPerWeek != 0) {
    cells.add(null);
  }
  return cells;
}

Map<HebrewDate, List<EventOccurrence>> _byDate(List<EventOccurrence> list) {
  final Map<HebrewDate, List<EventOccurrence>> map =
      <HebrewDate, List<EventOccurrence>>{};
  for (final EventOccurrence o in list) {
    map.putIfAbsent(o.occurrenceDate, () => <EventOccurrence>[]).add(o);
  }
  return map;
}

/// The Hebrew month containing [month] (the original month view).
MonthGridData hebrewMonthData(
  WidgetRef ref,
  HebrewDateEngine engine,
  HebrewDate month,
) {
  // Provider keys use the month's first day: keying on the selected day
  // re-ran the month's queries on every tap (round #10).
  final HebrewDate first = HebrewDate(
    year: month.year,
    month: month.month,
    day: 1,
  );
  final int days = engine.daysInMonth(month.year, month.month);
  final Map<int, List<JewishDayLabel>> labelsByDay = ref.watch(
    monthDayLabelsProvider(first),
  );
  return MonthGridData(
    cells: _weeks(<HebrewDate>[
      for (int day = 1; day <= days; day++)
        HebrewDate(year: month.year, month: month.month, day: day),
    ], engine.weekdayIndex(first)),
    occurrences: _byDate(
      ref.watch(monthEventsProvider(first)).value ?? const <EventOccurrence>[],
    ),
    labels: <HebrewDate, List<JewishDayLabel>>{
      for (final MapEntry<int, List<JewishDayLabel>> e in labelsByDay.entries)
        HebrewDate(year: month.year, month: month.month, day: e.key): e.value,
    },
  );
}

/// The Gregorian month containing the civil date of [anyDay] (M23). It can
/// touch up to three Hebrew months, so labels are gathered per Hebrew month.
MonthGridData gregorianMonthData(
  WidgetRef ref,
  HebrewDateEngine engine,
  HebrewDate anyDay,
) {
  final DateTime g = engine.toGregorian(anyDay);
  final int days = DateTime(g.year, g.month + 1, 0).day;
  final List<HebrewDate> dates = <HebrewDate>[
    for (int d = 1; d <= days; d++)
      engine.fromGregorian(DateTime(g.year, g.month, d)),
  ];
  final Map<HebrewDate, List<JewishDayLabel>> labels =
      <HebrewDate, List<JewishDayLabel>>{};
  final Set<HebrewDate> hebrewMonths = <HebrewDate>{
    for (final HebrewDate d in dates)
      HebrewDate(year: d.year, month: d.month, day: 1),
  };
  for (final HebrewDate first in hebrewMonths) {
    ref.watch(monthDayLabelsProvider(first)).forEach((
      int day,
      List<JewishDayLabel> list,
    ) {
      labels[HebrewDate(year: first.year, month: first.month, day: day)] = list;
    });
  }
  return MonthGridData(
    // DateTime.weekday is 1 (Monday)..7 (Sunday); the grid starts Sunday.
    cells: _weeks(dates, DateTime(g.year, g.month, 1).weekday % 7),
    occurrences: _byDate(
      ref
              .watch(rangeEventsProvider((from: dates.first, to: dates.last)))
              .value ??
          const <EventOccurrence>[],
    ),
    labels: labels,
  );
}

/// The Hebrew date one Gregorian month step [delta] from [anchor], keeping
/// the Gregorian day (clamped to the target month's length). The month
/// pages' step in the Gregorian display.
HebrewDate addGregorianMonths(
  HebrewDateEngine engine,
  HebrewDate anchor,
  int delta,
) {
  final DateTime g = engine.toGregorian(anchor);
  final int lastDay = DateTime(g.year, g.month + delta + 1, 0).day;
  return engine.fromGregorian(
    DateTime(g.year, g.month + delta, g.day > lastDay ? lastDay : g.day),
  );
}
