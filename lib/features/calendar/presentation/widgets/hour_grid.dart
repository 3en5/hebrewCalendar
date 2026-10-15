import 'dart:async' show Timer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/event/event.dart';
import '../../../../domain/event/event_occurrence.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../application/hebrew_date_engine_provider.dart';
import 'day_occurrences.dart';
import 'event_block.dart';

const int _hoursPerDay = 24;

/// Fallback duration (minutes) used to size/lay out a timed event that has
/// no [Event.endTime] (or an end time at/before its start) — purely a
/// display heuristic, never written back to the event.
const int _defaultDurationMinutes = 60;

/// A vertically-scrollable 24-hour grid with one column per
/// [DayOccurrences] (one column for the day view, seven for the week view),
/// each showing its timed events as positioned, `EventBlock`s. Overlapping
/// events within a column split the column's width equally among the
/// overlapping cluster (task brief M3b §3 — "simple algorithm: divide
/// equally").
///
/// Tapping an empty hour slot calls [onEmptySlotTap] with that column's date
/// and the tapped hour; tapping an event block calls [onEventTap] instead —
/// the block's own `InkWell` is hit-tested first since it's painted above
/// the slot's `GestureDetector` in the `Stack`, so the two never conflict.
///
/// The grid opens scrolled to an hour before the current time, and today's
/// column carries a "now" line with a dot, like Google Calendar (tester
/// request 2026-10-14). A timer moves the line every half minute and is
/// cancelled on dispose.
class HourGrid extends ConsumerStatefulWidget {
  const HourGrid({
    required this.columns,
    required this.onEmptySlotTap,
    required this.onEventTap,
    super.key,
  });

  final List<DayOccurrences> columns;
  final void Function(HebrewDate date, int hour) onEmptySlotTap;
  final void Function(EventOccurrence occurrence) onEventTap;

  @override
  ConsumerState<HourGrid> createState() => _HourGridState();
}

/// How far above the current time the grid opens, so the hour just past
/// stays in view.
const Duration _leadBeforeNow = Duration(hours: 1);

/// How often the "now" line moves.
const Duration _nowTick = Duration(seconds: 30);

class _HourGridState extends ConsumerState<HourGrid> {
  /// Created on the first layout, once the viewport height is known, so the
  /// opening offset can be clamped to the end of the day.
  ScrollController? _scroll;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_nowTick, (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll?.dispose();
    super.dispose();
  }

  ScrollController _controllerFor(double viewportHeight) {
    final ScrollController? existing = _scroll;
    if (existing != null) {
      return existing;
    }
    final double total = hourRowHeight * _hoursPerDay;
    final double target =
        _minutesOf(_now.subtract(_leadBeforeNow)) / 60 * hourRowHeight;
    // Just after midnight the lead wraps to yesterday's evening: open at
    // the top instead.
    final double wanted = _now.hour < _leadBeforeNow.inHours ? 0 : target;
    final double offset = math.max(0, math.min(wanted, total - viewportHeight));
    return _scroll = ScrollController(initialScrollOffset: offset);
  }

