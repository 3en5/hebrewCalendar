// Unit tests for the pure M4 reminder planner (ARCHITECTURE.md §6): horizon
// filtering, past-skipping, the all-day 09:00 rule, the 60-nearest cap,
// stable-id stability/uniqueness, exact fireAt arithmetic for timed events,
// and Hebrew body formatting. No plugin, no Flutter — see
// docs/RULES.md/ARCHITECTURE.md for why this is the "pure domain planner".

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_occurrence.dart';
import 'package:hebrew_calendar/domain/event/event_time_of_day.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_numerals.dart';
import 'package:hebrew_calendar/domain/notifications/planned_notification.dart';
import 'package:hebrew_calendar/domain/notifications/reminder_planner.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

Event _buildEvent({
  required String id,
  required HebrewDate hebrewDate,
  bool allDay = true,
  EventTimeOfDay? startTime,
  List<int> reminders = const <int>[],
  String title = 'אירוע',
}) {
  final DateTime fixedTimestamp = DateTime(2026, 1, 1);
  return Event(
    id: id,
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: title,
    hebrewDate: hebrewDate,
    allDay: allDay,
    startTime: startTime,
    reminderMinutesBefore: reminders,
    createdAt: fixedTimestamp,
    updatedAt: fixedTimestamp,
  );
}

EventOccurrence _occurrence(Event event) =>
    EventOccurrence(event: event, occurrenceDate: event.hebrewDate);

