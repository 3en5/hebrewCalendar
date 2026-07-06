// Widget tests for the Hebrew month body (M3b — was MonthViewScreen before
// the calendar shell restructuring): docs/TESTING_AND_DEPLOY.md requires
// widget tests for central screens plus RTL verification.

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
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_providers.dart';
import 'package:hebrew_calendar/main.dart';

import '../../../test_support/fake_auth_repository.dart';
import '../../../test_support/fake_notification_scheduler.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

/// Every test pumps [HebrewCalendarApp] and expects the (signed-in) calendar
/// shell in its default month view, so each needs the auth gate signed in
/// and an in-memory event repository.
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

/// Overrides [CalendarViewNotifier] with a fixed initial month view so
/// tests don't depend on the wall-clock date.
class _FixedMonthViewNotifier extends CalendarViewNotifier {
  _FixedMonthViewNotifier(this._fixedMonth);

  final HebrewDate _fixedMonth;

  @override
  CalendarViewState build() => CalendarViewState(
    viewType: CalendarViewType.month,
    focusedDate: _fixedMonth,
  );
}

String _expectedTitle(HebrewDate month) =>
    '${_engine.monthName(month.month)} ${hebrewYearNumeral(month.year)}';

void main() {
  testWidgets('renders the month view in RTL', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _signedInOverrides(),
        child: const HebrewCalendarApp(),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(Scaffold));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('shows the correct Hebrew month title for a fixed month', (
    WidgetTester tester,
  ) async {
    const HebrewDate fixedMonth = HebrewDate(
      year: 5784,
      month: HebrewMonth.adarI,
      day: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ..._signedInOverrides(),
          calendarViewProvider.overrideWith(
            () => _FixedMonthViewNotifier(fixedMonth),
          ),
        ],
        child: const HebrewCalendarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_expectedTitle(fixedMonth)), findsOneWidget);
  });

  testWidgets('highlights today in the current month', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _signedInOverrides(),
        child: const HebrewCalendarApp(),
      ),
    );
    await tester.pumpAndSettle();

    final Finder todayCell = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Semantics &&
          (widget.properties.label?.contains('היום') ?? false),
    );
    expect(todayCell, findsOneWidget);
  });

  testWidgets('swiping the month view changes the title', (
    WidgetTester tester,
  ) async {
    const HebrewDate fixedMonth = HebrewDate(
      year: 5786,
      month: HebrewMonth.tishrei,
      day: 1,
    );
    final HebrewDate nextMonth = _engine.nextMonth(fixedMonth);
    final HebrewDate previousMonth = _engine.previousMonth(fixedMonth);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ..._signedInOverrides(),
          calendarViewProvider.overrideWith(
            () => _FixedMonthViewNotifier(fixedMonth),
          ),
        ],
        child: const HebrewCalendarApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_expectedTitle(fixedMonth)), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-800, 0));
    await tester.pumpAndSettle();

    // The original month's title must be gone; the new one must be one of
    // the two chronologically-adjacent months — the exact swipe direction
    // depends on RTL page-index semantics, which this test deliberately
    // doesn't hard-code.
    expect(find.text(_expectedTitle(fixedMonth)), findsNothing);
    final bool showsNext = find
        .text(_expectedTitle(nextMonth))
        .evaluate()
        .isNotEmpty;
    final bool showsPrevious = find
        .text(_expectedTitle(previousMonth))
        .evaluate()
        .isNotEmpty;
    expect(showsNext || showsPrevious, isTrue);
  });
}
