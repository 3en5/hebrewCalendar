// Widget tests for the M5a settings screen: the enable flow requests
// Google Calendar access (via a fake), and the manual "סנכרן עכשיו" button
// updates the last-sync label.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_providers.dart';
import 'package:hebrew_calendar/features/settings/presentation/settings_screen.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:hebrew_calendar/l10n/app_localizations_he.dart';

import '../../../test_support/fake_auth_repository.dart';
import '../../../test_support/fake_google_calendar_api.dart';

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
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'enabling sync requests Google Calendar access and turns the switch on',
    (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
      final InMemoryEventRepository repository = InMemoryEventRepository();
      final FakeGoogleCalendarApi api = FakeGoogleCalendarApi();
      addTearDown(auth.dispose);
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        _wrap(<Override>[
          authRepositoryProvider.overrideWithValue(auth),
          eventRepositoryProvider.overrideWithValue(repository),
          googleCalendarApiProvider.overrideWithValue(api),
          syncSettingsStoreProvider.overrideWithValue(
            InMemorySyncSettingsStore(),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsOneWidget);
      SwitchListTile switchTile = tester.widget(find.byType(SwitchListTile));
      expect(switchTile.value, isFalse);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(api.requestAccessCallCount, 1);
      switchTile = tester.widget(find.byType(SwitchListTile));
      expect(switchTile.value, isTrue);
    },
  );

  testWidgets(
    'when access is denied, the switch stays off and a snackbar is shown',
    (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
      final InMemoryEventRepository repository = InMemoryEventRepository();
      final FakeGoogleCalendarApi api = FakeGoogleCalendarApi()
        ..accessGranted = false;
      addTearDown(auth.dispose);
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        _wrap(<Override>[
          authRepositoryProvider.overrideWithValue(auth),
          eventRepositoryProvider.overrideWithValue(repository),
          googleCalendarApiProvider.overrideWithValue(api),
          syncSettingsStoreProvider.overrideWithValue(
            InMemorySyncSettingsStore(),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      final SwitchListTile switchTile = tester.widget(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets('manual sync-now updates the last-sync label', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
    final InMemoryEventRepository repository = InMemoryEventRepository();
    final FakeGoogleCalendarApi api = FakeGoogleCalendarApi();
    final InMemorySyncSettingsStore store = InMemorySyncSettingsStore();
    addTearDown(auth.dispose);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _wrap(<Override>[
        authRepositoryProvider.overrideWithValue(auth),
        eventRepositoryProvider.overrideWithValue(repository),
        googleCalendarApiProvider.overrideWithValue(api),
        syncSettingsStoreProvider.overrideWithValue(store),
      ]),
    );
    await tester.pumpAndSettle();

    // Enable first — the sync-now button is disabled while sync is off.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final AppLocalizationsHe l10n = AppLocalizationsHe();
    expect(find.text(l10n.settingsGoogleSyncNeverSynced), findsNothing);

    await tester.tap(find.byIcon(Icons.sync));
    await tester.pumpAndSettle();

    expect(find.textContaining(':'), findsWidgets);
  });
}
