// Sync progress (device request 2026-10-12): the engine reports each phase,
// and the progress view shows it in words over a progress bar.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/data/sync/sync_engine.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/sync/remote_event_snapshot.dart';
import 'package:hebrew_calendar/domain/sync/sync_progress.dart';
import 'package:hebrew_calendar/features/settings/presentation/widgets/sync_progress_view.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';

import '../../test_support/fake_google_calendar_api.dart';

void main() {
  test('a pass reports downloading, then applying, then uploading', () async {
    final DateTime now = DateTime(2026, 6, 15, 9);
    final InMemoryEventRepository repository = InMemoryEventRepository(
      now: () => now,
    );
    addTearDown(repository.dispose);
    final FakeGoogleCalendarApi api = FakeGoogleCalendarApi();
    final InMemorySyncSettingsStore store = InMemorySyncSettingsStore();
    await store.setEnabled(true);
    api.events['g-1'] = RemoteEventSnapshot(
      googleEventId: 'g-1',
      etag: 'e',
      updatedAt: now,
      isCancelled: false,
      summary: 'מ-Google',
      start: DateTime(2026, 6, 20),
      end: DateTime(2026, 6, 21),
    );
    await repository.create(
      Event(
        id: '',
        ownerUid: 'uid-1',
        calendarId: 'default',
        title: 'מהאפליקציה',
        hebrewDate: const HebrewDate(
          year: 5786,
          month: HebrewMonth.tammuz,
          day: 1,
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final List<SyncProgress> seen = <SyncProgress>[];

    await SyncEngine(
      repository: repository,
      api: api,
      settingsStore: store,
      engine: const HebrewDateEngine(),
      now: () => now,
    ).runSync(onProgress: seen.add);

    expect(seen.first.phase, SyncPhase.downloading);
    expect(
      seen,
      contains(const SyncProgress(SyncPhase.applying, done: 1, total: 1)),
    );
    expect(
      seen.last,
      const SyncProgress(SyncPhase.uploading, done: 1, total: 1),
    );
  });

  testWidgets('the view shows the counts and a filling bar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('he'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object?>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(
          body: SyncProgressView(
            progress: SyncProgress(SyncPhase.applying, done: 340, total: 2944),
          ),
        ),
      ),
    );
    expect(find.text('מעדכן ביומן: 340 מתוך 2,944'), findsOneWidget);
    final LinearProgressIndicator bar = tester.widget(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(340 / 2944, 1e-9));
  });
}
