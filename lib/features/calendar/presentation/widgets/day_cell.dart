import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';

/// A single day cell in the month grid: the Hebrew day number in gematria
/// (primary, larger) with the Gregorian day number underneath (secondary,
/// smaller). Days outside the displayed month are dimmed; today is
/// highlighted with a filled circle in `colorScheme.primary`, matching
/// Google Calendar's month view.
class DayCell extends StatelessWidget {
  const DayCell({
    required this.hebrewDay,
    required this.gregorianDay,
    required this.isInDisplayedMonth,
    required this.isToday,
    this.hasEvents = false,
    this.onTap,
    super.key,
  });

  /// The Hebrew day of month (1-30).
  final int hebrewDay;

  /// The corresponding Gregorian day of month, shown as a secondary hint.
  final int gregorianDay;

  /// Whether this cell belongs to the month being displayed (as opposed to
  /// a leading/trailing day borrowed from an adjacent month).
  final bool isInDisplayedMonth;

  /// Whether this cell is today.
  final bool isToday;

  /// Whether at least one event falls on this day — shown as a small dot
  /// (the cell is too small for Google Calendar-style title chips).
  final bool hasEvents;

  /// Called when the cell is tapped; null (no ink response) when there is
  /// nothing to show for this day.
  final VoidCallback? onTap;

  static const double _dimmedOpacity = 0.38;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final double opacity = isInDisplayedMonth ? 1.0 : _dimmedOpacity;

    final Color hebrewDayColor = isToday
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withValues(alpha: opacity);
    final Color gregorianDayColor = colorScheme.onSurfaceVariant.withValues(
      alpha: opacity,
    );

    return Semantics(
      label: isToday ? '${hebrewDayNumeral(hebrewDay)} — היום' : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacingXs),
          // The grid delegate in `month_grid.dart` derives the cell's
          // aspect ratio from the *available* height so this fits at the
          // default text scale — but `FittedBox` is a safety net on top of
          // that: it guarantees no `RenderFlex` overflow (RULES.md-adjacent
          // real-device requirement) even under a larger system font scale
          // (up to 1.3, per the task brief) or an unusually short cell,
          // by scaling the whole column down to fit instead of clipping.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: rem(2.0),
                  height: rem(2.0),
                  alignment: Alignment.center,
                  // Inner padding keeps scaled-down text off the circle edge.
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: spacingXs / 2,
                  ),
                  decoration: isToday
                      ? BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        )
                      : null,
                  // The container width is fixed (today-circle geometry) but a
                  // gematria numeral can be 1-3 glyphs wide (א׳ vs י״ב); without
                  // this inner FittedBox the Text line-breaks at the fixed width
                  // and the second line is clipped — on device only one letter
                  // of a two-letter numeral was visible.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hebrewDayNumeral(hebrewDay),
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: bodyRem,
                        fontWeight: FontWeight.w600,
                        color: hebrewDayColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacingXs),
                Text(
                  '$gregorianDay',
                  style: TextStyle(
                    fontSize: captionRem,
                    color: gregorianDayColor,
                  ),
                ),
                SizedBox(height: spacingXs),
                SizedBox(
                  width: spacingSm,
                  height: spacingSm,
                  child: hasEvents
                      ? DecoratedBox(
                          key: ValueKey<String>('event-dot-$hebrewDay'),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withValues(
                              alpha: opacity,
                            ),
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
