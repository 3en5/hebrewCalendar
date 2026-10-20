// Owner requests 2026-10-15/20: a text size in settings (90%-140%), on top
// of the phone's font size, that also grows the month view's cells.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_providers.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/day_cell.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_providers.dart';
import 'package:hebrew_calendar/features/settings/application/text_size_provider.dart';
import 'package:hebrew_calendar/features/settings/presentation/widgets/text_size_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:hebrew_calendar/main.dart';

import '../../test_support/fake_auth_repository.dart';
import '../../test_support/fake_google_calendar_api.dart';
import '../../test_support/fake_notification_scheduler.dart';

class _FixedDayNotifier extends CalendarViewNotifier {
  _FixedDayNotifier(this._day);

  final HebrewDate _day;

  @override
  CalendarViewState build() =>
      CalendarViewState(viewType: CalendarViewType.month, focusedDate: _day);
}

class _FixedSize extends TextSizeNotifier {
  _FixedSize(this._size);

  final double _size;

  @override
  double build() => _size;
}

const HebrewDate _day = HebrewDate(
  year: 5787,
  month: HebrewMonth.cheshvan,
  day: 12,
);

Future<void> _pump(WidgetTester tester, double size) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
  final InMemoryEventRepository repository = InMemoryEventRepository();
  addTearDown(auth.dispose);
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      // A fresh app per pump, so a second pump takes its new size.
      key: UniqueKey(),
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
        calendarViewProvider.overrideWith(() => _FixedDayNotifier(_day)),
        textSizeProvider.overrideWith(() => _FixedSize(size)),
      ],
      child: const HebrewCalendarApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _cell(int day) => find.byWidgetPredicate(
  (Widget w) => w is DayCell && w.hebrewDay == day && w.onTap != null,
);

void main() {
  testWidgets('the chosen size scales the text on top of the phone', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, 1.2);
    final BuildContext context = tester.element(_cell(15));
    expect(
      MediaQuery.textScalerOf(context).scale(10),
      moreOrLessEquals(10 * 1.1 * 1.2),
    );
  });

  test('the total enlargement stops at the cap', () {
    double total(double phone, double app) =>
        AppTextScaler(TextScaler.linear(phone), app).scale(10) / 10;
    expect(total(1.0, 1.4), moreOrLessEquals(1.4));
    expect(total(1.1, 1.2), moreOrLessEquals(1.32));
    expect(total(1.3, 1.4), moreOrLessEquals(kMaxTotalTextScale));
    // A phone already above the cap keeps its own size.
    expect(total(2.0, 1.4), moreOrLessEquals(2.0));
    // Owner request 2026-10-20: 90% shrinks, even on a large phone font.
    expect(total(1.0, 0.9), moreOrLessEquals(0.9));
    expect(total(2.0, 0.9), moreOrLessEquals(1.8));
  });

  test('sizes snap to the 5% steps of the range', () {
    expect(snapTextSize(0.8), 0.9);
    expect(snapTextSize(1.12), 1.1);
    expect(snapTextSize(1.13), 1.15);
    expect(snapTextSize(2.0), 1.4);
  });

  testWidgets('the month view at 90% has no overflow', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 0.9);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the month cells grow with the text size, without overflow', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 1.0);
    final Size normal = tester.getSize(_cell(15));
    await _pump(tester, 1.4);
    final Size large = tester.getSize(_cell(15));
    expect(large.height, greaterThan(normal.height * 1.2));
    expect(large.width, normal.width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the settings choice is applied and kept', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('he'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: TextSizeTile()),
        ),
      ),
    );
    final Slider slider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('text-size-slider')),
    );
    expect(slider.min, 0.9);
    expect(slider.max, 1.4);
    expect(slider.divisions, 10);
    // Dragging previews without storing; lifting the finger keeps it.
    slider.onChanged!(1.2499);
    await tester.pump();
    expect(container.read(textSizeProvider), 1.25);
    expect(find.text('125%'), findsWidgets);
    final SharedPreferences before = await SharedPreferences.getInstance();
    expect(before.getDouble('app_text_size_v1'), isNull);
    slider.onChangeEnd!(1.3);
    await tester.pumpAndSettle();
    expect(container.read(textSizeProvider), 1.3);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('app_text_size_v1'), 1.3);
    await preloadTextSize();
    final ProviderContainer next = ProviderContainer();
    addTearDown(next.dispose);
    expect(next.read(textSizeProvider), 1.3);
  });
}
