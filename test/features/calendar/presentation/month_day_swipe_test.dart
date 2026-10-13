// Owner request 2026-10-13: in the month view, swiping the day detail moves
// one day and swiping the grid moves one month, both in the same direction
// (RTL: a swipe to the right is "next").

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_numerals.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_providers.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_providers.dart';
import 'package:hebrew_calendar/main.dart';

import '../../../test_support/fake_auth_repository.dart';
import '../../../test_support/fake_google_calendar_api.dart';
import '../../../test_support/fake_notification_scheduler.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

class _FixedDayNotifier extends CalendarViewNotifier {
  _FixedDayNotifier(this._day);

  final HebrewDate _day;

  @override
  CalendarViewState build() =>
      CalendarViewState(viewType: CalendarViewType.month, focusedDate: _day);
}

Future<ProviderContainer> _pump(WidgetTester tester, HebrewDate day) async {
  final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
  final InMemoryEventRepository repository = InMemoryEventRepository();
  addTearDown(auth.dispose);
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(auth),
        eventRepositoryProvider.overrideWithValue(repository),
        notificationSchedulerProvider.overrideWithValue(
          FakeNotificationScheduler(),
        ),
        googleCalendarApiProvider.overrideWithValue(FakeGoogleCalendarApi()),
        syncSettingsStoreProvider.overrideWithValue(
          InMemorySyncSettingsStore(),
        ),
        calendarViewProvider.overrideWith(() => _FixedDayNotifier(day)),
      ],
      child: const HebrewCalendarApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(PageView)));
}

HebrewDate _focused(ProviderContainer c) =>
    c.read(calendarViewProvider).focusedDate;

String _title(HebrewDate d) =>
    '${_engine.monthName(d.month)} ${hebrewYearNumeral(d.year)}';

final Finder _dayArea = find.byKey(const ValueKey<String>('day-swipe-area'));

/// A point in the day detail below the date header, clear of the
/// day-features row (which scrolls on its own).
Offset _inDayDetail(WidgetTester tester) =>
    tester.getBottomLeft(_dayArea) + const Offset(150, -80);

void main() {
  const HebrewDate day = HebrewDate(
    year: 5787,
    month: HebrewMonth.cheshvan,
    day: 12,
  );

  testWidgets('swiping the day detail right/left moves one day', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await _pump(tester, day);

    await tester.dragFrom(_inDayDetail(tester), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(_focused(c), _engine.addDays(day, 1));
    expect(find.text(_title(day)), findsOneWidget);

    await tester.dragFrom(_inDayDetail(tester), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.dragFrom(_inDayDetail(tester), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(_focused(c), _engine.addDays(day, -1));
  });

  testWidgets('a short drag does not move the day', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await _pump(tester, day);
    await tester.timedDragFrom(
      _inDayDetail(tester),
      const Offset(20, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(_focused(c), day);
  });

  testWidgets('past the last day the month page follows', (
    WidgetTester tester,
  ) async {
    const HebrewDate last = HebrewDate(
      year: 5787,
      month: HebrewMonth.tishrei,
      day: 30,
    );
    final ProviderContainer c = await _pump(tester, last);
    expect(find.text(_title(last)), findsOneWidget);

    await tester.dragFrom(_inDayDetail(tester), const Offset(300, 0));
    await tester.pumpAndSettle();
    final HebrewDate next = _engine.addDays(last, 1);
    expect(next.month, HebrewMonth.cheshvan);
    expect(_focused(c), next);
    expect(find.text(_title(next)), findsOneWidget);
  });

  testWidgets('swiping the grid right still moves to the next month', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await _pump(tester, day);
    final Offset grid =
        tester.getTopLeft(find.byType(PageView)) + const Offset(150, 120);
    await tester.dragFrom(grid, const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(_focused(c).month, _engine.nextMonth(day).month);
  });
}
