import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../domain/hebrew_date/jewish_day_info.dart';
import '../../../settings/application/text_size_provider.dart';
import '../../../zmanim/presentation/shabbat_times.dart';

/// Maximum number of event dots drawn under the day numeral; a busier day
/// still shows this many (the full list is in the agenda below the grid).
const int _maxDots = 3;

/// Hebrew letters stand lower than digits at the same font size (in Rubik,
/// measured 2026-10-16: 25 px against 29 px), so a day's letters looked
/// smaller than the Gregorian numbers (owner report): they are drawn this
/// much larger to match.
const double hebrewNumeralBoost = 1.16;

/// The day numeral's circle (today, selected day), in rem: wide enough that
/// a two-letter numeral like ט״ו keeps its full size inside it.
const double _numeralCircleRem = 2.0;

/// Where the day's numeral and the event dots sit, as shares of the
/// cell's height: the space above the numeral and below the dots (owner
/// tuning 2026-10-15: the first version had them too close to the edges).
const double _numeralTopShare = 0.12;
const double _dotsBottomShare = 0.10;

/// The least space above the numeral, clear of the small corner number.
double get _cellTopPad => spacingXs * 1.5;

/// A single day cell in the month grid (owner-approved "variant B" design):
/// thin grid lines, the Hebrew day in gematria centered, the Gregorian day
/// small in the top-end corner, the day's main holiday/parsha [label] (M8)
/// in small text, Friday's candle lighting or Saturday's end of Shabbat
/// (M21), and one dot per event underneath. Today is
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
    this.gregorianPrimary = false,
    this.eventColors = const <Color>[],
    this.label,
    this.shabbatTime,
    this.onTap,
    this.onPressStart,
    this.onPressEnd,
    this.onPressCancel,
    super.key,
  });

  /// The Hebrew day of month (1-30).
  final int hebrewDay;

  /// The corresponding Gregorian day of month, shown as a secondary hint.
  final int gregorianDay;

  /// The Gregorian display (M23): the Gregorian day is the big numeral and
  /// the Hebrew day the small corner hint.
  final bool gregorianPrimary;

  final bool isToday;

  /// Whether this is the day whose events the agenda below the grid shows.
  final bool isSelected;

  /// Whether this cell is in the Shabbat (last) column.
  final bool isShabbat;

  /// Whether to draw the vertical grid line on the cell's end side (every
  /// column but the last).
  final bool drawEndLine;

  /// One color per event on this day (M10); drawn as up to [_maxDots] dots.
  final List<Color> eventColors;

  /// The day's most important holiday/parsha label, if any.
  final JewishDayLabel? label;

  /// Friday's candle lighting or Saturday's end of Shabbat (M21).
  final ShabbatTime? shabbatTime;

  final VoidCallback? onTap;

  /// A finger touched the cell, lifted from it, or turned the touch into a
  /// drag (the month view's pop, [DayPopStack]).
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final VoidCallback? onPressCancel;

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
        onTapDown: onPressStart == null ? null : (_) => onPressStart!(),
        onTapUp: onPressEnd == null ? null : (_) => onPressEnd!(),
        onTapCancel: onPressCancel,
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
                  gregorianPrimary
                      ? hebrewDayNumeral(hebrewDay)
                      : '$gregorianDay',
                  style: TextStyle(
                    fontSize:
                        rem(0.5625) *
                        (gregorianPrimary ? hebrewNumeralBoost : 1),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget numeral = _DayNumeral(
                    hebrew: !gregorianPrimary,
                    text: gregorianPrimary
                        ? '$gregorianDay'
                        : hebrewDayNumeral(hebrewDay),
                    isToday: isToday,
                    isSelected: isSelected,
                  );
                  final Widget dots = _EventDots(
                    hebrewDay: hebrewDay,
                    colors: eventColors,
                  );
                  final Widget middle = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (label != null)
                        // Fixed to the cell's width so a long name shrinks
                        // instead of widening the cell.
                        SizedBox(
                          width: constraints.maxWidth - spacingXs,
                          child: _DayLabel(label: label!),
                        ),
                      if (shabbatTime != null)
                        ShabbatTimeLine(shabbatTime: shabbatTime!),
                    ],
                  );
                  final double numeralHeight =
                      rem(_numeralCircleRem) * textGrowth(context, bodyRem);
                  final double fixedPart =
                      _cellTopPad + numeralHeight + spacingXs * 2.5;
                  if (constraints.maxHeight < fixedPart + spacingXs) {
                    // A very short row: everything centered and scaled down
                    // together, as a safety net.
                    return Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[numeral, middle, dots],
                        ),
                      ),
                    );
                  }
                  // Owner request 2026-10-15: the day's letters always at
                  // the same height and the dots always at the bottom, so a
                  // row reads level however much text a day has; the label
                  // and Shabbat time take the space between, shrunk to fit.
                  final double top = (constraints.maxHeight * _numeralTopShare)
                      .clamp(_cellTopPad, double.infinity);
                  final double bottom =
                      (constraints.maxHeight * _dotsBottomShare).clamp(
                        spacingXs / 2,
                        double.infinity,
                      );
                  if (constraints.maxHeight <
                      top + bottom + numeralHeight + spacingXs * 3) {
                    return Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[numeral, middle, dots],
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: top, bottom: bottom),
                    child: Column(
                      children: <Widget>[
                        numeral,
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: middle,
                            ),
                          ),
                        ),
                        dots,
                      ],
                    ),
                  );
                },
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
    required this.text,
    required this.isToday,
    required this.isSelected,
    required this.hebrew,
  });

  final String text;

  /// Whether [text] is a Hebrew numeral (rather than digits).
  final bool hebrew;
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

    // The circle grows with the text size, so the numeral grows with it.
    final double circle = rem(_numeralCircleRem) * textGrowth(context, bodyRem);
    return Container(
      width: circle,
      height: circle,
      alignment: Alignment.center,
      // Inner padding keeps scaled-down text off the circle edge.
      padding: EdgeInsetsDirectional.symmetric(horizontal: spacingXs / 4),
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
          text,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: bodyRem * (hebrew ? hebrewNumeralBoost : 1),
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
    // Shrinks to the cell's width rather than cutting the name (owner
    // sketch 2026-10-15: at a large text size "חול המועד" was cut).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label.shortName,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: rem(0.5625),
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: jewishDayLabelColor(colorScheme, label.kind),
        ),
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
  const _EventDots({required this.hebrewDay, required this.colors});

  final int hebrewDay;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final double dot = spacingXs * 1.25;
    if (colors.isEmpty) {
      return SizedBox(height: dot);
    }
    return Row(
      key: ValueKey<String>('event-dot-$hebrewDay'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final Color color in colors.take(_maxDots))
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
