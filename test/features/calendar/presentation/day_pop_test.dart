// Owner request 2026-10-15: tapping a day in the month view pops its cell
// to twice its size for about a second, then it shrinks back.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/day_cell.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/day_pop_stack.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_providers.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_providers.dart';
import 'package:hebrew_calendar/main.dart';

import '../../../test_support/fake_auth_repository.dart';
import '../../../test_support/fake_google_calendar_api.dart';
import '../../../test_support/fake_notification_scheduler.dart';


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

final Finder _pop = find.byKey(const ValueKey<String>('day-pop'));

/// The month grid's cell for Hebrew [day] (the grid, not the agenda).
Finder _cell(int day) => find.byWidgetPredicate(
  (Widget w) => w is DayCell && w.hebrewDay == day && w.onTap != null,
);

void main() {
  const HebrewDate day = HebrewDate(
    year: 5787,
    month: HebrewMonth.cheshvan,
    day: 12,
  );

  testWidgets('a tapped day grows, holds and shrinks back', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await _pump(tester, day);
    final Rect cell = tester.getRect(_cell(18));
    await tester.tap(_cell(18));
    await tester.pump();
    expect(container.read(calendarViewProvider).focusedDate.day, 18);
    await tester.pump(dayPopGrow + const Duration(milliseconds: 100));
    expect(_pop, findsOneWidget);
    final Rect grown = tester.getRect(_pop);
    expect(grown.width, moreOrLessEquals(cell.width * dayPopScale, epsilon: 1));
    expect(
      grown.height,
      moreOrLessEquals(cell.height * dayPopScale, epsilon: 1),
    );
    await tester.pump(dayPopHold + dayPopShrink);
    await tester.pump();
    expect(_pop, findsNothing);
  });

  testWidgets('an edge day grows inwards and stays on screen', (
    WidgetTester tester,
  ) async {
    await _pump(tester, day);
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    // 1 Cheshvan 5787 is a Sunday: the first column, at the right in RTL.
    for (final int d in <int>[1, 7]) {
      await tester.tap(_cell(d));
      await tester.pump(dayPopGrow + const Duration(milliseconds: 100));
      final Rect grown = tester.getRect(_pop);
      expect(grown.left, greaterThanOrEqualTo(-0.5), reason: 'day $d');
      expect(
        grown.right,
        lessThanOrEqualTo(screen.width + 0.5),
        reason: 'day $d',
      );
      await tester.pumpAndSettle();
    }
  });

  testWidgets('no pop when the system turns animations off', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final ProviderContainer container = await _pump(tester, day);
    await tester.tap(_cell(18));
    await tester.pump(dayPopGrow);
    expect(_pop, findsNothing);
    expect(container.read(calendarViewProvider).focusedDate.day, 18);
  });
}
