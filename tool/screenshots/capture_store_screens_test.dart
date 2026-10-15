// Captures the raw phone screens for the Play Store screenshots from the
// real app widgets with sample events (not run in CI: it lives outside
// test/). Run from the repo root:
//   flutter test tool/screenshots/capture_store_screens_test.dart
// then frame them: python3 tool/brand/make_store_screenshots.py
// Output: build/store_raw/*.png (1080x2400).

// A test file kept outside test/, so the analyzer doesn't know it is one.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_attendee.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/calendar/presentation/calendar_shell_screen.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_providers.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_providers.dart';
import 'package:hebrew_calendar/features/settings/application/theme_mode_provider.dart';
import 'package:hebrew_calendar/data/halacha/daily_halacha_source.dart';
import 'package:hebrew_calendar/data/halacha/halacha_cloud.dart';
import 'package:hebrew_calendar/domain/halacha/daily_halacha.dart';
import 'package:hebrew_calendar/features/halacha/application/daily_halacha_providers.dart';
import 'package:hebrew_calendar/features/settings/application/app_version_provider.dart';
import 'package:hebrew_calendar/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/test_support/fake_auth_repository.dart';
import '../../test/test_support/fake_background_sync_scheduler.dart';
import '../../test/test_support/fake_google_calendar_api.dart';
import '../../test/test_support/fake_notification_scheduler.dart';

/// M25: the daily halacha from the built files in site/halacha/ksa, a
/// sample dedication and share, and no cloud writes.
class _ShotHalachaCloud implements HalachaCloud {
  @override
  Future<String?> dedicationFor(DateTime day) async =>
      'לרפואת כל חולי עמו ישראל';

  @override
  Future<double?> enabledShare() async => 0.45;

  @override
  Future<void> recordChoice({required bool? from, required bool to}) async {}

  @override
  Future<void> recordLearned(DateTime day) async {}
}

DailyHalachaSource _localHalacha() => DailyHalachaSource(
  baseUrl: 'https://example.test/ksa',
  client: MockClient(
    (http.Request r) async => http.Response.bytes(
      File('site/halacha/ksa/${r.url.pathSegments.last}').readAsBytesSync(),
      200,
    ),
  ),
);

/// Preferences for every shot: the daily halacha already shown today, so
/// it opens only in its own shot.
Map<String, Object> _prefs() => <String, Object>{
  'daily_halacha_mode_v1': 'on',
  'daily_halacha_last_shown_v1': dedicationDayKey(DateTime.now()),
};

const Size _physical = Size(1080, 2400);
const double _dpr = 2.625;
final GlobalKey _boundary = GlobalKey();