void main() {
  final DateTime now = DateTime(2026, 1, 10, 8);
  final HebrewDate today = _engine.fromGregorian(now);

  group('fireAt arithmetic', () {
    test('timed event at 14:00 with a 30 minute reminder fires at 13:30', () {
      final Event event = _buildEvent(
        id: 'e1',
        hebrewDate: today,
        allDay: false,
        startTime: const EventTimeOfDay(hour: 14, minute: 0),
        reminders: const <int>[30],
      );

      final List<PlannedNotification> plan = planReminders(
        occurrences: <EventOccurrence>[_occurrence(event)],
        now: now,
        engine: _engine,
      );

      expect(plan, hasLength(1));
      expect(
        plan.single.fireAt,
        DateTime(now.year, now.month, now.day, 13, 30),
      );
    });

    test('all-day event fires at 09:00 local minus minutesBefore', () {
      final Event event = _buildEvent(
        id: 'e2',
        hebrewDate: today,
        reminders: const <int>[60],
      );

      final List<PlannedNotification> plan = planReminders(
        occurrences: <EventOccurrence>[_occurrence(event)],
        now: now,
        engine: _engine,
      );

      expect(plan, hasLength(1));
      expect(plan.single.fireAt, DateTime(now.year, now.month, now.day, 8, 0));
    });

    test(
      'multiple reminder offsets on the same occurrence each get a plan',
      () {
        final Event event = _buildEvent(
          id: 'e3',
          hebrewDate: today,
          allDay: false,
          startTime: const EventTimeOfDay(hour: 20, minute: 0),
          reminders: const <int>[10, 60],
        );

        final List<PlannedNotification> plan = planReminders(
          occurrences: <EventOccurrence>[_occurrence(event)],
          now: now,
          engine: _engine,
        );

        expect(plan, hasLength(2));
        expect(
          plan.map((PlannedNotification p) => p.fireAt),
          containsAll(<DateTime>[
            DateTime(now.year, now.month, now.day, 19, 50),
            DateTime(now.year, now.month, now.day, 19, 0),
          ]),
        );
      },
    );
  });

  group('past skipping', () {
    test('a reminder whose fire time already passed is dropped', () {
      final HebrewDate yesterday = _engine.addDays(today, -1);
      final Event event = _buildEvent(
        id: 'past',
        hebrewDate: yesterday,
        reminders: const <int>[10],
      );

      final List<PlannedNotification> plan = planReminders(
        occurrences: <EventOccurrence>[_occurrence(event)],
        now: now,
        engine: _engine,
      );

      expect(plan, isEmpty);
    });

    test('a reminder firing exactly at now is kept, not treated as past', () {
      final Event event = _buildEvent(
        id: 'now-exact',
        hebrewDate: today,
        allDay: false,
        startTime: const EventTimeOfDay(hour: 8, minute: 0),
        reminders: const <int>[0],
      );

      final List<PlannedNotification> plan = planReminders(
        occurrences: <EventOccurrence>[_occurrence(event)],
        now: now,
        engine: _engine,
      );

      expect(plan, hasLength(1));
      expect(plan.single.fireAt, now);
    });
  });

  group('horizon filtering', () {
    test('an occurrence far beyond the horizon is dropped', () {
      final HebrewDate farFuture = _engine.addDays(today, 100);
      final Event event = _buildEvent(
        id: 'far',
        hebrewDate: farFuture,
        reminders: const <int>[10],
      );

      final List<PlannedNotification> plan = planReminders(
        occurrences: <EventOccurrence>[_occurrence(event)],
        now: now,
        engine: _engine,
        horizon: const Duration(days: 60),
      );

      expect(plan, isEmpty);
    });

    test('a fire time exactly at the horizon boundary is kept', () {
      const Duration horizon = Duration(days: 60);
      final Event event = _buildEvent(
        id: 'boundary',
        hebrewDate: today,
        allDay: false,
        startTime: const EventTimeOfDay(hour: 8, minute: 0),
        reminders: const <int>[
          -((60 * 24 * 60)),
        ], // fires exactly at horizon end
      );

      final List<PlannedNotification> plan = planReminders(
        occurrences: <EventOccurrence>[_occurrence(event)],
        now: now,
        engine: _engine,
        horizon: horizon,
      );

      expect(plan, hasLength(1));
      expect(plan.single.fireAt, now.add(horizon));
    });
  });

  group('cap to 60 nearest', () {
    test('more than 60 candidate reminders are capped to the 60 soonest', () {
      final List<EventOccurrence> occurrences = <EventOccurrence>[
        for (int i = 0; i < 70; i++)
          _occurrence(
            _buildEvent(
              id: 'event-$i',
              hebrewDate: _engine.addDays(today, i ~/ 24),
              allDay: false,
              startTime: EventTimeOfDay(hour: (8 + i) % 24, minute: 0),
              reminders: const <int>[0],
            ),
          ),
      ];

      final List<PlannedNotification> plan = planReminders(
        occurrences: occurrences,
        now: now,
        engine: _engine,
      );

      expect(plan, hasLength(60));
      for (int i = 1; i < plan.length; i++) {
        expect(
          plan[i].fireAt.isAfter(plan[i - 1].fireAt) ||
              plan[i].fireAt.isAtSameMomentAs(plan[i - 1].fireAt),
          isTrue,
        );
      }
    });
  });

  group('stable id', () {
    test('replanning identical input yields identical ids', () {
      final Event event = _buildEvent(
        id: 'stable',
        hebrewDate: today,
        reminders: const <int>[10],
      );
      final List<EventOccurrence> occurrences = <EventOccurrence>[
        _occurrence(event),
      ];

      final int firstId = planReminders(
        occurrences: occurrences,
        now: now,
        engine: _engine,
      ).single.stableId;
      final int secondId = planReminders(
        occurrences: occurrences,
        now: now,
        engine: _engine,
      ).single.stableId;

      expect(firstId, secondId);
      expect(firstId, isNonNegative);
    });

    test('different occurrence dates get different ids', () {
      final int idA = computeStableNotificationId(
        eventId: 'e',
        occurrenceDate: today,
        minutesBefore: 10,
      );
      final int idB = computeStableNotificationId(
        eventId: 'e',
        occurrenceDate: _engine.addDays(today, 1),
        minutesBefore: 10,
      );
      expect(idA, isNot(idB));
    });

    test(
      'different reminder offsets on the same occurrence get different ids',
      () {
        final int idA = computeStableNotificationId(
          eventId: 'e',
          occurrenceDate: today,
          minutesBefore: 10,
        );
        final int idB = computeStableNotificationId(
          eventId: 'e',
          occurrenceDate: today,
          minutesBefore: 30,
        );
        expect(idA, isNot(idB));
      },
    );

    test('different event ids get different ids', () {
      final int idA = computeStableNotificationId(
        eventId: 'e1',
        occurrenceDate: today,
        minutesBefore: 10,
      );
      final int idB = computeStableNotificationId(
        eventId: 'e2',
        occurrenceDate: today,
        minutesBefore: 10,
      );
      expect(idA, isNot(idB));
    });
  });

  group('Hebrew body formatting', () {
    test('timed event body contains title, Hebrew date and time', () {
      final Event event = _buildEvent(
        id: 'body-timed',
        hebrewDate: today,
        allDay: false,
        startTime: const EventTimeOfDay(hour: 14, minute: 5),
        reminders: const <int>[10],
        title: 'פגישה',
      );

      final PlannedNotification notification = planReminders(
        occurrences: <EventOccurrence>[_occurrence(event)],
        now: now,
        engine: _engine,
      ).single;

      final String expectedDate =
          '${hebrewDayNumeral(today.day)} ב${_engine.monthName(today.month)} '
          '${hebrewYearNumeral(today.year)}';
      expect(notification.body, 'פגישה · $expectedDate, 14:05');
    });

    test('all-day event body has no time suffix', () {
      final Event event = _buildEvent(
        id: 'body-allday',
        hebrewDate: today,
        reminders: const <int>[10],
        title: 'חג',
      );

      final PlannedNotification notification = planReminders(
        occurrences: <EventOccurrence>[_occurrence(event)],
        now: now,
        engine: _engine,
      ).single;

      final String expectedDate =
          '${hebrewDayNumeral(today.day)} ב${_engine.monthName(today.month)} '
          '${hebrewYearNumeral(today.year)}';
      expect(notification.body, 'חג · $expectedDate');
    });
  });

  test('the plan is sorted by fireAt ascending', () {
    final Event later = _buildEvent(
      id: 'later',
      hebrewDate: today,
      allDay: false,
      startTime: const EventTimeOfDay(hour: 20, minute: 0),
      reminders: const <int>[0],
    );
    final Event sooner = _buildEvent(
      id: 'sooner',
      hebrewDate: today,
      allDay: false,
      startTime: const EventTimeOfDay(hour: 9, minute: 0),
      reminders: const <int>[0],
    );

    final List<PlannedNotification> plan = planReminders(
      occurrences: <EventOccurrence>[_occurrence(later), _occurrence(sooner)],
      now: now,
      engine: _engine,
    );

    expect(plan.map((PlannedNotification p) => p.fireAt), <DateTime>[
      DateTime(now.year, now.month, now.day, 9, 0),
      DateTime(now.year, now.month, now.day, 20, 0),
    ]);
  });
}
