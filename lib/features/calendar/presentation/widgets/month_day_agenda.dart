import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/theme/event_colors.dart';
import '../../../../domain/event/event.dart';
import '../../../../domain/event/event_occurrence.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../../domain/hebrew_date/jewish_day_info.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/calendar_display_mode_provider.dart';
import '../../application/hebrew_date_engine_provider.dart';
import '../../../zmanim/presentation/day_features_carousel.dart';
import 'day_events_sheet.dart';
import 'weekday_names.dart';

/// The selected day's events under the month grid (owner-approved design):
/// a one-line date header, then exactly one compact row per event (time +
/// title). Tapping a row opens [DayEventsSheet] for that event, which holds
/// the edit/delete actions.
class MonthDayAgenda extends ConsumerWidget {
  const MonthDayAgenda({
    required this.date,
    required this.occurrences,
    this.labels = const <JewishDayLabel>[],
    super.key,
  });

  final HebrewDate date;

  /// The day's holidays/parsha (M8), shown with the times of day in the
  /// swipeable row under the date header ([DayFeaturesCarousel]).
  final List<JewishDayLabel> labels;

  /// The occurrences on [date], already in chronological order.
  final List<EventOccurrence> occurrences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    final String weekday = hebrewWeekdayNames[engine.weekdayIndex(date)];
    final DateTime civil = engine.toGregorian(date);
    final String hebrewDay = l10n.monthAgendaDayHeader(
      weekday,
      hebrewDayNumeral(date.day),
      engine.monthName(date.month),
    );
    // M23: the Gregorian display swaps the bold and the secondary date.
    final bool gregorianFirst =
        ref.watch(calendarDisplayModeProvider) == CalendarDisplayMode.gregorian;
    final String hebrewLabel = gregorianFirst
        ? 'יום $weekday, ${DateFormat.MMMMd('he').format(civil)}'
        : hebrewDay;
    final String gregorianLabel = gregorianFirst
        ? '${hebrewDayNumeral(date.day)} ${engine.monthName(date.month)}'
        : DateFormat.yMMMMd('he').format(civil);

    // KALFAPP style (ARCHITECTURE.md §13): the agenda sits in a light-blue
    // rounded card, like PowerWatch's summary card.
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(
        spacingSm,
        spacingSm,
        spacingSm,
        0,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.vertical(top: Radius.circular(spacingMd)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              spacingMd,
              spacingMd,
              spacingMd,
              spacingXs,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    hebrewLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  gregorianLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              spacingXs,
              0,
              spacingXs,
              spacingXs,
            ),
            child: DayFeaturesCarousel(
              day: engine.toGregorian(date),
              labels: labels,
            ),
          ),
          Expanded(
            child: occurrences.isEmpty
                ? Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: spacingMd,
                      vertical: spacingSm,
                    ),
                    child: Text(
                      l10n.monthAgendaEmpty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    // Bottom padding keeps the last row clear of the FAB.
                    padding: EdgeInsetsDirectional.only(bottom: spacingXxl * 2),
                    itemCount: occurrences.length,
                    itemBuilder: (BuildContext context, int index) =>
                        _AgendaRow(occurrence: occurrences[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.occurrence});

  final EventOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Event event = occurrence.event;
    final String timeLabel = event.allDay
        ? AppLocalizations.of(context).eventAllDayLabel
        : (event.startTime?.toString() ?? '');

    return InkWell(
      onTap: () => unawaited(
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => DayEventsSheet(
            date: occurrence.occurrenceDate,
            occurrences: <EventOccurrence>[occurrence],
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: spacingXs,
              height: rem(1.125),
              decoration: BoxDecoration(
                color: eventColor(event.colorId, theme.colorScheme),
                borderRadius: BorderRadius.circular(spacingXs / 2),
              ),
            ),
            SizedBox(width: spacingSm),
            SizedBox(
              width: rem(3.5),
              child: Text(
                timeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
