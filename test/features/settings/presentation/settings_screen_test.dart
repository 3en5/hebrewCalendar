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
import 'package:hebrew_calendar/features/settings/application/backup_providers.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_providers.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_settings_state.dart';
import 'package:hebrew_calendar/features/settings/presentation/settings_screen.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:hebrew_calendar/l10n/app_localizations_he.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../test_support/fake_auth_repository.dart';
import '../../../test_support/fake_background_sync_scheduler.dart';
import '../../../test_support/fake_backup_service.dart';
import '../../../test_support/fake_google_calendar_api.dart';
import '../../../test_support/fake_hanging_sync_settings_store.dart';

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
  // M7: the settings screen's version footer reads `PackageInfo.fromPlatform()`
  // — this is the package's own supported test seam, avoiding the real
  // platform channel (which would throw `MissingPluginException` under
  // plain `flutter test`, per docs/LESSONS.md's note on plugin channels).
  PackageInfo.setMockInitialValues(
    appName: 'hebrew_calendar',
    packageName: 'il.co.natanor.kalfapp.hebrewcalendar',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  testWidgets(
    'enabling sync requests Google Calendar access and turns the switch on',
    (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
      final InMemoryEventRepository repository = InMemoryEventRepository();
      final FakeGoogleCalendarApi api = FakeGoogleCalendarApi();
      final FakeBackgroundSyncScheduler scheduler =
          FakeBackgroundSyncScheduler();
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
          backgroundSyncSchedulerProvider.overrideWithValue(scheduler),
          backupServiceProvider.overrideWithValue(FakeBackupService()),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsOneWidget);
      SwitchListTile switchTile = tester.widget(find.byType(SwitchListTile));
      expect(switchTile.value, isFalse);
      final AppLocalizationsHe l10n = AppLocalizationsHe();
      expect(
        find.text(
          l10n.settingsBackgroundSyncStatus(
            l10n.settingsBackgroundSyncStatusOff,
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(api.requestAccessCallCount, 1);
      expect(scheduler.registerPeriodicCallCount, 1);
      expect(
        find.text(
          l10n.settingsBackgroundSyncStatus(
            l10n.settingsBackgroundSyncStatusActive,
          ),
        ),
        findsOneWidget,
      );
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
          backgroundSyncSchedulerProvider.overrideWithValue(
            FakeBackgroundSyncScheduler(),
          ),
          backupServiceProvider.overrideWithValue(FakeBackupService()),
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
        backgroundSyncSchedulerProvider.overrideWithValue(
          FakeBackgroundSyncScheduler(),
        ),
        backupServiceProvider.overrideWithValue(FakeBackupService()),
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

  testWidgets(
    'a settings load that never completes shows a retry error, not an '
    'endless spinner (real-device report #2)',
    (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
      final InMemoryEventRepository repository = InMemoryEventRepository();
      final FakeGoogleCalendarApi api = FakeGoogleCalendarApi();
      final FakeHangingSyncSettingsStore hangingStore =
          FakeHangingSyncSettingsStore();
      addTearDown(auth.dispose);
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        _wrap(<Override>[
          authRepositoryProvider.overrideWithValue(auth),
          eventRepositoryProvider.overrideWithValue(repository),
          googleCalendarApiProvider.overrideWithValue(api),
          syncSettingsStoreProvider.overrideWithValue(hangingStore),
          // Short enough that the test doesn't wait for the real
          // production default (10s) — proves the bounded-loading
          // mechanism works, not its exact duration.
          syncStartTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 20),
          ),
          backgroundSyncSchedulerProvider.overrideWithValue(
            FakeBackgroundSyncScheduler(),
          ),
          backupServiceProvider.overrideWithValue(FakeBackupService()),
        ]),
      );

      // Give the timeout a chance to fire; well under flutter test's
      // default async-guard budget.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      final AppLocalizationsHe l10n = AppLocalizationsHe();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text(l10n.settingsGoogleSyncLoadFailedMessage),
        findsOneWidget,
      );
      expect(find.text(l10n.settingsGoogleSyncRetryButton), findsOneWidget);

      await tester.tap(find.text(l10n.settingsGoogleSyncRetryButton));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      // Retrying re-attempts the (still-hanging) load and times out again —
      // still a clear error, never silence or a stuck spinner.
      expect(
        find.text(l10n.settingsGoogleSyncLoadFailedMessage),
        findsOneWidget,
      );
    },
  );

  testWidgets('the About entry opens a screen with the app name and version', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(auth.dispose);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _wrap(<Override>[
        authRepositoryProvider.overrideWithValue(auth),
        eventRepositoryProvider.overrideWithValue(repository),
        googleCalendarApiProvider.overrideWithValue(FakeGoogleCalendarApi()),
        syncSettingsStoreProvider.overrideWithValue(
          InMemorySyncSettingsStore(),
        ),
        backgroundSyncSchedulerProvider.overrideWithValue(
          FakeBackgroundSyncScheduler(),
        ),
        backupServiceProvider.overrideWithValue(FakeBackupService()),
      ]),
    );
    await tester.pumpAndSettle();

    final AppLocalizationsHe l10n = AppLocalizationsHe();
    // The "אודות" entry sits below the sync/backup sections, past the fold
    // on the test surface's default size — scroll it into view first.
    await tester.dragUntilVisible(
      find.text(l10n.settingsAboutTooltip),
      find.byType(ListView),
      const Offset(0, -100),
    );
    // `dragUntilVisible` stops once the widget enters the sliver's cache
    // extent, which can be just before it's actually hit-testable within
    // the viewport (docs/LESSONS.md) — a small extra drag guarantees `tap`
    // lands on it.
    await tester.drag(find.byType(ListView), const Offset(0, -50));
    await tester.pumpAndSettle();
    // Owner request 2026-10-15: "rate the app" sits above About.
    expect(find.byKey(const ValueKey<String>('rate-app')), findsOneWidget);
    // Owner request 2026-10-15: the user guide, above "rate the app".
    expect(find.byKey(const ValueKey<String>('user-guide')), findsOneWidget);
    await tester.tap(find.text(l10n.settingsAboutTooltip));
    await tester.pumpAndSettle();

    expect(find.text(l10n.aboutScreenTitle), findsWidgets);
    // The app name and tagline are (deliberately, per the task brief) the
    // same Hebrew text, so both render as "יומן עברי" — hence findsWidgets.
    expect(find.text(l10n.appTitle), findsWidgets);
    expect(find.text(l10n.aboutDeveloperCredit), findsOneWidget);
    // Owner request 2026-10-15: privacy policy and terms of use links.
    expect(find.byKey(const ValueKey<String>('about-privacy')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('about-terms')), findsOneWidget);
    expect(find.textContaining('1.0.0'), findsOneWidget);
  });

  group('real-device report #2, round 2 — the spinner was outliving '
      "start()'s own timeout", () {
    testWidgets(
      'rendering the sync section needs no GoogleCalendarApi override at '
      'all — the section never constructs/awaits Google auth to display '
      '(if this ever required an override again, that would be the '
      'smoking gun)',
      (WidgetTester tester) async {
        final FakeAuthRepository auth = FakeAuthRepository(
          initialUser: testUser,
        );
        final InMemoryEventRepository repository = InMemoryEventRepository();
        addTearDown(auth.dispose);
        addTearDown(repository.dispose);

        await tester.pumpWidget(
          _wrap(<Override>[
            authRepositoryProvider.overrideWithValue(auth),
            eventRepositoryProvider.overrideWithValue(repository),
            // Deliberately NOT overriding `googleCalendarApiProvider`: the
            // real `GoogleCalendarApiImpl` (which only stores a
            // `GoogleSignIn.instance` reference — never calls it) is
            // constructed here.
            syncSettingsStoreProvider.overrideWithValue(
              InMemorySyncSettingsStore(),
            ),
            backgroundSyncSchedulerProvider.overrideWithValue(
              FakeBackgroundSyncScheduler(),
            ),
            backupServiceProvider.overrideWithValue(FakeBackupService()),
          ]),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(SwitchListTile), findsOneWidget);
      },
    );

    testWidgets(
      'a provider that throws synchronously during construction shows the '
      'retry card with the real error text, not a crash or an endless '
      'spinner',
      (WidgetTester tester) async {
        final FakeAuthRepository auth = FakeAuthRepository(
          initialUser: testUser,
        );
        final InMemoryEventRepository repository = InMemoryEventRepository();
        addTearDown(auth.dispose);
        addTearDown(repository.dispose);

        await tester.pumpWidget(
          _wrap(<Override>[
            authRepositoryProvider.overrideWithValue(auth),
            eventRepositoryProvider.overrideWithValue(repository),
            googleCalendarApiProvider.overrideWith(
              (Ref ref) => throw StateError('כשל מכוון בבנייה לבדיקה'),
            ),
            syncSettingsStoreProvider.overrideWithValue(
              InMemorySyncSettingsStore(),
            ),
            backgroundSyncSchedulerProvider.overrideWithValue(
              FakeBackgroundSyncScheduler(),
            ),
            backupServiceProvider.overrideWithValue(FakeBackupService()),
          ]),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final AppLocalizationsHe l10n = AppLocalizationsHe();
        expect(find.text(l10n.settingsGoogleSyncRetryButton), findsOneWidget);
        expect(find.textContaining('כשל מכוון בבנייה לבדיקה'), findsOneWidget);
      },
    );

    testWidgets(
      "a googleSyncStateProvider stream that never emits at all (every "
      "provider layer failing to emit, hypothetically, despite start()'s "
      "own timeout) is still saved by the widget's own 12s loading "
      'watchdog — never an endless spinner',
      (WidgetTester tester) async {
        final FakeAuthRepository auth = FakeAuthRepository(
          initialUser: testUser,
        );
        final InMemoryEventRepository repository = InMemoryEventRepository();
        addTearDown(auth.dispose);
        addTearDown(repository.dispose);

        await tester.pumpWidget(
          _wrap(<Override>[
            authRepositoryProvider.overrideWithValue(auth),
            eventRepositoryProvider.overrideWithValue(repository),
            googleCalendarApiProvider.overrideWithValue(
              FakeGoogleCalendarApi(),
            ),
            syncSettingsStoreProvider.overrideWithValue(
              InMemorySyncSettingsStore(),
            ),
            backgroundSyncSchedulerProvider.overrideWithValue(
              FakeBackgroundSyncScheduler(),
            ),
            backupServiceProvider.overrideWithValue(FakeBackupService()),
            // Simulates every provider layer above the widget failing to
            // ever emit anything (a stream that closes without a single
            // event) — the scenario the widget's own watchdog exists for,
            // independent of how well `start()`/`watchState()` behave.
            googleSyncStateProvider.overrideWith(
              (Ref ref) => const Stream<GoogleSyncSettingsState>.empty(),
            ),
          ]),
        );
        await tester.pump();

        final AppLocalizationsHe l10n = AppLocalizationsHe();
        expect(find.text(l10n.settingsGoogleSyncWatchdogMessage), findsNothing);

        await tester.pump(const Duration(seconds: 13));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.text(l10n.settingsGoogleSyncWatchdogMessage),
          findsOneWidget,
        );
        expect(find.text(l10n.settingsGoogleSyncRetryButton), findsOneWidget);
      },
    );
  });
}
