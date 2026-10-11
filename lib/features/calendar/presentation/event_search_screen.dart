import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/dimens.dart';
import '../../../core/theme/event_colors.dart';
import '../../../domain/event/event.dart';
import '../../../domain/event/event_search.dart';
import '../../../domain/event/recurrence_rule.dart';
import '../../../domain/hebrew_date/hebrew_date.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../l10n/app_localizations.dart';
import '../../event_editor/application/event_repository_provider.dart';
import '../application/calendar_view_provider.dart';
import '../application/hebrew_date_engine_provider.dart';

/// All events, loaded once per visit to the search screen (M13).
final FutureProvider<List<Event>> _searchableEventsProvider =
    FutureProvider.autoDispose<List<Event>>(
      (Ref ref) => ref.watch(eventRepositoryProvider).getAllForSearch(),
    );

/// Word search over every event's title, description and location (M13).
/// Tapping a result jumps the calendar to that day.
class EventSearchScreen extends ConsumerStatefulWidget {
  const EventSearchScreen({super.key});

  @override
  ConsumerState<EventSearchScreen> createState() => _EventSearchScreenState();
}

class _EventSearchScreenState extends ConsumerState<EventSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final HebrewDateEngine engine = ref.watch(hebrewDateEngineProvider);
    final AsyncValue<List<Event>> events = ref.watch(_searchableEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey<String>('event-search-field'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: (String value) => setState(() => _query = value),
        ),
        actions: <Widget>[
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: events.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            Center(child: Text(error.toString())),
        data: (List<Event> all) {
          if (_query.trim().isEmpty) {
            return const SizedBox.shrink();
          }
          final List<EventSearchHit> hits = searchEvents(
            events: all,
            query: _query,
            today: engine.fromGregorian(DateTime.now()),
            engine: engine,
          );
          if (hits.isEmpty) {
            return Center(child: Text(l10n.searchNoResults));
          }
          return ListView.builder(
            itemCount: hits.length,
            itemBuilder: (BuildContext context, int index) =>
                _SearchHitTile(hit: hits[index], engine: engine),
          );
        },
      ),
    );
  }
}

class _SearchHitTile extends ConsumerWidget {
  const _SearchHitTile({required this.hit, required this.engine});

  final EventSearchHit hit;
  final HebrewDateEngine engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Event event = hit.event;
    final HebrewDate date = hit.date;
    final String hebrew =
        '${hebrewDayNumeral(date.day)} ${engine.monthName(date.month)} '
        '${hebrewYearNumeral(date.year)}';
    final String gregorian = DateFormat.yMMMd(
      'he',
    ).format(engine.toGregorian(date));
    final bool recurring = event.recurrence.type != RecurrenceType.none;
    return ListTile(
      leading: Container(
        width: spacingXs,
        height: rem(2.0),
        decoration: BoxDecoration(
          color: eventColor(event.colorId, theme.colorScheme),
          borderRadius: BorderRadius.circular(spacingXs / 2),
        ),
      ),
      title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        recurring
            ? '$hebrew · $gregorian · ${l10n.searchRecurringNote}'
            : '$hebrew · $gregorian',
      ),
      onTap: () {
        ref.read(calendarViewProvider.notifier).setFocusedDate(date);
        Navigator.of(context).pop();
      },
    );
  }
}