Future<void> _loadFonts() async {
  final FontLoader rubik = FontLoader('Rubik');
  for (final String w in <String>['Regular', 'Medium', 'SemiBold', 'Bold']) {
    rubik.addFont(rootBundle.load('assets/fonts/Rubik-$w.ttf'));
  }
  await rubik.load();
  final String sdk = Platform.environment['FLUTTER_ROOT']!;
  final FontLoader icons = FontLoader('MaterialIcons')
    ..addFont(
      File(
        '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then((Uint8List b) => ByteData.view(b.buffer)),
    );
  await icons.load();
}

Event _e(
  String title,
  HebrewDate date, {
  RecurrenceRule recurrence = const RecurrenceRule(),
  EventTimeOfDay? start,
  EventTimeOfDay? end,
  String? colorId,
  String location = '',
  List<EventAttendee> attendees = const <EventAttendee>[],
}) {
  final DateTime now = DateTime(2026, 9, 1);
  return Event(
    id: '',
    ownerUid: testUser.uid,
    calendarId: 'default',
    title: title,
    hebrewDate: date,
    allDay: start == null,
    startTime: start,
    endTime: end,
    recurrence: recurrence,
    colorId: colorId,
    location: location,
    attendees: attendees,
    reminderMinutesBefore: const <int>[30],
    createdAt: now,
    updatedAt: now,
  );
}

HebrewDate _t(int day) =>
    HebrewDate(year: 5787, month: HebrewMonth.tishrei, day: day);

/// Sample events around Tishrei 5787 (Sukkot).
Future<void> _seed(InMemoryEventRepository repo) async {
  const RecurrenceRule yearly = RecurrenceRule(
    type: RecurrenceType.hebrewYearly,
  );
  const RecurrenceRule weekly = RecurrenceRule(type: RecurrenceType.weekly);
  for (final Event e in <Event>[
    _e('יום הולדת לאמא', _t(12), recurrence: yearly, colorId: '11'),
    _e('אזכרה לסבא יוסף', _t(23), recurrence: yearly, colorId: '8'),
    _e('יום נישואין', _t(4), recurrence: yearly, colorId: '4'),
    _e(
      'ארוחת חג אצל סבתא',
      _t(15),
      start: const EventTimeOfDay(hour: 19, minute: 0),
      end: const EventTimeOfDay(hour: 22, minute: 0),
      colorId: '10',
      location: 'ירושלים',
    ),
    _e(
      'בניית הסוכה',
      _t(13),
      start: const EventTimeOfDay(hour: 16, minute: 0),
      end: const EventTimeOfDay(hour: 18, minute: 30),
      colorId: '5',
    ),
    _e(
      'פגישת צוות',
      _t(1),
      recurrence: weekly,
      start: const EventTimeOfDay(hour: 9, minute: 0),
      end: const EventTimeOfDay(hour: 10, minute: 0),
      colorId: '9',
      attendees: const <EventAttendee>[
        EventAttendee(
          email: 'dana@example.com',
          response: AttendeeResponse.accepted,
        ),
        EventAttendee(
          email: 'avi@example.com',
          response: AttendeeResponse.accepted,
        ),
      ],
    ),
    _e(
      'שיעור גמרא',
      _t(3),
      recurrence: weekly,
      start: const EventTimeOfDay(hour: 20, minute: 30),
      end: const EventTimeOfDay(hour: 21, minute: 30),
      colorId: '7',
    ),
    _e(
      'רופא שיניים',
      _t(15),
      start: const EventTimeOfDay(hour: 11, minute: 15),
      end: const EventTimeOfDay(hour: 12, minute: 0),
      colorId: '6',
    ),
  ]) {
    await repo.create(e);
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final RenderRepaintBoundary boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: _dpr);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final File out = File('build/store_raw/$name.png');
    await out.create(recursive: true);
    await out.writeAsBytes(bytes!.buffer.asUint8List());
  });
  debugDisableShadows = true;
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required ThemeMode mode,
}) async {
  // `flutter test` draws shadows as solid outlines by default; restored
  // at the end of [_shot] (the test framework checks it is reset).
  debugDisableShadows = false;
  tester.view.physicalSize = _physical;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
  final InMemoryEventRepository repository = InMemoryEventRepository();
  await _seed(repository);
  final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
  final InMemorySyncSettingsStore store = InMemorySyncSettingsStore();
  await store.setEnabled(true);
  await store.saveLastSyncedAt(DateTime.now());
  addTearDown(repository.dispose);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        overrides: <Override>[
          eventRepositoryProvider.overrideWithValue(repository),
          authRepositoryProvider.overrideWithValue(auth),
          notificationSchedulerProvider.overrideWithValue(
            FakeNotificationScheduler(),
          ),
          googleCalendarApiProvider.overrideWithValue(FakeGoogleCalendarApi()),
          syncSettingsStoreProvider.overrideWithValue(store),
          appVersionProvider.overrideWith((Ref ref) async => '1.0.0'),
          dailyHalachaSourceProvider.overrideWithValue(_localHalacha()),
          halachaCloudProvider.overrideWithValue(_ShotHalachaCloud()),
          backgroundSyncSchedulerProvider.overrideWithValue(
            FakeBackgroundSyncScheduler(),
          ),
        ],
        child: const HebrewCalendarApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(CalendarShellScreen)),
  );
  if (mode == ThemeMode.dark) {
    await container.read(themeModeProvider.notifier).setDark(true);
  }
  container.read(calendarViewProvider.notifier).setFocusedDate(_t(15));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _loadFonts();
  });
  // A fresh preferences store per screen, so dark mode doesn't carry over.
  setUp(() => SharedPreferences.setMockInitialValues(_prefs()));

  testWidgets('month', (WidgetTester tester) async {
    await _pumpApp(tester, mode: ThemeMode.light);
    await _shot(tester, '1_month');
  });

  testWidgets('month dark', (WidgetTester tester) async {
    await _pumpApp(tester, mode: ThemeMode.dark);
    await _shot(tester, '6_month_dark');
  });

  testWidgets('week', (WidgetTester tester) async {
    final ProviderContainer c = await _pumpApp(tester, mode: ThemeMode.light);
    c.read(calendarViewProvider.notifier).setViewType(CalendarViewType.week);
    await _shot(tester, '2_week');
  });

  testWidgets('agenda', (WidgetTester tester) async {
    final ProviderContainer c = await _pumpApp(tester, mode: ThemeMode.light);
    c.read(calendarViewProvider.notifier).setViewType(CalendarViewType.agenda);
    await _shot(tester, '8_agenda');
  });

  testWidgets('editor', (WidgetTester tester) async {
    final ProviderContainer c = await _pumpApp(tester, mode: ThemeMode.light);
    // A date in Adar of a leap year, so the leap-year Adar choice shows.
    c
        .read(calendarViewProvider.notifier)
        .setFocusedDate(
          const HebrewDate(year: 5787, month: HebrewMonth.adarII, day: 10),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('add-menu-new-event')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'יום הולדת לדוד');
    await tester.tap(find.byIcon(Icons.repeat));
    await tester.pumpAndSettle();
    await tester.tap(find.text('כל שנה (עברי)'));
    await tester.pumpAndSettle();
    await _shot(tester, '3b_editor_recurrence');
    await tester.ensureVisible(find.text('סיום'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('סיום'));
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _shot(tester, '3_editor');
  });

  testWidgets('search', (WidgetTester tester) async {
    await _pumpApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'יום');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _shot(tester, '4_search');
  });

  testWidgets('settings', (WidgetTester tester) async {
    await _pumpApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('הגדרות'));
    await _shot(tester, '5_settings');
  });

  testWidgets('halacha', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_halacha_mode_v1': 'on',
    });
    await _pumpApp(tester, mode: ThemeMode.light);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await _shot(tester, '9_halacha');
  });

  testWidgets('significant', (WidgetTester tester) async {
    await _pumpApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('add-menu-significant-date')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('significant-name')),
      'דוד',
    );
    Future<void> pick(String key, String text) async {
      await tester.tap(find.byKey(ValueKey<String>(key)));
      await tester.pumpAndSettle();
      final Finder menu = find.byType(Scrollable).last;
      final Finder item = find.descendant(of: menu, matching: find.text(text));
      await tester.scrollUntilVisible(item, 200, scrollable: menu);
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    await pick('significant-day', '15');
    await pick('significant-month', 'מרץ');
    await pick('significant-year', '1985');
    await tester.tap(find.text('אחרי השקיעה'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _shot(tester, '10_significant');
  });

  testWidgets('day zmanim', (WidgetTester tester) async {
    final ProviderContainer c = await _pumpApp(tester, mode: ThemeMode.light);
    c.read(calendarViewProvider.notifier).setViewType(CalendarViewType.day);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile).first);
    await _shot(tester, '11_day');
  });

  testWidgets('settings halacha', (WidgetTester tester) async {
    await _pumpApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('הגדרות'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await _shot(tester, '12_settings_more');
  });

  testWidgets('about', (WidgetTester tester) async {
    await _pumpApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('אודות').last);
    await _shot(tester, '7_about');
  });
}
