// Today's next event in the month view's day agenda is marked like a
// highlighter (owner request 2026-10-18): the first timed event that has
// not started yet, only on today, never an all-day event.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_occurrence.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/month_day_agenda.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

EventOccurrence _occ(HebrewDate date, String title, int? hour) {
  final DateTime t = DateTime(2026, 1, 1);
  return EventOccurrence(
    occurrenceDate: date,
    event: Event(
      id: title,
      ownerUid: 'uid-1',
      calendarId: 'default',
      title: title,
      hebrewDate: date,
      allDay: hour == null,
      startTime: hour == null ? null : EventTimeOfDay(hour: hour, minute: 0),
      endTime: hour == null ? null : EventTimeOfDay(hour: hour, minute: 30),
      createdAt: t,
      updatedAt: t,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  HebrewDate date,
  List<EventOccurrence> occurrences,
  DateTime now,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('he'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: MonthDayAgenda(date: date, occurrences: occurrences, now: now),
        ),
      ),
    ),
  );
  await tester.pump();
}

String? _marked(WidgetTester tester) {
  final Finder marker = find.byKey(const ValueKey<String>('agenda-next-event'));
  if (marker.evaluate().isEmpty) {
    return null;
  }
  return tester
      .widget<Text>(find.descendant(of: marker, matching: find.byType(Text)))
      .data;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  final DateTime now = DateTime(2026, 10, 18, 16, 18);
  final HebrewDate today = _engine.fromGregorian(now);

  test('nextEventIndex picks the first timed event not started yet', () {
    final List<EventOccurrence> list = <EventOccurrence>[
      _occ(today, 'all day', null),
      _occ(today, 'morning', 8),
      _occ(today, 'evening', 17),
      _occ(today, 'night', 20),
    ];
    expect(nextEventIndex(list, 16 * 60 + 18), 2);
    expect(nextEventIndex(list, 17 * 60), 2);
    expect(nextEventIndex(list, 17 * 60 + 1), 3);
    expect(nextEventIndex(list, 21 * 60), isNull);
  });

  testWidgets('marks today\'s next event', (WidgetTester tester) async {
    await _pump(tester, today, <EventOccurrence>[
      _occ(today, 'ציפורניים', 8),
      _occ(today, 'כדורגל', 17),
      _occ(today, 'תרופות', 20),
    ], now);
    expect(_marked(tester), 'כדורגל');
  });

  testWidgets('no mark on another day', (WidgetTester tester) async {
    final HebrewDate tomorrow = _engine.addDays(today, 1);
    await _pump(tester, tomorrow, <EventOccurrence>[
      _occ(tomorrow, 'כדורגל', 17),
    ], now);
    expect(_marked(tester), isNull);
  });

  testWidgets('no mark once every event has started', (
    WidgetTester tester,
  ) async {
    await _pump(tester, today, <EventOccurrence>[
      _occ(today, 'ציפורניים', 8),
      _occ(today, 'כל היום', null),
    ], now);
    expect(_marked(tester), isNull);
  });
}
