// Tests for the M4 orchestrator: `EventRepository.watchOccurrencesInRange`
// -> `planReminders` -> `NotificationScheduler`, using an in-memory
// repository and a fake scheduler (ARCHITECTURE.md §6 — the orchestrator is
// tested with fakes, never a real `flutter_local_notifications` plugin).

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/notifications/planned_notification.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_sync_service.dart';

import '../../../test_support/fake_notification_scheduler.dart';

const HebrewDateEngine _engine = HebrewDateEngine();
final DateTime _now = DateTime(2026, 1, 10, 8);
final HebrewDate _today = _engine.fromGregorian(_now);

Event _event({
  required String id,
  required List<int> reminders,
  EventTimeOfDay? startTime,
}) => Event(
  id: id,
  ownerUid: 'uid-1',
  calendarId: 'default',
  title: 'פגישה',
  hebrewDate: _today,
  allDay: startTime == null,
  startTime: startTime,
  reminderMinutesBefore: reminders,
  createdAt: _now,
  updatedAt: _now,
);

/// Waits long enough for the service's debounce timer (set well below this
/// in every test here) to have fired and its async replan to complete.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

void main() {
  late InMemoryEventRepository repository;
  late FakeNotificationScheduler scheduler;
  late ReminderSyncService service;

  setUp(() {
    repository = InMemoryEventRepository(now: () => _now);
    scheduler = FakeNotificationScheduler();
    service = ReminderSyncService(
      repository: repository,
      scheduler: scheduler,
      engine: _engine,
      now: () => _now,
      debounce: const Duration(milliseconds: 10),
    );
  });

  tearDown(() {
    repository.dispose();
  });

  test('starting initializes the scheduler', () async {
    await service.start();
    await _settle();
    expect(scheduler.initializeCallCount, 1);
    await service.stop();
  });

  test('creating an event with a reminder schedules it', () async {
    await service.start();
    await repository.create(
      _event(
        id: '',
        startTime: const EventTimeOfDay(hour: 14, minute: 0),
        reminders: const <int>[30],
      ),
    );
    await _settle();

    expect(scheduler.currentlyScheduled, hasLength(1));
    expect(
      scheduler.currentlyScheduled.single.fireAt,
      DateTime(_now.year, _now.month, _now.day, 13, 30),
    );
    await service.stop();
  });

  test('editing an event reschedules with the new fire time', () async {
    await service.start();
    final Event created = await repository.create(
      _event(
        id: '',
        startTime: const EventTimeOfDay(hour: 14, minute: 0),
        reminders: const <int>[30],
      ),
    );
    await _settle();
    expect(
      scheduler.currentlyScheduled.single.fireAt,
      DateTime(_now.year, _now.month, _now.day, 13, 30),
    );

    await repository.update(
      created.copyWith(startTime: const EventTimeOfDay(hour: 18, minute: 0)),
    );
    await _settle();

    expect(scheduler.currentlyScheduled, hasLength(1));
    expect(
      scheduler.currentlyScheduled.single.fireAt,
      DateTime(_now.year, _now.month, _now.day, 17, 30),
    );
    await service.stop();
  });

  test('deleting an event cancels its reminder', () async {
    await service.start();
    final Event created = await repository.create(
      _event(
        id: '',
        startTime: const EventTimeOfDay(hour: 14, minute: 0),
        reminders: const <int>[30],
      ),
    );
    await _settle();
    expect(scheduler.currentlyScheduled, hasLength(1));

    await repository.delete(created.id);
    await _settle();

    expect(scheduler.currentlyScheduled, isEmpty);
    await service.stop();
  });

  test(
    'stop cancels the subscription and every scheduled notification',
    () async {
      await service.start();
      await repository.create(
        _event(
          id: '',
          startTime: const EventTimeOfDay(hour: 14, minute: 0),
          reminders: const <int>[30],
        ),
      );
      await _settle();
      expect(scheduler.currentlyScheduled, hasLength(1));

      await service.stop();
      expect(scheduler.cancelAllCallCount, 1);

      final List<List<PlannedNotification>> callsBeforeMutation = List.of(
        scheduler.showScheduledCalls,
      );

      // A repository change after `stop()` must not reach the scheduler —
      // the subscription was cancelled (RULES.md §6.1).
      await repository.create(
        _event(id: '', startTime: null, reminders: const <int>[10]),
      );
      await _settle();

      expect(scheduler.showScheduledCalls, callsBeforeMutation);
    },
  );
}
