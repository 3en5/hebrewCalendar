// Device feedback: pulling the calendar down runs a Google sync.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_providers.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_providers.dart';
import 'package:hebrew_calendar/main.dart';

import '../../../test_support/fake_auth_repository.dart';
import '../../../test_support/fake_background_sync_scheduler.dart';
import '../../../test_support/fake_google_calendar_api.dart';
import '../../../test_support/fake_notification_scheduler.dart';

Future<FakeGoogleCalendarApi> _pump(
  WidgetTester tester, {
  required bool syncEnabled,
}) async {
  final InMemoryEventRepository repository = InMemoryEventRepository();
  final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
  final InMemorySyncSettingsStore store = InMemorySyncSettingsStore();
  if (syncEnabled) {
    await store.setEnabled(true);
  }
  final FakeGoogleCalendarApi api = FakeGoogleCalendarApi();
  addTearDown(repository.dispose);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        eventRepositoryProvider.overrideWithValue(repository),
        authRepositoryProvider.overrideWithValue(auth),
        notificationSchedulerProvider.overrideWithValue(
          FakeNotificationScheduler(),
        ),
        googleCalendarApiProvider.overrideWithValue(api),
        syncSettingsStoreProvider.overrideWithValue(store),
        backgroundSyncSchedulerProvider.overrideWithValue(
          FakeBackgroundSyncScheduler(),
        ),
      ],
      child: const HebrewCalendarApp(),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<void> _pullDown(WidgetTester tester) async {
  await tester.fling(find.byType(RefreshIndicator), const Offset(0, 400), 1000);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pulling down with sync off says how to turn it on', (
    WidgetTester tester,
  ) async {
    await _pump(tester, syncEnabled: false);
    await _pullDown(tester);
    expect(
      find.text('הסנכרון עם Google כבוי. אפשר להפעיל אותו בהגדרות.'),
      findsOneWidget,
    );
  });

  testWidgets('pulling down with sync on runs a sync', (
    WidgetTester tester,
  ) async {
    await _pump(tester, syncEnabled: true);
    await _pullDown(tester);
    expect(find.text('הסנכרון עם Google הושלם'), findsOneWidget);
  });
}
