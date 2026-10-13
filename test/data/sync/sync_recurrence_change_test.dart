// Device report 2026-10-13: an event that changes between single and
// recurring must not leave its old Google copies behind as duplicates.

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

  Future<Event> create(RecurrenceType type) => repository.create(
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

  test('single -> yearly removes the single Google event', () async {
    final Event single = await create(RecurrenceType.none);
    await engine.runSync();
    final String? singleId = (await repository.getById(
      single.id,
    ))!.googleSync.googleEventId;
    expect(singleId, isNotNull);

    final Event current = (await repository.getById(single.id))!;
    await repository.update(
      current.copyWith(
        recurrence: const RecurrenceRule(type: RecurrenceType.hebrewYearly),
      ),
    );
    await engine.runSync();

    expect(api.deletedEventIds, contains(singleId));
    final Event synced = (await repository.getById(single.id))!;
    expect(synced.googleSync.googleEventId, isNull);
    expect(synced.googleInstanceSync, hasLength(5));
  });

  test('yearly -> single removes the series instances', () async {
    final Event series = await create(RecurrenceType.hebrewYearly);
    await engine.runSync();
    final Set<String> instanceIds = <String>{
      for (final s in (await repository.getById(
        series.id,
      ))!.googleInstanceSync.values)
        s.googleEventId!,
    };
    expect(instanceIds, hasLength(5));

    final Event current = (await repository.getById(series.id))!;
    await repository.update(
      current.copyWith(recurrence: const RecurrenceRule()),
    );
    await engine.runSync();

    final Event synced = (await repository.getById(series.id))!;
    final String? singleId = synced.googleSync.googleEventId;
    expect(singleId, isNotNull);
    // Every old instance is gone except one the single event may reuse.
    expect(
      instanceIds.difference(<String>{...api.deletedEventIds, singleId!}),
      isEmpty,
    );
    expect(
      synced.googleInstanceSync.values.every((s) => s.googleEventId == null),
      isTrue,
    );
  });
}
