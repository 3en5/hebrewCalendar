import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/event/event.dart';
import '../../../domain/event/event_occurrence.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../event_editor/presentation/event_editor_screen.dart';
import '../application/calendar_view_provider.dart';
import '../application/hebrew_date_engine_provider.dart';
import '../application/range_events_provider.dart';
import 'paged_focus_sync.dart';
import 'widgets/all_day_events_row.dart';
import 'widgets/calendar_day_header.dart';
import 'widgets/day_occurrences.dart';
import 'widgets/hour_grid.dart';

/// The day body (M3b): a single day's full Hebrew-date header, an all-day
/// events row, and a scrollable 24-hour grid with that day's timed events —
/// paged one day at a time via [PagedFocusSync].
class DayViewScreen extends ConsumerStatefulWidget {
  const DayViewScreen({super.key});

  @override
  ConsumerState<DayViewScreen> createState() => _DayViewScreenState();
}

class _DayViewScreenState extends ConsumerState<DayViewScreen> {
  late final PagedFocusSync _sync;

  @override
  void initState() {
    super.initState();
    final HebrewDateEngine engine = ref.read(hebrewDateEngineProvider);
    _sync = PagedFocusSync(
      initialFocus: ref.read(calendarViewProvider).focusedDate,
      roundToGranularity: (HebrewDate date) => date,
      stepDate: (HebrewDate anchor, int delta) => engine.addDays(anchor, delta),
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
        return _DayPage(date: _sync.dateForPage(index));
      },
    );
  }
}

class _DayPage extends ConsumerWidget {
  const _DayPage({required this.date});

  final HebrewDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final HebrewDate today = engine.fromGregorian(DateTime.now());
    final List<EventOccurrence> occurrences =
        ref.watch(rangeEventsProvider((from: date, to: date))).value ??
        const <EventOccurrence>[];
    final DayOccurrences column = DayOccurrences(
      date: date,
      occurrences: occurrences,
    );

    return Column(
      children: <Widget>[
        CalendarDayHeader(
          date: date,
          isToday: date == today,
          mode: CalendarDayHeaderMode.full,
        ),
        AllDayEventsRow(
          columns: <DayOccurrences>[column],
          onEventTap: (EventOccurrence occurrence) => _openEditor(
            context,
            initialDate: occurrence.event.hebrewDate,
            existing: occurrence.event,
          ),
        ),
        Expanded(
          child: HourGrid(
            columns: <DayOccurrences>[column],
            onEmptySlotTap: (HebrewDate tappedDate, int hour) =>
                _openEditor(context, initialDate: tappedDate, existing: null),
            onEventTap: (EventOccurrence occurrence) => _openEditor(
              context,
              initialDate: occurrence.event.hebrewDate,
              existing: occurrence.event,
            ),
          ),
        ),
      ],
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
          args: (initialDate: initialDate, existing: existing),
        ),
      ),
    );
  }
}
