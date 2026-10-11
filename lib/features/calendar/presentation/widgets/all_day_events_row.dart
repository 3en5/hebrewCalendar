import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/theme/event_colors.dart';
import '../../../../domain/event/event_occurrence.dart';
import 'day_occurrences.dart';

/// The all-day events row shown above the hour grid in the week/day views
/// (M3b): one column per [DayOccurrences.date], each a stack of small
/// `colorScheme.primaryContainer` chips for that day's all-day events. A
/// leading spacer matching [hourLabelWidth] keeps the columns aligned with
/// `HourGrid`'s day columns underneath.
class AllDayEventsRow extends StatelessWidget {
  const AllDayEventsRow({
    required this.columns,
    required this.onEventTap,
    super.key,
  });

  final List<DayOccurrences> columns;
  final void Function(EventOccurrence occurrence) onEventTap;

  @override
  Widget build(BuildContext context) {
    final bool anyAllDay = columns.any(
      (DayOccurrences column) => column.allDay.isNotEmpty,
    );
    if (!anyAllDay) {
      return const SizedBox.shrink();
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: hourLabelWidth),
          for (final DayOccurrences column in columns)
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: spacingXs / 2,
                ),
                child: Column(
                  children: <Widget>[
                    for (final EventOccurrence occurrence in column.allDay)
                      _AllDayChip(
                        occurrence: occurrence,
                        onTap: () => onEventTap(occurrence),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip({required this.occurrence, required this.onTap});

  final EventOccurrence occurrence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final ({Color background, Color foreground}) colors = eventSurfaceColors(
      occurrence.event.colorId,
      colorScheme,
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: spacingXs / 2),
      child: Material(
        color: colors.background,
        borderRadius: BorderRadius.circular(spacingXs),
        child: InkWell(
          borderRadius: BorderRadius.circular(spacingXs),
          onTap: onTap,
          child: Container(
            height: allDayChipHeight,
            alignment: AlignmentDirectional.centerStart,
            padding: EdgeInsetsDirectional.symmetric(horizontal: spacingXs),
            child: Text(
              occurrence.event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: captionRem,
                fontWeight: FontWeight.w600,
                color: colors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
