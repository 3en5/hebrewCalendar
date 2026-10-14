// M24: the "+" menu opens the significant-date tool, which previews the
// Hebrew date and creates a yearly Hebrew event.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_providers.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_providers.dart';
import 'package:hebrew_calendar/main.dart';

import '../../test_support/fake_auth_repository.dart';
import '../../test_support/fake_google_calendar_api.dart';
import '../../test_support/fake_notification_scheduler.dart';

void main() {
  testWidgets('creates a Hebrew birthday from a Gregorian date', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
    addTearDown(repository.dispose);
    addTearDown(auth.dispose);

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
        ],
        child: const HebrewCalendarApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('אירוע חדש'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('add-menu-significant-date')),
    );
    await tester.pumpAndSettle();

    final Finder save = find.byKey(const ValueKey<String>('significant-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey<String>('significant-name')),
      'דוד',
    );
    await pickGregorian(tester, day: '15', month: 'מרץ', year: '1985');

    expect(find.textContaining('כ״ב באדר תשמ״ה'), findsOneWidget);

    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final List<Event> events = await repository.getAllForSearch();
    expect(events, hasLength(1));
    expect(events.single.title, 'יום הולדת עברי – דוד');
    expect(events.single.recurrence.type, RecurrenceType.hebrewYearly);
    expect(
      events.single.hebrewDate,
      const HebrewDate(year: 5745, month: HebrewMonth.adar, day: 22),
    );
  });
}

Future<void> pickGregorian(
  WidgetTester tester, {
  required String day,
  required String month,
  required String year,
}) async {
  Future<void> pick(String key, String text) async {
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await tester.pumpAndSettle();
    final Finder menu = find.byType(Scrollable).last;
    final Finder item = find.descendant(of: menu, matching: find.text(text));
    await tester.scrollUntilVisible(item, 200, scrollable: menu);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  await pick('significant-day', day);
  await pick('significant-month', month);
  await pick('significant-year', year);
}
