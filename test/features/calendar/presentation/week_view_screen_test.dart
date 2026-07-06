// Widget test for WeekViewScreen (M3b): a timed event shows as an event
// block positioned under its actual weekday's header column, not some
// other day in the week.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/main.dart';

import '../../../test_support/fake_auth_repository.dart';

const HebrewDateEngine _engine = HebrewDateEngine();
const HebrewDate _anyDayInWeek = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 10,
);

class _FixedWeekNotifier extends CalendarViewNotifier {
  @override
  CalendarViewState build() => const CalendarViewState(
    viewType: CalendarViewType.week,
    focusedDate: _anyDayInWeek,
  );
}

Event _timedEvent(HebrewDate date) {
  final DateTime now = DateTime(2026, 1, 1);
  return Event(
    id: 'ignored-on-create',
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: 'פגישה',
    hebrewDate: date,
    allDay: false,
    startTime: const EventTimeOfDay(hour: 10, minute: 0),
    endTime: const EventTimeOfDay(hour: 11, minute: 0),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('shows an event block aligned under the correct weekday', (
    WidgetTester tester,
  ) async {
    final HebrewDate weekStart = _engine.startOfWeek(_anyDayInWeek);
    final HebrewDate tuesday = _engine.addDays(weekStart, 2);

    final InMemoryEventRepository repository = InMemoryEventRepository();
    final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
    addTearDown(repository.dispose);
    addTearDown(auth.dispose);
    await repository.create(_timedEvent(tuesday));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(auth),
          eventRepositoryProvider.overrideWithValue(repository),
          calendarViewProvider.overrideWith(_FixedWeekNotifier.new),
        ],
        child: const HebrewCalendarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('פגישה'), findsOneWidget);
    final double eventCenterX = tester.getCenter(find.text('פגישה')).dx;

    double? nearestDistance;
    HebrewDate? nearestDay;
    for (int i = 0; i < 7; i++) {
      final HebrewDate day = _engine.addDays(weekStart, i);
      final Finder headerFinder = find.byKey(
        ValueKey<String>('week-day-header-$day'),
      );
      final double headerCenterX = tester.getCenter(headerFinder).dx;
      final double distance = (headerCenterX - eventCenterX).abs();
      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        nearestDay = day;
      }
    }

    expect(nearestDay, tuesday);
  });
}
