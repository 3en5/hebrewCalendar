// Today's next event in the month view's day agenda is marked like a
// highlighter (owner requests 2026-10-18): the first timed event that has
// not started yet, only on today, never an all-day event; its time and
// title share one marker, it is scrolled to the middle of a long list, and
// the events that are over are drawn faint.

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

final Finder _marker = find.byKey(const ValueKey<String>('agenda-next-event'));

/// The texts inside the marker (time, then title), or null without one.
List<String?>? _marked(WidgetTester tester) {
  if (_marker.evaluate().isEmpty) {
    return null;
  }
  return tester
      .widgetList<Text>(
        find.descendant(of: _marker, matching: find.byType(Text)),
      )
      .map((Text t) => t.data)
      .toList();
}

/// Whether the row titled [title] is drawn faint.
bool _faint(WidgetTester tester, String title) => find
    .ancestor(of: find.text(title), matching: find.byType(Opacity))
    .evaluate()
    .isNotEmpty;

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

  test('isEventOver once the end has passed', () {
    final Event morning = _occ(today, 'morning', 8).event; // 08:00-08:30
    expect(isEventOver(morning, 8 * 60 + 10), isFalse); // still on
    expect(isEventOver(morning, 8 * 60 + 30), isTrue);
    expect(isEventOver(_occ(today, 'all day', null).event, 23 * 60), isFalse);
  });

  testWidgets('events that are over are faint, the rest are not', (
    WidgetTester tester,
  ) async {
    await _pump(tester, today, <EventOccurrence>[
      _occ(today, 'ציפורניים', 8),
      _occ(today, 'כל היום', null),
      _occ(today, 'כדורגל', 17),
    ], now);
    expect(_faint(tester, 'ציפורניים'), isTrue);
    expect(_faint(tester, 'כל היום'), isFalse);
    expect(_faint(tester, 'כדורגל'), isFalse);
  });

  testWidgets('a long day opens with the next event in the middle', (
    WidgetTester tester,
  ) async {
    final List<EventOccurrence> many = <EventOccurrence>[
      for (int h = 0; h < 24; h++) _occ(today, 'אירוע $h', h),
    ];
    await _pump(tester, today, many, now);
    await tester.pumpAndSettle();
    expect(_marked(tester), <String>['17:00', 'אירוע 17']);
    final Rect list = tester.getRect(
      find.byWidgetPredicate(
        (Widget w) => w is ListView && w.scrollDirection == Axis.vertical,
      ),
    );
    final double centre = tester.getCenter(_marker).dy;
    expect((centre - list.center.dy).abs(), lessThan(list.height * 0.15));
  });

  testWidgets('marks today\'s next event', (WidgetTester tester) async {
    await _pump(tester, today, <EventOccurrence>[
      _occ(today, 'ציפורניים', 8),
      _occ(today, 'כדורגל', 17),
      _occ(today, 'תרופות', 20),
    ], now);
    expect(_marked(tester), <String>['17:00', 'כדורגל']);
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
