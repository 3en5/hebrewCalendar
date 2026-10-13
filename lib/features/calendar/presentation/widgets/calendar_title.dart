import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/calendar_display_mode_provider.dart';
import '../../application/calendar_view_provider.dart';
import '../../application/hebrew_date_engine_provider.dart';

/// The calendar app bar's title: the focused month and, small below it,
/// the same span in the other calendar. In the Hebrew display "חשוון
/// תשפ״ז" over "אוקטובר–נובמבר 2026"; in the Gregorian display (M23) the
/// other way round. Tapping it switches between the two displays (owner
/// request 2026-10-13); the focused day stays selected.
class CalendarTitle extends ConsumerWidget {
  const CalendarTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CalendarViewState state = ref.watch(calendarViewProvider);
    final CalendarDisplayMode mode = ref.watch(calendarDisplayModeProvider);
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    if (state.viewType == CalendarViewType.agenda) {
      return Text(l10n.calendarViewAgenda);
    }
    final bool gregorian = mode == CalendarDisplayMode.gregorian;
    final HebrewDate focused = state.focusedDate;
    final String title = gregorian
        ? _gregorianMonth(engine.toGregorian(focused))
        : '${engine.monthName(focused.month)} ${hebrewYearNumeral(focused.year)}';
    final String subtitle = gregorian
        ? _hebrewSpanOfGregorianMonth(engine, engine.toGregorian(focused))
        : _gregorianSpanOfHebrewMonth(engine, focused);
    final ThemeData theme = Theme.of(context);

    return PopupMenuButton<CalendarDisplayMode>(
      key: const ValueKey<String>('calendar-title'),
      tooltip: l10n.calendarDisplayTooltip,
      position: PopupMenuPosition.under,
      initialValue: mode,
      onSelected: (CalendarDisplayMode m) =>
          ref.read(calendarDisplayModeProvider.notifier).set(m),
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<CalendarDisplayMode>>[
            for (final CalendarDisplayMode m in CalendarDisplayMode.values)
              CheckedPopupMenuItem<CalendarDisplayMode>(
                value: m,
                checked: m == mode,
                child: Text(
                  m == CalendarDisplayMode.hebrew
                      ? l10n.calendarDisplayHebrew
                      : l10n.calendarDisplayGregorian,
                ),
              ),
          ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Scaled down, never cut or overflowing: "ספטמבר 2026" is wider
          // than "תשרי תשפ״ז", and the app bar is narrow at a large text
          // scale.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: theme.appBarTheme.titleTextStyle),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: captionRem,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Icon(
            Icons.expand_more,
            size: rem(1.1),
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

String _gregorianMonth(DateTime d) =>
    '${DateFormat.MMMM('he').format(d)} ${d.year}';

/// "יוני 2026", "יוני–יולי 2026", "דצמבר 2026–ינואר 2027".
String _gregorianSpanOfHebrewMonth(HebrewDateEngine engine, HebrewDate h) {
  final DateTime first = engine.toGregorian(
    HebrewDate(year: h.year, month: h.month, day: 1),
  );
  final DateTime last = engine.toGregorian(
    HebrewDate(
      year: h.year,
      month: h.month,
      day: engine.daysInMonth(h.year, h.month),
    ),
  );
  final DateFormat month = DateFormat.MMMM('he');
  if (first.year != last.year) {
    return '${_gregorianMonth(first)}–${_gregorianMonth(last)}';
  }
  return first.month == last.month
      ? _gregorianMonth(first)
      : '${month.format(first)}–${month.format(last)} ${first.year}';
}

/// "תשרי–חשוון תשפ״ז", "אלול תשפ״ו–תשרי תשפ״ז".
String _hebrewSpanOfGregorianMonth(HebrewDateEngine engine, DateTime g) {
  final HebrewDate first = engine.fromGregorian(DateTime(g.year, g.month, 1));
  final HebrewDate last = engine.fromGregorian(
    DateTime(g.year, g.month + 1, 0),
  );
  String name(HebrewDate d) => engine.monthName(d.month);
  if (first.year != last.year) {
    return '${name(first)} ${hebrewYearNumeral(first.year)}–'
        '${name(last)} ${hebrewYearNumeral(last.year)}';
  }
  return first.month == last.month
      ? '${name(first)} ${hebrewYearNumeral(first.year)}'
      : '${name(first)}–${name(last)} ${hebrewYearNumeral(first.year)}';
}
