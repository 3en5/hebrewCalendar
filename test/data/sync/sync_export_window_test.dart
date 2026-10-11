// The export window and its rolling top-up (owner request, 2026-10-11):
// yearly/monthly series go five years ahead to Google, weekly/daily two,
// and a series nobody edits still gets its later instances created.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/data/sync/sync_engine.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';

import '../../test_support/fake_google_calendar_api.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

void main() {
  late DateTime now;
  late InMemoryEventRepository repository;
  late FakeGoogleCalendarApi api;
  late SyncEngine engine;

  setUp(() async {
    now = DateTime(2026, 6, 15, 9);
    repository = InMemoryEventRepository(now: () => now);
    api = FakeGoogleCalendarApi();
    final InMemorySyncSettingsStore settingsStore = InMemorySyncSettingsStore();
    await settingsStore.setEnabled(true);
    engine = SyncEngine(
      repository: repository,
      api: api,
      settingsStore: settingsStore,
      engine: _engine,
      now: () => now,
    );
  });

  tearDown(() => repository.dispose());

  Future<Event> createSeries(RecurrenceType type) => repository.create(
    Event(
      id: '',
      ownerUid: 'uid-1',
      calendarId: 'default',
      title: 'יום הולדת',
      hebrewDate: const HebrewDate(
        year: 5786,
        month: HebrewMonth.tevet,
        day: 10,
      ),
      recurrence: RecurrenceRule(type: type),
      createdAt: now,
      updatedAt: now,
    ),
  );

  test('a yearly series is exported five years ahead', () async {
    final Event series = await createSeries(RecurrenceType.hebrewYearly);

    await engine.runSync();

    // June 2026 + 5 years: 10 Tevet 5787..5791.
    expect(api.insertedEvents, hasLength(5));
    final Event? synced = await repository.getById(series.id);
    expect(synced?.googleInstanceSync, hasLength(5));
  });

  test('a weekly series stays at two years', () async {
    await createSeries(RecurrenceType.weekly);

    await engine.runSync();

    expect(api.insertedEvents.length, inInclusiveRange(103, 106));
  });

  test('an unedited yearly series is topped up once an instance is within '
      'a year of the window end, without re-creating existing ones', () async {
    final Event series = await createSeries(RecurrenceType.hebrewYearly);
    await engine.runSync();
    expect(api.insertedEvents, hasLength(5));

    // A year later the next missing instance (Tevet 5792, Dec 2031) is
    // still more than four years away: nothing to do yet.
    now = DateTime(2027, 6, 15, 9);
    await engine.runSync();
    expect(api.insertedEvents, hasLength(5));

    // Early 2028 it comes within four years: the series is filled up to
    // five years (Tevet 5792 and 5793).
    now = DateTime(2028, 1, 15, 9);
    await engine.runSync();
    expect(api.insertedEvents, hasLength(7));
    final Event? synced = await repository.getById(series.id);
    expect(synced?.googleSync.dirty, isFalse);
    expect(synced?.googleInstanceSync, hasLength(7));

    // Nothing further on the next pass.
    await engine.runSync();
    expect(api.insertedEvents, hasLength(7));
  });
}
