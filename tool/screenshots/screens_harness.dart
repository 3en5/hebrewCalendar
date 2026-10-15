// Shared by the screenshot captures in this folder (store screens and the
// user guide): the real app with sample events, fonts, and a PNG writer.

// Used by test files kept outside test/, so the analyzer doesn't know them.
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

import '../../test/test_support/fake_auth_repository.dart';
import '../../test/test_support/fake_background_sync_scheduler.dart';
import '../../test/test_support/fake_google_calendar_api.dart';
import '../../test/test_support/fake_notification_scheduler.dart';

/// M25: the daily halacha from the built files in site/halacha/ksa, a
/// sample dedication and share, and no cloud writes.
class ShotHalachaCloud implements HalachaCloud {
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

DailyHalachaSource localHalacha() => DailyHalachaSource(
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
Map<String, Object> shotPrefs() => <String, Object>{
  'daily_halacha_mode_v1': 'on',
  'daily_halacha_last_shown_v1': dedicationDayKey(DateTime.now()),
};

const Size shotPhysicalSize = Size(1080, 2400);
const double shotDpr = 2.625;
final GlobalKey shotBoundary = GlobalKey();

Future<void> loadShotFonts() async {
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

HebrewDate shotDay(int day) =>
    HebrewDate(year: 5787, month: HebrewMonth.tishrei, day: day);

/// Sample events around Tishrei 5787 (Sukkot).
Future<void> _seed(InMemoryEventRepository repo) async {
  const RecurrenceRule yearly = RecurrenceRule(
    type: RecurrenceType.hebrewYearly,
  );
  const RecurrenceRule weekly = RecurrenceRule(type: RecurrenceType.weekly);
  for (final Event e in <Event>[
    _e('יום הולדת לאמא', shotDay(12), recurrence: yearly, colorId: '11'),
    _e('אזכרה לסבא יוסף', shotDay(23), recurrence: yearly, colorId: '8'),
    _e('יום נישואין', shotDay(4), recurrence: yearly, colorId: '4'),
    _e(
      'ארוחת חג אצל סבתא',
      shotDay(15),
      start: const EventTimeOfDay(hour: 19, minute: 0),
      end: const EventTimeOfDay(hour: 22, minute: 0),
      colorId: '10',
      location: 'ירושלים',
    ),
    _e(
      'בניית הסוכה',
      shotDay(13),
      start: const EventTimeOfDay(hour: 16, minute: 0),
      end: const EventTimeOfDay(hour: 18, minute: 30),
      colorId: '5',
    ),
    _e(
      'פגישת צוות',
      shotDay(1),
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
      shotDay(3),
      recurrence: weekly,
      start: const EventTimeOfDay(hour: 20, minute: 30),
      end: const EventTimeOfDay(hour: 21, minute: 30),
      colorId: '7',
    ),
    _e(
      'רופא שיניים',
      shotDay(15),
      start: const EventTimeOfDay(hour: 11, minute: 15),
      end: const EventTimeOfDay(hour: 12, minute: 0),
      colorId: '6',
    ),
  ]) {
    await repo.create(e);
  }
}

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await shotNow(tester, name);
  debugDisableShadows = true;
}

/// Writes the screen as it is now, without letting animations settle (a
/// held press, a running animation).
Future<void> shotNow(WidgetTester tester, String name) async {
  final RenderRepaintBoundary boundary =
      shotBoundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: shotDpr);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final File out = File('build/store_raw/$name.png');
    await out.create(recursive: true);
    await out.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<ProviderContainer> pumpShotApp(
  WidgetTester tester, {
  required ThemeMode mode,
}) async {
  // `flutter test` draws shadows as solid outlines by default; restored
  // at the end of [shot] (the test framework checks it is reset).
  debugDisableShadows = false;
  tester.view.physicalSize = shotPhysicalSize;
  tester.view.devicePixelRatio = shotDpr;
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
      key: shotBoundary,
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
          dailyHalachaSourceProvider.overrideWithValue(localHalacha()),
          halachaCloudProvider.overrideWithValue(ShotHalachaCloud()),
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
  // The app remembers the last view; every shot starts from the month.
  container
      .read(calendarViewProvider.notifier)
      .setViewType(CalendarViewType.month);
  container.read(calendarViewProvider.notifier).setFocusedDate(shotDay(15));
  await tester.pumpAndSettle();
  return container;
}
