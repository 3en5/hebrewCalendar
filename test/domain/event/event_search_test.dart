// M13: word search over events.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_search.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';

const HebrewDateEngine _engine = HebrewDateEngine();
const HebrewDate _today = HebrewDate(
  year: 5787,
  month: HebrewMonth.cheshvan,
  day: 10,
);

Event _event(
  String id,
  String title,
  HebrewDate date, {
  String description = '',
  String location = '',
  RecurrenceRule recurrence = const RecurrenceRule(),
}) => Event(
  id: id,
  ownerUid: 'u',
  calendarId: 'default',
  title: title,
  description: description,
  location: location,
  hebrewDate: date,
  recurrence: recurrence,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

List<String> _ids(List<EventSearchHit> hits) =>
    hits.map((EventSearchHit h) => h.event.id).toList();

void main() {
  final List<Event> events = <Event>[
    _event(
      'past',
      'פגישה עם רו״ח',
      const HebrewDate(year: 5787, month: HebrewMonth.tishrei, day: 3),
    ),
    _event(
      'soon',
      'פגישה עם הבנק',
      const HebrewDate(year: 5787, month: HebrewMonth.cheshvan, day: 12),
    ),
    _event(
      'later',
      'רופא',
      const HebrewDate(year: 5787, month: HebrewMonth.kislev, day: 1),
      location: 'קופת חולים, פגישה',
    ),
    _event(
      'other',
      'יום הולדת',
      const HebrewDate(year: 5787, month: HebrewMonth.kislev, day: 5),
    ),
  ];

  test('finds a word in title, description or location; upcoming first', () {
    final List<EventSearchHit> hits = searchEvents(
      events: events,
      query: 'פגישה',
      today: _today,
      engine: _engine,
    );
    expect(_ids(hits), <String>['soon', 'later', 'past']);
  });

  test('every word must match', () {
    expect(
      _ids(
        searchEvents(
          events: events,
          query: 'פגישה בנק',
          today: _today,
          engine: _engine,
        ),
      ),
      <String>['soon'],
    );
  });

  test('an empty query finds nothing', () {
    expect(
      searchEvents(events: events, query: '  ', today: _today, engine: _engine),
      isEmpty,
    );
  });

  test('a recurring event jumps to its next occurrence', () {
    final Event yearly = _event(
      'birthday',
      'יום הולדת לאבא',
      const HebrewDate(year: 5780, month: HebrewMonth.cheshvan, day: 23),
      recurrence: const RecurrenceRule(type: RecurrenceType.hebrewYearly),
    );
    final EventSearchHit hit = searchEvents(
      events: <Event>[yearly],
      query: 'אבא',
      today: _today,
      engine: _engine,
    ).single;
    expect(
      hit.date,
      const HebrewDate(year: 5787, month: HebrewMonth.cheshvan, day: 23),
    );
  });
}
