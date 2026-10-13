import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/event/event.dart';
import '../../../domain/event/event_occurrence.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../event_editor/application/event_editor_controller.dart';
import '../../event_editor/presentation/event_editor_screen.dart';
import '../../event_editor/presentation/recurring_scope_dialog.dart';
import '../application/calendar_view_provider.dart';
import '../application/hebrew_date_engine_provider.dart';
import '../application/range_events_provider.dart';
import 'paged_focus_sync.dart';
import 'widgets/all_day_events_row.dart';
import 'widgets/calendar_day_header.dart';
import 'widgets/day_occurrences.dart';
import 'widgets/hour_grid.dart';
import 'widgets/week_columns_painter.dart';

const int _daysPerWeek = 7;

/// The week body (M3b): a horizontal seven-day layout starting Sunday
/// (rightmost under RTL — falls out of the ambient `Directionality`, no
/// manual left/right needed), a day-headers row, an all-day events row, and
/// a scrollable 24-hour grid — paged by week via [PagedFocusSync].
class WeekViewScreen extends ConsumerStatefulWidget {
  const WeekViewScreen({super.key});

  @override
  ConsumerState<WeekViewScreen> createState() => _WeekViewScreenState();
}

class _WeekViewScreenState extends ConsumerState<WeekViewScreen> {
  late final PagedFocusSync _sync;

  @override
  void initState() {
    super.initState();
    final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
    _sync = PagedFocusSync(
      initialFocus: ref.read(calendarViewProvider).focusedDate,
      roundToGranularity: engine.startOfWeek,
      stepDate: (HebrewDate anchor, int delta) =>
          engine.addDays(anchor, delta * _daysPerWeek),
      onPageDateChanged: (HebrewDate date) =>
          ref.read(calendarViewProvider.notifier).setFocusedDate(date),
      onAnchorChangedExternally: () => setState(() {}),
    );
  }

  @override
  void dispose() {
    _sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CalendarViewState>(calendarViewProvider, (previous, next) {
      _sync.syncExternalFocus(next.focusedDate);
    });

    return PageView.builder(
      controller: _sync.pageController,
      itemCount: PagedFocusSync.pageWindow * 2 + 1,
      onPageChanged: _sync.onPageChanged,
      itemBuilder: (BuildContext context, int index) {
        return _WeekPage(weekStart: _sync.dateForPage(index));
      },
    );
  }
}

class _WeekPage extends ConsumerWidget {
  const _WeekPage({required this.weekStart});

  final HebrewDate weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final HebrewDate today = engine.fromGregorian(DateTime.now());
    final HebrewDate weekEnd = engine.addDays(weekStart, _daysPerWeek - 1);
    final List<HebrewDate> days = <HebrewDate>[
      for (int i = 0; i < _daysPerWeek; i++) engine.addDays(weekStart, i),
    ];

    final List<EventOccurrence> occurrences =
        ref.watch(rangeEventsProvider((from: weekStart, to: weekEnd))).value ??
        const <EventOccurrence>[];
    final List<DayOccurrences> columns = <DayOccurrences>[
      for (final HebrewDate day in days)
        DayOccurrences(
          date: day,
          occurrences: occurrences
              .where((EventOccurrence o) => o.occurrenceDate == day)
              .toList(),
        ),
    ];

    final ColorScheme colors = Theme.of(context).colorScheme;
    final int todayIndex = days.indexOf(today);
    // Column guides across the whole page: tints behind, dashed lines on
    // top (owner request 2026-10-13).
    return CustomPaint(
      painter: WeekColumnsPainter(
        labelWidth: hourLabelWidth,
        textDirection: Directionality.of(context),
        lineColor: colors.outlineVariant,
        shabbatTint: colors.primary.withValues(alpha: 0.05),
        todayTint: colors.primary.withValues(alpha: 0.07),
        todayIndex: todayIndex < 0 ? null : todayIndex,
        paintLines: false,
      ),
      foregroundPainter: WeekColumnsPainter(
        labelWidth: hourLabelWidth,
        textDirection: Directionality.of(context),
        lineColor: colors.outlineVariant.withValues(alpha: 0.7),
        shabbatTint: Colors.transparent,
        todayTint: Colors.transparent,
        paintTints: false,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(width: hourLabelWidth),
              for (final HebrewDate day in days)
                Expanded(
                  child: CalendarDayHeader(
                    key: ValueKey<String>('week-day-header-$day'),
                    date: day,
                    isToday: day == today,
                  ),
                ),
            ],
          ),
          AllDayEventsRow(
            columns: columns,
            onEventTap: (EventOccurrence occurrence) =>
                openEventEditorForOccurrence(context, occurrence),
          ),
          Expanded(
            child: HourGrid(
              columns: columns,
              onEmptySlotTap: (HebrewDate date, int hour) =>
                  _openEditor(context, initialDate: date, existing: null),
              onEventTap: (EventOccurrence occurrence) =>
                  openEventEditorForOccurrence(context, occurrence),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditor(
    BuildContext context, {
    required HebrewDate initialDate,
    required Event? existing,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventEditorScreen(
          args: EventEditorArgs(initialDate: initialDate, existing: existing),
        ),
      ),
    );
  }
}
