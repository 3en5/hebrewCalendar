// M17: changes made in Google Calendar to the app's own exports, through
// the real SyncEngine with FakeGoogleCalendarApi + InMemoryEventRepository.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/google_calendar_api.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/data/sync/sync_engine.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_source.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/sync/occurrence_key.dart';
import 'package:hebrew_calendar/domain/sync/remote_event_snapshot.dart';
import 'package:hebrew_calendar/domain/sync/sync_state.dart';

import '../../test_support/fake_google_calendar_api.dart';

const HebrewDateEngine _engine = HebrewDateEngine();
final DateTime _now = DateTime(2026, 6, 15, 9);

/// The anchor: 10 Tevet 5786 (Dec 2025); upcoming instances 5787.. .
const HebrewDate _anchor = HebrewDate(
  year: 5786,
  month: HebrewMonth.tevet,
  day: 10,
);
const HebrewDate _next = HebrewDate(
  year: 5787,
  month: HebrewMonth.tevet,
  day: 10,
);

RemoteEventSnapshot _edited(
  RemoteEventSnapshot base, {
  String? summary,
  DateTime? start,
  bool cancelled = false,
  bool keepMarkers = true,
}) => RemoteEventSnapshot(
  googleEventId: base.googleEventId,
  etag: '${base.etag}-x',
  updatedAt: _now.add(const Duration(hours: 1)),
  isCancelled: cancelled,
  summary: summary ?? base.summary,
  description: base.description,
  location: base.location,
  start: start ?? base.start,
  end: start == null ? base.end : start.add(const Duration(hours: 1)),
  isAllDay: start == null ? base.isAllDay : false,
  hebcalEventId: keepMarkers ? base.hebcalEventId : null,
  hebcalOccurrence: keepMarkers ? base.hebcalOccurrence : null,
);

