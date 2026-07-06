import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/event/event.dart';
import '../../../../domain/event/event_occurrence.dart';

/// A single timed event rendered as a rounded, `colorScheme.primaryContainer`
/// block inside the week/day hour grid (M3b) — title and start time, tap to
/// edit. Sized/positioned by its caller (`HourGrid`); this widget only knows
/// how to paint itself within whatever box it's given.
class EventBlock extends StatelessWidget {
  const EventBlock({required this.occurrence, required this.onTap, super.key});

  final EventOccurrence occurrence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Event event = occurrence.event;
    final String? timeLabel = event.startTime?.toString();

    return Padding(
      padding: EdgeInsetsDirectional.all(spacingXs / 2),
      child: Material(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(spacingXs),
        child: InkWell(
          borderRadius: BorderRadius.circular(spacingXs),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: spacingXs,
              vertical: spacingXs / 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: captionRem,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                if (timeLabel != null)
                  Text(
                    timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: captionRem,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
