// Widget tests for the Hebrew month view: docs/TESTING_AND_DEPLOY.md
// requires widget tests for central screens plus RTL verification.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_numerals.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/calendar/application/displayed_month_provider.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/main.dart';

import '../../../test_support/fake_auth_repository.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

/// Every test pumps [HebrewCalendarApp] and expects the (signed-in) month
/// view, so each needs the auth gate signed in and an in-memory event
/// repository (the auth gate now sits in front of [MonthViewScreen] — M2b).
List<Override> _signedInOverrides() {
  final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
  final InMemoryEventRepository repository = InMemoryEventRepository();
  addTearDown(auth.dispose);
  addTearDown(repository.dispose);
  return <Override>[
    authRepositoryProvider.overrideWithValue(auth),
    eventRepositoryProvider.overrideWithValue(repository),
  ];
}

/// Overrides [DisplayedMonthNotifier] with a fixed initial month so tests
/// don't depend on the wall-clock date.
class _FixedMonthNotifier extends DisplayedMonthNotifier {
  _FixedMonthNotifier(this._fixedMonth);

  final HebrewDate _fixedMonth;

  @override
  HebrewDate build() => _fixedMonth;
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
        overrides: [
          ..._signedInOverrides(),
          displayedMonthProvider.overrideWith(
            () => _FixedMonthNotifier(fixedMonth),
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

  testWidgets('tapping the next-month chevron changes the title', (
    WidgetTester tester,
  ) async {
    const HebrewDate fixedMonth = HebrewDate(
      year: 5786,
      month: HebrewMonth.tishrei,
      day: 1,
    );
    final HebrewDate followingMonth = _engine.nextMonth(fixedMonth);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._signedInOverrides(),
          displayedMonthProvider.overrideWith(
            () => _FixedMonthNotifier(fixedMonth),
          ),
        ],
        child: const HebrewCalendarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_expectedTitle(fixedMonth)), findsOneWidget);

    await tester.tap(find.byTooltip('החודש הבא'));
    await tester.pumpAndSettle();

    expect(find.text(_expectedTitle(followingMonth)), findsOneWidget);
    expect(find.text(_expectedTitle(fixedMonth)), findsNothing);
  });
}
