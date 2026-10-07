import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/event/event.dart';
import '../../../../domain/event/event_occurrence.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
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
class HourGrid extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                  onEmptySlotTap: onEmptySlotTap,
                  onEventTap: onEventTap,
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
                  child: Text(
                    '$hour:00',
                    style: TextStyle(fontSize: captionRem, color: color),
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
    required this.onEmptySlotTap,
    required this.onEventTap,
  });

  final DayOccurrences column;
  final void Function(HebrewDate date, int hour) onEmptySlotTap;
  final void Function(EventOccurrence occurrence) onEventTap;

  @override
  Widget build(BuildContext context) {
    final Color lineColor = Theme.of(context).colorScheme.outlineVariant;
    final List<_PositionedEvent> positioned = _layoutTimedEvents(column.timed);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
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
