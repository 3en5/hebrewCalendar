import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/theme/event_colors.dart';
import '../../../../domain/event/event.dart';
import '../../../../domain/event/event_occurrence.dart';
import '../../../../domain/event/event_time_of_day.dart';
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
    this.now,
    super.key,
  });

  /// The clock, for tests and screenshots; the real time when null.
  final DateTime? now;

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
                : _AgendaList(
                    date: date,
                    occurrences: occurrences,
                    engine: engine,
                    now: now,
                  ),
          ),
        ],
      ),
    );
  }
}

/// How often the list checks which event is next.
const Duration _nextTick = Duration(seconds: 30);

/// Index in [occurrences] (chronological) of the next timed event at
/// [nowMinutes] minutes after midnight: the first one starting at or after
/// it. Null when every timed event has already started.
int? nextEventIndex(List<EventOccurrence> occurrences, int nowMinutes) {
  for (int i = 0; i < occurrences.length; i++) {
    final EventTimeOfDay? start = occurrences[i].event.startTime;
    if (!occurrences[i].event.allDay &&
        start != null &&
        start.minutesFromMidnight >= nowMinutes) {
      return i;
    }
  }
  return null;
}

/// The marker behind the next event's title: a highlighter yellow, with
/// dark text on it in both themes (owner sketch 2026-10-18: a faint yellow
/// looked muddy in the dark theme).
const Color nextEventMarkerColor = Color(0xFFFFE066);
const Color nextEventMarkerTextColor = Color(0xFF1C1B1F);

/// The rows, with today's next event marked like a highlighter (owner
/// request 2026-10-18); the mark moves on as the time passes.
class _AgendaList extends StatefulWidget {
  const _AgendaList({
    required this.date,
    required this.occurrences,
    required this.engine,
    this.now,
  });

  final HebrewDate date;
  final List<EventOccurrence> occurrences;
  final HebrewDateEngine engine;
  final DateTime? now;

  @override
  State<_AgendaList> createState() => _AgendaListState();
}

class _AgendaListState extends State<_AgendaList> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _timer = Timer.periodic(_nextTick, (_) => setState(() {}));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = widget.now ?? DateTime.now();
    final int? next = widget.engine.fromGregorian(now) == widget.date
        ? nextEventIndex(widget.occurrences, now.hour * 60 + now.minute)
        : null;
    return ListView.builder(
      // Bottom padding keeps the last row clear of the FAB.
      padding: EdgeInsetsDirectional.only(bottom: spacingXxl * 2),
      itemCount: widget.occurrences.length,
      itemBuilder: (BuildContext context, int index) => _AgendaRow(
        occurrence: widget.occurrences[index],
        isNext: index == next,
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.occurrence, this.isNext = false});

  final EventOccurrence occurrence;

  /// Today's next event, drawn with a marker behind its title.
  final bool isNext;

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
              child: isNext
                  ? Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        key: const ValueKey<String>('agenda-next-event'),
                        padding: EdgeInsetsDirectional.symmetric(
                          horizontal: spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: nextEventMarkerColor,
                          borderRadius: BorderRadius.circular(spacingXs / 2),
                        ),
                        child: Semantics(
                          label: AppLocalizations.of(
                            context,
                          ).monthAgendaNextEvent,
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: nextEventMarkerTextColor,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Text(
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
