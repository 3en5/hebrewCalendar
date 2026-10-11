import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../domain/hebrew_date/jewish_day_info.dart';

/// Maximum number of event dots drawn under the day numeral; a busier day
/// still shows this many (the full list is in the agenda below the grid).
const int _maxDots = 3;

/// A single day cell in the month grid (owner-approved "variant B" design):
/// thin grid lines, the Hebrew day in gematria centered, the Gregorian day
/// small in the top-end corner, the day's main holiday/parsha [label] (M8)
/// in small text, and one dot per event underneath. Today is
/// a filled `primary` circle; the selected day gets a tinted background
/// (and a ring, when it isn't also today). Shabbat cells are lightly tinted.
class DayCell extends StatelessWidget {
  const DayCell({
    required this.hebrewDay,
    required this.gregorianDay,
    required this.isToday,
    required this.isSelected,
    required this.isShabbat,
    required this.drawEndLine,
    this.eventCount = 0,
    this.label,
    this.onTap,
    super.key,
  });

  /// The Hebrew day of month (1-30).
  final int hebrewDay;

  /// The corresponding Gregorian day of month, shown as a secondary hint.
  final int gregorianDay;

  final bool isToday;

  /// Whether this is the day whose events the agenda below the grid shows.
  final bool isSelected;

  /// Whether this cell is in the Shabbat (last) column.
  final bool isShabbat;

  /// Whether to draw the vertical grid line on the cell's end side (every
  /// column but the last).
  final bool drawEndLine;

  /// Number of events on this day; drawn as up to [_maxDots] dots.
  final int eventCount;

  /// The day's most important holiday/parsha label, if any.
  final JewishDayLabel? label;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final Color background = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.55)
        : isShabbat
        ? colorScheme.primary.withValues(alpha: 0.05)
        : Colors.transparent;

    return Semantics(
      label: isToday ? '${hebrewDayNumeral(hebrewDay)} — היום' : null,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            border: monthGridLineBorder(context, drawEndLine: drawEndLine),
          ),
          child: Stack(
            children: <Widget>[
              PositionedDirectional(
                top: spacingXs / 2,
                end: spacingXs,
                child: Text(
                  '$gregorianDay',
                  style: TextStyle(
                    fontSize: rem(0.5625),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) =>
                    Center(
                      // Safety net for large system font scales / short
                      // rows: scale the content down instead of overflowing.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _DayNumeral(
                              hebrewDay: hebrewDay,
                              isToday: isToday,
                              isSelected: isSelected,
                            ),
                            if (label != null)
                              // Fixed to the cell's width so a long name
                              // ellipsizes instead of shrinking the numeral.
                              SizedBox(
                                width: constraints.maxWidth - spacingXs,
                                child: _DayLabel(label: label!),
                              ),
                            SizedBox(height: spacingXs / 2),
                            _EventDots(hebrewDay: hebrewDay, count: eventCount),
                          ],
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The thin bottom (and, except in the last column, end-side) grid line
/// shared by every month-grid cell, including the empty out-of-month ones.
BorderDirectional monthGridLineBorder(
  BuildContext context, {
  required bool drawEndLine,
}) {
  final BorderSide line = BorderSide(
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
    width: 0.5,
  );
  return BorderDirectional(
    bottom: line,
    end: drawEndLine ? line : BorderSide.none,
  );
}

class _DayNumeral extends StatelessWidget {
  const _DayNumeral({
    required this.hebrewDay,
    required this.isToday,
    required this.isSelected,
  });

  final int hebrewDay;
  final bool isToday;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color textColor = isToday
        ? colorScheme.onPrimary
        : isSelected
        ? colorScheme.primary
        : colorScheme.onSurface;

    return Container(
      width: rem(1.75),
      height: rem(1.75),
      alignment: Alignment.center,
      // Inner padding keeps scaled-down text off the circle edge.
      padding: EdgeInsetsDirectional.symmetric(horizontal: spacingXs / 2),
      decoration: isToday
          ? BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle)
          : isSelected
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.primary, width: 1.5),
            )
          : null,
      // A gematria numeral can be 1-3 glyphs wide (א׳ vs י״ב); without this
      // FittedBox the Text line-breaks at the fixed circle width and the
      // second line is clipped.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          hebrewDayNumeral(hebrewDay),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: bodyRem,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.label});

  final JewishDayLabel label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Text(
      label.shortName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: rem(0.5625),
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: jewishDayLabelColor(colorScheme, label.kind),
      ),
    );
  }
}

/// Text color for a holiday/parsha label, shared by the month cell and the
/// day agenda's tags: the parsha in the primary color, fasts and memorial
/// days in a muted tone, everything else in the tertiary (holiday) color.
Color jewishDayLabelColor(ColorScheme colorScheme, JewishDayKind kind) {
  switch (kind) {
    case JewishDayKind.parsha:
      return colorScheme.primary;
    case JewishDayKind.fast:
    case JewishDayKind.national:
      return colorScheme.onSurfaceVariant;
    case JewishDayKind.holiday:
    case JewishDayKind.minor:
    case JewishDayKind.roshChodesh:
      return colorScheme.tertiary;
  }
}

class _EventDots extends StatelessWidget {
  const _EventDots({required this.hebrewDay, required this.count});

  final int hebrewDay;
  final int count;

  @override
  Widget build(BuildContext context) {
    final double dot = spacingXs * 1.25;
    if (count == 0) {
      return SizedBox(height: dot);
    }
    final Color color = Theme.of(context).colorScheme.primary;
    return Row(
      key: ValueKey<String>('event-dot-$hebrewDay'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < count.clamp(0, _maxDots); i++)
          Container(
            width: dot,
            height: dot,
            margin: EdgeInsetsDirectional.symmetric(horizontal: dot / 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
      ],
    );
  }
}