void main() {
  late InMemoryEventRepository repository;
  late FakeGoogleCalendarApi api;
  late SyncEngine engine;

  setUp(() async {
    repository = InMemoryEventRepository(now: () => _now);
    api = FakeGoogleCalendarApi();
    final InMemorySyncSettingsStore store = InMemorySyncSettingsStore();
    await store.setEnabled(true);
    engine = SyncEngine(
      repository: repository,
      api: api,
      settingsStore: store,
      engine: _engine,
      now: () => _now,
    );
  });

  tearDown(() => repository.dispose());

  Future<Event> exportedSeries() async {
    final Event created = await repository.create(
      Event(
        id: '',
        ownerUid: 'uid-1',
        calendarId: 'default',
        title: 'יום הולדת',
        hebrewDate: _anchor,
        recurrence: const RecurrenceRule(type: RecurrenceType.hebrewYearly),
        reminderMinutesBefore: const <int>[60],
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    await engine.runSync();
    return (await repository.getById(created.id))!;
  }

  RemoteEventSnapshot instanceOf(Event series, HebrewDate date) {
    final String id =
        series.googleInstanceSync[occurrenceKeyFor(date)]!.googleEventId!;
    return api.events[id]!;
  }

  test(
    'an occurrence edited in Google becomes "this occurrence only"',
    () async {
      final Event series = await exportedSeries();
      final RemoteEventSnapshot remote = instanceOf(series, _next);
      final DateTime moved = DateTime(2026, 12, 20, 18, 30);
      final RemoteEventSnapshot edited = _edited(
        remote,
        summary: 'יום הולדת – מסיבה',
        start: moved,
      );
      api.events[remote.googleEventId] = edited;
      api.scriptedPages.add(
        GoogleEventsPage(
          events: <RemoteEventSnapshot>[edited],
          nextSyncToken: 't',
        ),
      );

      await engine.runSync();

      final Event updatedSeries = (await repository.getById(series.id))!;
      expect(updatedSeries.recurrence.exceptions, contains(_next));
      expect(
        updatedSeries.googleInstanceSync.containsKey(occurrenceKeyFor(_next)),
        isFalse,
      );
      final Event standalone = (await repository.getAllForSync()).firstWhere(
        (Event e) => e.id != series.id,
      );
      expect(standalone.title, 'יום הולדת – מסיבה');
      expect(standalone.recurrence.type, RecurrenceType.none);
      expect(standalone.hebrewDate, _engine.fromGregorian(moved));
      expect(standalone.startTime, const EventTimeOfDay(hour: 18, minute: 30));
      expect(standalone.reminderMinutesBefore, <int>[60]);
      expect(standalone.googleSync.googleEventId, remote.googleEventId);
      expect(standalone.googleSync.dirty, isFalse);

      // Later passes neither delete the Google event nor duplicate it.
      await engine.runSync();
      expect(api.deletedEventIds, isNot(contains(remote.googleEventId)));
      expect(await repository.getAllForSync(), hasLength(2));
    },
  );

  test('a new etag with unchanged content (e.g. a guest replied) is not an '
      'edit', () async {
    final Event series = await exportedSeries();
    final RemoteEventSnapshot remote = instanceOf(series, _next);
    final RemoteEventSnapshot touched = _edited(remote);
    api.events[remote.googleEventId] = touched;
    api.scriptedPages.add(
      GoogleEventsPage(
        events: <RemoteEventSnapshot>[touched],
        nextSyncToken: 't',
      ),
    );

    await engine.runSync();

    final Event after = (await repository.getById(series.id))!;
    expect(after.recurrence.exceptions, isEmpty);
    expect(
      after.googleInstanceSync[occurrenceKeyFor(_next)]!.etag,
      touched.etag,
    );
    expect(await repository.getAllForSync(), hasLength(1));
  });

  test('an upcoming occurrence deleted in Google is skipped by the series, '
      'even when the deletion carries no markers', () async {
    final Event series = await exportedSeries();
    final RemoteEventSnapshot remote = instanceOf(series, _next);
    final RemoteEventSnapshot deleted = _edited(
      remote,
      cancelled: true,
      keepMarkers: false,
    );
    api.scriptedPages.add(
      GoogleEventsPage(
        events: <RemoteEventSnapshot>[deleted],
        nextSyncToken: 't',
      ),
    );

    await engine.runSync();

    final Event after = (await repository.getById(series.id))!;
    expect(after.recurrence.exceptions, <HebrewDate>[_next]);
  });

  test('a deletion of a past instance, which the export pass itself prunes, '
      'does not become an exception', () async {
    final Event series = await exportedSeries();
    await repository.updateSyncState(
      series.id,
      googleInstanceSync: <String, GoogleSyncState>{
        occurrenceKeyFor(_anchor): const GoogleSyncState(googleEventId: 'old'),
      },
    );
    api.scriptedPages.add(
      GoogleEventsPage(
        events: <RemoteEventSnapshot>[
          RemoteEventSnapshot(
            googleEventId: 'old',
            etag: 'e',
            updatedAt: _now,
            isCancelled: true,
          ),
        ],
        nextSyncToken: 't',
      ),
    );

    await engine.runSync();

    final Event after = (await repository.getById(series.id))!;
    expect(after.recurrence.exceptions, isEmpty);
  });

  test('a single app event edited in Google takes the new title, keeping '
      'its reminders', () async {
    final Event created = await repository.create(
      Event(
        id: '',
        ownerUid: 'uid-1',
        calendarId: 'default',
        title: 'פגישה',
        hebrewDate: _next,
        reminderMinutesBefore: const <int>[15],
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    await engine.runSync();
    final Event exported = (await repository.getById(created.id))!;
    final RemoteEventSnapshot remote =
        api.events[exported.googleSync.googleEventId]!;
    final RemoteEventSnapshot edited = _edited(remote, summary: 'פגישה חשובה');
    api.scriptedPages.add(
      GoogleEventsPage(
        events: <RemoteEventSnapshot>[edited],
        nextSyncToken: 't',
      ),
    );

    await engine.runSync();

    final Event after = (await repository.getById(created.id))!;
    expect(after.title, 'פגישה חשובה');
    expect(after.reminderMinutesBefore, <int>[15]);
    expect(after.source, EventSource.app);
    expect(after.googleSync.dirty, isFalse);
  });

  test('an own export whose app event no longer exists is ignored, and a '
      'Google copy cleared of its title keeps the app title', () async {
    final Event created = await repository.create(
      Event(
        id: '',
        ownerUid: 'uid-1',
        calendarId: 'default',
        title: 'פגישה',
        hebrewDate: _next,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    await engine.runSync();
    final Event exported = (await repository.getById(created.id))!;
    final RemoteEventSnapshot remote =
        api.events[exported.googleSync.googleEventId]!;
    final RemoteEventSnapshot orphan = RemoteEventSnapshot(
      googleEventId: 'orphan-1',
      etag: 'e',
      updatedAt: _now,
      isCancelled: false,
      summary: 'ישן',
      start: DateTime(2026, 12, 1),
      end: DateTime(2026, 12, 2),
      hebcalEventId: 'deleted-series',
      hebcalOccurrence: occurrenceKeyFor(_next),
    );
    api.scriptedPages.add(
      GoogleEventsPage(
        events: <RemoteEventSnapshot>[
          orphan,
          _edited(remote, summary: ''),
        ],
        nextSyncToken: 't',
      ),
    );

    await engine.runSync();

    expect((await repository.getById(created.id))!.title, 'פגישה');
    expect(await repository.getAllForSync(), hasLength(1));
  });

  test('an imported timed Google event keeps its start and end time', () async {
    api.events['g-1'] = RemoteEventSnapshot(
      googleEventId: 'g-1',
      etag: 'e-1',
      updatedAt: _now,
      isCancelled: false,
      summary: 'רופא',
      start: DateTime(2026, 6, 20, 10, 15),
      end: DateTime(2026, 6, 20, 11),
      isAllDay: false,
    );

    await engine.runSync();

    final Event imported = (await repository.getAllForSync()).single;
    expect(imported.startTime, const EventTimeOfDay(hour: 10, minute: 15));
    expect(imported.endTime, const EventTimeOfDay(hour: 11, minute: 0));
  });
}
