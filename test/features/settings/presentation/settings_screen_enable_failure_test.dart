// Device-feedback round #3 widget test — split out from
// settings_screen_test.dart (RULES.md §2, 500-line file limit): tapping the
// enable switch when Google authorization genuinely fails (not a plain
// decline/cancel) must show a snackbar with the real error text and leave
// the switch off, never silence (the reported symptom: tap does nothing, no
// dialog, no error, stays off).

import 'dart:async';

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
import 'package:hebrew_calendar/features/settings/presentation/settings_screen.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:hebrew_calendar/l10n/app_localizations_he.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../test_support/fake_auth_repository.dart';
import '../../../test_support/fake_background_sync_scheduler.dart';
import '../../../test_support/fake_backup_service.dart';
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
  PackageInfo.setMockInitialValues(
    appName: 'hebrew_calendar',
    packageName: 'com.hebrewcalendar.hebrew_calendar',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  testWidgets(
    'a genuine authorization failure shows a snackbar with the real error '
    'text and leaves the switch off — never silent',
    (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
      final InMemoryEventRepository repository = InMemoryEventRepository();
      final FakeGoogleCalendarApi api = FakeGoogleCalendarApi()
        ..nextRequestAccessError = StateError(
          'No signed-in Google account available for Calendar sync.',
        );
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
      // The real error text is surfaced in two places at once — the
      // snackbar (settingsGoogleSyncActionFailedMessage) and the section's
      // own persistent inline error line (settingsGoogleSyncErrorPrefix,
      // since `enable()`'s failure also sets `SyncStatus.error`) — both
      // contain the underlying message, hence findsWidgets not
      // findsOneWidget.
      expect(find.textContaining('No signed-in Google account'), findsWidgets);
    },
  );

  testWidgets(
    'the switch is disabled and shows a small progress indicator while '
    'authorization is in flight, so a second tap cannot double-fire',
    (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
      final InMemoryEventRepository repository = InMemoryEventRepository();
      final FakeGoogleCalendarApi api = FakeGoogleCalendarApi();
      final Completer<void> gate = Completer<void>();
      api.holdRequestAccessUntil = gate.future;
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
      // One pump (not pumpAndSettle): catch the switch mid-flight, while
      // `requestAccess()` is held open by `gate` below — `pumpAndSettle`
      // would hang forever waiting for a future that never resolves on
      // its own.
      await tester.pump();

      final SwitchListTile busySwitch = tester.widget(
        find.byType(SwitchListTile),
      );
      expect(busySwitch.onChanged, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      final AppLocalizationsHe l10n = AppLocalizationsHe();
      expect(
        find.text(
          l10n.settingsBackgroundSyncStatus(
            l10n.settingsBackgroundSyncStatusActive,
          ),
        ),
        findsOneWidget,
      );
    },
  );
}