  @override
  Widget build(BuildContext context) {
    final List<DayOccurrences> columns = widget.columns;
    final HebrewDate today = ref
        .watch(hebrewDateEngineProvider)
        .fromGregorian(_now);
    final int nowMinutes = _minutesOf(_now);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          controller: _controllerFor(constraints.maxHeight),
          child: SizedBox(
            height: hourRowHeight * _hoursPerDay,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _HourLabelColumn(),
                for (final DayOccurrences column in columns)
                  Expanded(
                    child: _DayColumn(
                      column: column,
                      nowMinutes: column.date == today ? nowMinutes : null,
                      onEmptySlotTap: widget.onEmptySlotTap,
                      onEventTap: widget.onEventTap,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

int _minutesOf(DateTime time) => time.hour * 60 + time.minute;

/// The red "now" line across today's column, with a dot at its start edge.
class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.error;
    final double dot = rem(0.75);
    return IgnorePointer(
      child: SizedBox(
        key: const ValueKey<String>('hour-grid-now-line'),
        height: dot,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: AlignmentDirectional.centerStart,
          children: <Widget>[
            Container(height: rem(0.125), color: color),
            PositionedDirectional(
              start: -dot / 2,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourLabelColumn extends StatelessWidget {
  const _HourLabelColumn();

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: hourLabelWidth,
      child: Column(
        children: <Widget>[
          for (int hour = 0; hour < _hoursPerDay; hour++)
            SizedBox(
              height: hourRowHeight,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: spacingXs,
                  top: spacingXs,
                ),
                child: Align(
                  alignment: AlignmentDirectional.topEnd,
                  // One line at any text size (owner sketch 2026-10-15:
                  // at 140% "13:00" broke in two): shrink to the gutter.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$hour:00',
                      maxLines: 1,
                      style: TextStyle(fontSize: captionRem, color: color),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.column,
    required this.nowMinutes,
    required this.onEmptySlotTap,
    required this.onEventTap,
  });

  final DayOccurrences column;

  /// Minutes since midnight when this column is today, else null.
  final int? nowMinutes;
  final void Function(HebrewDate date, int hour) onEmptySlotTap;
  final void Function(EventOccurrence occurrence) onEventTap;

  @override
  Widget build(BuildContext context) {
    final int? now = nowMinutes;
    final Color lineColor = Theme.of(context).colorScheme.outlineVariant;
    final List<_PositionedEvent> positioned = _layoutTimedEvents(column.timed);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Column(
              children: <Widget>[
                for (int hour = 0; hour < _hoursPerDay; hour++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onEmptySlotTap(column.date, hour),
                    child: Container(
                      height: hourRowHeight,
                      decoration: BoxDecoration(
                        border: BorderDirectional(
                          top: BorderSide(color: lineColor),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (final _PositionedEvent event in positioned)
              PositionedDirectional(
                top: (event.startMinutes / 60) * hourRowHeight,
                start:
                    (constraints.maxWidth / event.columnCount) *
                    event.columnIndex,
                width: constraints.maxWidth / event.columnCount,
                height: (event.durationMinutes / 60 * hourRowHeight).clamp(
                  eventBlockMinHeight,
                  double.infinity,
                ),
                child: EventBlock(
                  occurrence: event.occurrence,
                  onTap: () => onEventTap(event.occurrence),
                ),
              ),
            if (now != null)
              PositionedDirectional(
                top: now / 60 * hourRowHeight - rem(0.75) / 2,
                start: 0,
                end: 0,
                child: const _NowLine(),
              ),
          ],
        );
      },
    );
  }
}

class _PositionedEvent {
  const _PositionedEvent({
    required this.occurrence,
    required this.startMinutes,
    required this.durationMinutes,
    required this.columnIndex,
    required this.columnCount,
  });

  final EventOccurrence occurrence;
  final int startMinutes;
  final int durationMinutes;
  final int columnIndex;
  final int columnCount;
}

/// Lays out [occurrences] (already filtered to timed events) top-to-bottom
/// by start time, splitting each cluster of mutually-overlapping events
/// into equal-width side-by-side columns.
List<_PositionedEvent> _layoutTimedEvents(List<EventOccurrence> occurrences) {
  final List<EventOccurrence> sorted = <EventOccurrence>[...occurrences]
    ..sort(
      (EventOccurrence a, EventOccurrence b) =>
          _startMinutes(a).compareTo(_startMinutes(b)),
    );

  final List<List<EventOccurrence>> clusters = <List<EventOccurrence>>[];
  List<EventOccurrence> currentCluster = <EventOccurrence>[];
  int currentClusterEnd = -1;
  for (final EventOccurrence occurrence in sorted) {
    final int start = _startMinutes(occurrence);
    final int end = _endMinutes(occurrence);
    if (currentCluster.isEmpty || start < currentClusterEnd) {
      currentCluster.add(occurrence);
      currentClusterEnd = end > currentClusterEnd ? end : currentClusterEnd;
    } else {
      clusters.add(currentCluster);
      currentCluster = <EventOccurrence>[occurrence];
      currentClusterEnd = end;
    }
  }
  if (currentCluster.isNotEmpty) {
    clusters.add(currentCluster);
  }

  final List<_PositionedEvent> positioned = <_PositionedEvent>[];
  for (final List<EventOccurrence> cluster in clusters) {
    final int columnCount = cluster.length;
    for (int i = 0; i < cluster.length; i++) {
      final EventOccurrence occurrence = cluster[i];
      positioned.add(
        _PositionedEvent(
          occurrence: occurrence,
          startMinutes: _startMinutes(occurrence),
          durationMinutes: _endMinutes(occurrence) - _startMinutes(occurrence),
          columnIndex: i,
          columnCount: columnCount,
        ),
      );
    }
  }
  return positioned;
}

int _startMinutes(EventOccurrence occurrence) =>
    occurrence.event.startTime?.minutesFromMidnight ?? 0;

int _endMinutes(EventOccurrence occurrence) {
  final int start = _startMinutes(occurrence);
  final int? end = occurrence.event.endTime?.minutesFromMidnight;
  if (end == null || end <= start) {
    return start + _defaultDurationMinutes;
  }
  return end;
}
