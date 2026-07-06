// Widget tests for the auth gate: docs/TESTING_AND_DEPLOY.md requires
// widget tests for central screens; the auth gate decides which of two
// central screens (sign-in vs. the calendar shell) the whole app shows.
//
// Uses only a fake AuthRepository — never touches real Firebase (task brief
// M2b §5).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/auth/presentation/auth_gate.dart';
import 'package:hebrew_calendar/features/auth/presentation/sign_in_screen.dart';
import 'package:hebrew_calendar/features/calendar/presentation/calendar_shell_screen.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_providers.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_providers.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';

import '../../../test_support/fake_auth_repository.dart';
import '../../../test_support/fake_google_calendar_api.dart';
import '../../../test_support/fake_notification_scheduler.dart';

Widget _wrap(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('he'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    ),
  );
}

void main() {
  testWidgets('shows the sign-in screen when signed out', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository auth = FakeAuthRepository();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      _wrap(<Override>[authRepositoryProvider.overrideWithValue(auth)]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(CalendarShellScreen), findsNothing);
  });

  testWidgets('shows the month view when signed in', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
    addTearDown(auth.dispose);
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _wrap(<Override>[
        authRepositoryProvider.overrideWithValue(auth),
        eventRepositoryProvider.overrideWithValue(repository),
        notificationSchedulerProvider.overrideWithValue(
          FakeNotificationScheduler(),
        ),
        googleCalendarApiProvider.overrideWithValue(FakeGoogleCalendarApi()),
        syncSettingsStoreProvider.overrideWithValue(
          InMemorySyncSettingsStore(),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CalendarShellScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('switches from month view to sign-in when the user signs out', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
    addTearDown(auth.dispose);
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _wrap(<Override>[
        authRepositoryProvider.overrideWithValue(auth),
        eventRepositoryProvider.overrideWithValue(repository),
        notificationSchedulerProvider.overrideWithValue(
          FakeNotificationScheduler(),
        ),
        googleCalendarApiProvider.overrideWithValue(FakeGoogleCalendarApi()),
        syncSettingsStoreProvider.overrideWithValue(
          InMemorySyncSettingsStore(),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CalendarShellScreen), findsOneWidget);

    auth.emit(null);
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(CalendarShellScreen), findsNothing);
  });
}
