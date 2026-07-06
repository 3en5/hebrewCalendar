// Widget tests for CalendarShellScreen (M3b): the view switcher cycles
// through all four bodies, and the "today" button refocuses without
// changing which view is shown.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_numerals.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/calendar/presentation/agenda_view_screen.dart';
import 'package:hebrew_calendar/features/calendar/presentation/day_view_screen.dart';
import 'package:hebrew_calendar/features/calendar/presentation/month_view_body.dart';
import 'package:hebrew_calendar/features/calendar/presentation/week_view_screen.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_providers.dart';
import 'package:hebrew_calendar/main.dart';

import '../../../test_support/fake_auth_repository.dart';
import '../../../test_support/fake_notification_scheduler.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

List<Override> _signedInOverrides() {
  final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
  final InMemoryEventRepository repository = InMemoryEventRepository();
  addTearDown(auth.dispose);
  addTearDown(repository.dispose);
  return <Override>[
    authRepositoryProvider.overrideWithValue(auth),
    eventRepositoryProvider.overrideWithValue(repository),
    notificationSchedulerProvider.overrideWithValue(
      FakeNotificationScheduler(),
    ),
  ];
}

class _FixedFocusNotifier extends CalendarViewNotifier {
  _FixedFocusNotifier(this._focused);

  final HebrewDate _focused;

  @override
  CalendarViewState build() => CalendarViewState(
    viewType: CalendarViewType.month,
    focusedDate: _focused,
  );
}

String _monthYearTitle(HebrewDate date) =>
    '${_engine.monthName(date.month)} ${hebrewYearNumeral(date.year)}';

void main() {
  testWidgets('the view switcher switches between all four views', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _signedInOverrides(),
        child: const HebrewCalendarApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MonthViewBody), findsOneWidget);

    Future<void> switchTo(String label) async {
      await tester.tap(find.byType(PopupMenuButton<CalendarViewType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await switchTo('שבוע');
    expect(find.byType(WeekViewScreen), findsOneWidget);
    expect(find.byType(MonthViewBody), findsNothing);

    await switchTo('יום');
    expect(find.byType(DayViewScreen), findsOneWidget);
    expect(find.byType(WeekViewScreen), findsNothing);

    await switchTo("אג'נדה");
    expect(find.byType(AgendaViewScreen), findsOneWidget);
    expect(find.byType(DayViewScreen), findsNothing);

    await switchTo('חודש');
    expect(find.byType(MonthViewBody), findsOneWidget);
    expect(find.byType(AgendaViewScreen), findsNothing);
  });

  testWidgets('the today button refocuses on today without changing view', (
    WidgetTester tester,
  ) async {
    final HebrewDate today = _engine.fromGregorian(DateTime.now());
    final HebrewDate farPast = HebrewDate(
      year: today.year - 5,
      month: HebrewMonth.tishrei,
      day: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ..._signedInOverrides(),
          calendarViewProvider.overrideWith(() => _FixedFocusNotifier(farPast)),
        ],
        child: const HebrewCalendarApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_monthYearTitle(farPast)), findsOneWidget);
    expect(find.byType(MonthViewBody), findsOneWidget);

    await tester.tap(find.byIcon(Icons.today));
    await tester.pumpAndSettle();

    expect(find.text(_monthYearTitle(today)), findsOneWidget);
    expect(find.text(_monthYearTitle(farPast)), findsNothing);
    // Still the month view — only the focus moved.
    expect(find.byType(MonthViewBody), findsOneWidget);
  });
}
