import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../application/hebrew_date_engine_provider.dart';
import 'weekday_names.dart';

/// How much detail [CalendarDayHeader] shows.
enum CalendarDayHeaderMode {
  /// Weekday name + gematria day (highlighted circle for today) + a small
  /// Gregorian day number — one per day-of-week column in the week view.
  compact,

  /// A single line with the full Hebrew date ("יום ראשון, י׳ בתשרי תשפ״ו")
  /// — the day view's header.
  full,
}

/// Shared day header for the week and day views (M3b task brief §3 —
/// "extract shared widgets... so week/day reuse them"): weekday name +
/// gematria day number, in either a [CalendarDayHeaderMode.compact] form
/// (week view, one per column) or a [CalendarDayHeaderMode.full] one (day
/// view, a single header for the whole screen).
class CalendarDayHeader extends ConsumerWidget {
  const CalendarDayHeader({
    required this.date,
    required this.isToday,
    this.mode = CalendarDayHeaderMode.compact,
    this.onTap,
    this.showGregorian = false,
    super.key,
  });

  final HebrewDate date;
  final bool isToday;
  final CalendarDayHeaderMode mode;
  final VoidCallback? onTap;

  /// [CalendarDayHeaderMode.full] only: adds the Gregorian date in
  /// parentheses, dd/MM/yy (device request 2026-10-13, agenda view).
  final bool showGregorian;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String weekdayName = hebrewWeekdayNames[engine.weekdayIndex(date)];

    if (mode == CalendarDayHeaderMode.full) {
      final String label =
          '$weekdayName, ${hebrewDayNumeral(date.day)} '
          '${engine.monthName(date.month)} ${hebrewYearNumeral(date.year)}';
      return Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm,
        ),
        child: Text.rich(
          TextSpan(
            text: label,
            children: <InlineSpan>[
              if (showGregorian)
                TextSpan(
                  text:
                      ' (${DateFormat('dd/MM/yy').format(engine.toGregorian(date))})',
                  // 15% smaller than the Hebrew date (device request
                  // 2026-10-13).
                  style: TextStyle(
                    fontSize:
                        (Theme.of(context).textTheme.titleMedium?.fontSize ??
                            bodyRem) *
                        0.85,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isToday ? colorScheme.primary : null,
          ),
        ),
      );
    }

    final int gregorianDay = engine.toGregorian(date).day;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: spacingXs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              weekdayName,
              style: TextStyle(
                fontSize: captionRem,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacingXs),
            Container(
              width: rem(1.75),
              height: rem(1.75),
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                hebrewDayNumeral(date.day),
                style: TextStyle(
                  fontSize: bodyRem,
                  fontWeight: FontWeight.w600,
                  color: isToday
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(height: spacingXs),
            Text(
              '$gregorianDay',
              style: TextStyle(
                fontSize: captionRem,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
