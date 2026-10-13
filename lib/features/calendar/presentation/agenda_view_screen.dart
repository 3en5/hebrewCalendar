import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/event/event.dart';
import '../../../domain/event/event_occurrence.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../l10n/app_localizations.dart';
import '../../event_editor/presentation/recurring_scope_dialog.dart';
import '../application/calendar_view_provider.dart';
import '../application/hebrew_date_engine_provider.dart';
import '../application/range_events_provider.dart';
import 'widgets/calendar_day_header.dart';

/// The agenda body (M3b): an "infinite-feel" scrolling list of upcoming
/// occurrences starting at the focused date, grouped by Hebrew date with a
/// header per day (a plain grouped `ListView` — task brief M3b §3 explicitly
/// allows this over true sticky headers).
///
/// Loads a rolling window of [_initialWindowMonths] Hebrew months from the
/// focused date, widening by [_windowIncrementMonths] (up to
/// [_maxWindowMonths], a safety cap) as the user scrolls near the bottom —
/// each widening re-subscribes `rangeEventsProvider` with a larger range
/// rather than paginating incrementally, which is simple and correct even
/// though it re-fetches the whole window (acceptable at this scale per the
/// task brief).
class AgendaViewScreen extends ConsumerStatefulWidget {
  const AgendaViewScreen({super.key});

  @override
  ConsumerState<AgendaViewScreen> createState() => _AgendaViewScreenState();
}

class _AgendaViewScreenState extends ConsumerState<AgendaViewScreen> {
  static const int _initialWindowMonths = 3;
  static const int _windowIncrementMonths = 3;
  static const int _maxWindowMonths = 24;
  static const double _extendScrollThreshold = 200;

  late HebrewDate _from;
  int _windowMonths = _initialWindowMonths;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _from = ref.read(calendarViewProvider).focusedDate;
    _scrollController.addListener(_maybeExtendWindow);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeExtendWindow() {
    if (_windowMonths >= _maxWindowMonths || !_scrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _extendScrollThreshold) {
      setState(() => _windowMonths += _windowIncrementMonths);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CalendarViewState>(calendarViewProvider, (
      CalendarViewState? previous,
      CalendarViewState next,
    ) {
      if (next.focusedDate == _from) {
        return;
      }
      setState(() {
        _from = next.focusedDate;
        _windowMonths = _initialWindowMonths;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final HebrewDate to = engine.addMonths(_from, _windowMonths);
    final AsyncValue<List<EventOccurrence>> occurrencesAsync = ref.watch(
      rangeEventsProvider((from: _from, to: to)),
    );

    return occurrencesAsync.when(
      data: (List<EventOccurrence> occurrences) => _AgendaList(
        scrollController: _scrollController,
        occurrences: occurrences,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _AgendaList extends StatelessWidget {
  const _AgendaList({
    required this.scrollController,
    required this.occurrences,
  });

  final ScrollController scrollController;
  final List<EventOccurrence> occurrences;

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).agendaEmptyState));
    }

    final List<EventOccurrence> sorted = <EventOccurrence>[...occurrences]
      ..sort(compareEventOccurrences);
    final Map<HebrewDate, List<EventOccurrence>> groups =
        <HebrewDate, List<EventOccurrence>>{};
    for (final EventOccurrence occurrence in sorted) {
      groups
          .putIfAbsent(occurrence.occurrenceDate, () => <EventOccurrence>[])
          .add(occurrence);
    }
    final List<HebrewDate> dates = groups.keys.toList()..sort();

    return ListView.builder(
      controller: scrollController,
      itemCount: dates.length,
      itemBuilder: (BuildContext context, int index) {
        final HebrewDate date = dates[index];
        return _AgendaDayGroup(date: date, occurrences: groups[date]!);
      },
    );
  }
}

class _AgendaDayGroup extends ConsumerWidget {
  const _AgendaDayGroup({required this.date, required this.occurrences});

  final HebrewDate date;
  final List<EventOccurrence> occurrences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final HebrewDate today = engine.fromGregorian(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CalendarDayHeader(
          date: date,
          isToday: date == today,
          mode: CalendarDayHeaderMode.full,
          showGregorian: true,
        ),
        for (final EventOccurrence occurrence in occurrences)
          _AgendaEventTile(occurrence: occurrence),
      ],
    );
  }
}

class _AgendaEventTile extends StatelessWidget {
  const _AgendaEventTile({required this.occurrence});

  final EventOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Event event = occurrence.event;
    final String timeLabel = event.allDay
        ? l10n.eventAllDayLabel
        : (event.startTime?.toString() ?? '');

    return ListTile(
      leading: SizedBox(
        width: rem(3.0),
        child: Text(timeLabel, style: TextStyle(fontSize: captionRem)),
      ),
      title: Text(event.title),
      trailing: event.location.isEmpty
          ? null
          : const Icon(Icons.location_on_outlined),
      onTap: () => openEventEditorForOccurrence(context, occurrence),
    );
  }
}
