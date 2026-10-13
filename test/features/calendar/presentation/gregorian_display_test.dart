// M23 (owner request 2026-10-13): a Gregorian display of the calendar,
// switched from the month title. The focused day is the pivot: it stays
// selected when switching.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_display_mode_provider.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/month_grid_data.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_providers.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_providers.dart';
import 'package:hebrew_calendar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> _switchTo(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey<String>('calendar-title')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // 13 October 2026.
  final HebrewDate day = _engine.fromGregorian(DateTime(2026, 10, 13));

  test('addGregorianMonths keeps the Gregorian day, clamped', () {
    final HebrewDate jan31 = _engine.fromGregorian(DateTime(2027, 1, 31));
    expect(
      _engine.toGregorian(addGregorianMonths(_engine, jan31, 1)),
      DateTime(2027, 2, 28),
    );
    expect(
      _engine.toGregorian(addGregorianMonths(_engine, jan31, -2)),
      DateTime(2026, 11, 30),
    );
  });

  testWidgets('the title switches to the Gregorian display and back', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await _pump(tester, day);
    expect(find.text('חשוון תשפ״ז'), findsOneWidget);

    await _switchTo(tester, 'תצוגה לועזית');
    expect(c.read(calendarDisplayModeProvider), CalendarDisplayMode.gregorian);
    expect(find.text('אוקטובר 2026'), findsOneWidget);
    expect(find.text('תשרי–חשוון תשפ״ז'), findsOneWidget);
    // The pivot: the focused day is unchanged.
    expect(c.read(calendarViewProvider).focusedDate, day);
    // The grid runs 1..31 October: the 31st is a cell.
    expect(find.text('31'), findsWidgets);

    await _switchTo(tester, 'תצוגה עברית');
    expect(c.read(calendarDisplayModeProvider), CalendarDisplayMode.hebrew);
    expect(find.text('חשוון תשפ״ז'), findsOneWidget);
    expect(c.read(calendarViewProvider).focusedDate, day);
  });

  testWidgets('in the Gregorian display the grid swipe moves a Gregorian '
      'month', (WidgetTester tester) async {
    final ProviderContainer c = await _pump(tester, day);
    await _switchTo(tester, 'תצוגה לועזית');
    final Offset grid =
        tester.getTopLeft(find.byType(PageView)) + const Offset(150, 120);
    await tester.dragFrom(grid, const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(
      _engine.toGregorian(c.read(calendarViewProvider).focusedDate),
      DateTime(2026, 11, 13),
    );
    expect(find.text('נובמבר 2026'), findsOneWidget);
  });

  test('a preloaded choice applies from the first read', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'calendar_display_mode_v1': 'gregorian',
    });
    await preloadCalendarDisplayMode();
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    // No await: the stored choice is there synchronously.
    expect(c.read(calendarDisplayModeProvider), CalendarDisplayMode.gregorian);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await preloadCalendarDisplayMode();
  });

  test('the choice is kept per device', () async {
    final ProviderContainer first = ProviderContainer();
    await first
        .read(calendarDisplayModeProvider.notifier)
        .set(CalendarDisplayMode.gregorian);
    first.dispose();
    final ProviderContainer second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(calendarDisplayModeProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      second.read(calendarDisplayModeProvider),
      CalendarDisplayMode.gregorian,
    );
  });
}
