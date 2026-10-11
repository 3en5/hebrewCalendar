import '../hebrew_date/hebrew_date.dart';
import '../hebrew_date/hebrew_date_engine.dart';
import 'event.dart';
import 'recurrence_expander.dart';
import 'recurrence_rule.dart';

/// One search result (M13): the event and the Hebrew date to jump to.
class EventSearchHit {
  const EventSearchHit({required this.event, required this.date});

  final Event event;

  /// For a recurring event, its next occurrence from today (or its anchor
  /// when none falls in the next two years); otherwise its own date.
  final HebrewDate date;
}

/// Events whose title, description or location contain every word of
/// [query] (case-insensitive). Upcoming events come first (soonest first),
/// then past ones (most recent first). At most [limit] hits.
List<EventSearchHit> searchEvents({
  required List<Event> events,
  required String query,
  required HebrewDate today,
  required HebrewDateEngine engine,
  int limit = 200,
}) {
  final List<String> words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return const <EventSearchHit>[];
  }
  final List<EventSearchHit> upcoming = <EventSearchHit>[];
  final List<EventSearchHit> past = <EventSearchHit>[];
  for (final Event event in events) {
    final String haystack =
        '${event.title}\n${event.description}\n${event.location}'.toLowerCase();
    if (!words.every(haystack.contains)) {
      continue;
    }
    final EventSearchHit hit = EventSearchHit(
      event: event,
      date: _dateToShow(event, today, engine),
    );
    (hit.date >= today ? upcoming : past).add(hit);
  }
  upcoming.sort(
    (EventSearchHit a, EventSearchHit b) => a.date.compareTo(b.date),
  );
  past.sort((EventSearchHit a, EventSearchHit b) => b.date.compareTo(a.date));
  return <EventSearchHit>[...upcoming, ...past].take(limit).toList();
}

HebrewDate _dateToShow(Event event, HebrewDate today, HebrewDateEngine engine) {
  if (event.recurrence.type == RecurrenceType.none ||
      event.hebrewDate >= today) {
    return event.hebrewDate;
  }
  final occurrences = occurrencesForEventInRange(
    event: event,
    from: today,
    to: engine.addDays(today, 730),
    engine: engine,
  );
  return occurrences.isEmpty
      ? event.hebrewDate
      : occurrences.first.occurrenceDate;
}
