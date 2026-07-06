// Unit tests for InMemoryEventRepository: create/update/delete and the
// watchEventsForHebrewMonth stream's emissions on each mutation.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_occurrence.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';

const HebrewDate _tishrei5 = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 5,
);

Event _draftEvent({String title = 'אירוע', HebrewDate hebrewDate = _tishrei5}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Event(
    id: 'ignored-on-create',
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: title,
    hebrewDate: hebrewDate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late InMemoryEventRepository repository;
  int idCounter = 0;

  setUp(() {
    idCounter = 0;
    repository = InMemoryEventRepository(
      idGenerator: () => 'test-event-${idCounter++}',
      now: () => DateTime(2026, 7, 6),
    );
  });

  tearDown(() {
    repository.dispose();
  });

  group('create', () {
    test('assigns a repository-generated id, ignoring the given one', () async {
      final Event created = await repository.create(_draftEvent());
      expect(created.id, 'test-event-0');
    });

    test('sets createdAt and updatedAt to the same timestamp', () async {
      final Event created = await repository.create(_draftEvent());
      expect(created.createdAt, DateTime(2026, 7, 6));
      expect(created.updatedAt, DateTime(2026, 7, 6));
    });

    test('is retrievable via getById', () async {
      final Event created = await repository.create(_draftEvent());
      final Event? fetched = await repository.getById(created.id);
      expect(fetched, created);
    });
  });

  group('update', () {
    test('overwrites fields and bumps updatedAt but keeps createdAt', () async {
      repository = InMemoryEventRepository(
        idGenerator: () => 'test-event-${idCounter++}',
        now: () {
          idCounter++;
          return idCounter == 1 ? DateTime(2026, 1, 1) : DateTime(2026, 1, 2);
        },
      );
      final Event created = await repository.create(_draftEvent());
      final Event updated = await repository.update(
        created.copyWith(title: 'כותרת חדשה'),
      );
      expect(updated.title, 'כותרת חדשה');
      expect(updated.createdAt, created.createdAt);
      expect(updated.updatedAt, isNot(created.createdAt));
    });

    test('throws for an id that does not exist', () async {
      expect(
        () => repository.update(_draftEvent().copyWith(id: 'missing')),
        throwsStateError,
      );
    });
  });

  group('delete', () {
    test('removes an existing event', () async {
      final Event created = await repository.create(_draftEvent());
      await repository.delete(created.id);
      expect(await repository.getById(created.id), isNull);
    });

    test('is a no-op for an id that does not exist', () async {
      await repository.delete('does-not-exist');
      // No exception thrown is the assertion.
    });
  });

  group('watchEventsForHebrewMonth', () {
    test('emits an empty list before anything is created', () async {
      final List<EventOccurrence> first = await repository
          .watchEventsForHebrewMonth(_tishrei5.year, _tishrei5.month)
          .first;
      expect(first, isEmpty);
    });

    test('emits the new event after create', () async {
      final Stream<List<EventOccurrence>> stream = repository
          .watchEventsForHebrewMonth(_tishrei5.year, _tishrei5.month);
      final Future<List<List<EventOccurrence>>> emissions = stream
          .take(2)
          .toList();
      await repository.create(_draftEvent());
      final List<List<EventOccurrence>> results = await emissions;
      expect(results.first, isEmpty);
      expect(results.last, hasLength(1));
      expect(results.last.single.event.title, 'אירוע');
      expect(results.last.single.occurrenceDate, _tishrei5);
    });

    test('does not include events from a different Hebrew month', () async {
      await repository.create(
        _draftEvent(
          hebrewDate: const HebrewDate(
            year: 5786,
            month: HebrewMonth.cheshvan,
            day: 5,
          ),
        ),
      );
      final List<EventOccurrence> tishreiEvents = await repository
          .watchEventsForHebrewMonth(_tishrei5.year, _tishrei5.month)
          .first;
      expect(tishreiEvents, isEmpty);
    });

    test('reflects an update', () async {
      final Event created = await repository.create(_draftEvent());
      final Stream<List<EventOccurrence>> stream = repository
          .watchEventsForHebrewMonth(_tishrei5.year, _tishrei5.month);
      final Future<List<List<EventOccurrence>>> emissions = stream
          .take(2)
          .toList();
      await repository.update(created.copyWith(title: 'עודכן'));
      final List<List<EventOccurrence>> results = await emissions;
      expect(results.last.single.event.title, 'עודכן');
    });

    test('reflects a delete', () async {
      final Event created = await repository.create(_draftEvent());
      final Stream<List<EventOccurrence>> stream = repository
          .watchEventsForHebrewMonth(_tishrei5.year, _tishrei5.month);
      final Future<List<List<EventOccurrence>>> emissions = stream
          .take(2)
          .toList();
      await repository.delete(created.id);
      final List<List<EventOccurrence>> results = await emissions;
      expect(results.first, hasLength(1));
      expect(results.last, isEmpty);
    });

    test(
      'expands a recurring event into occurrences across later months',
      () async {
        final Event created = await repository.create(
          _draftEvent().copyWith(
            recurrence: const RecurrenceRule(
              type: RecurrenceType.hebrewMonthly,
            ),
          ),
        );
        final List<EventOccurrence> nextMonth = await repository
            .watchEventsForHebrewMonth(5786, HebrewMonth.cheshvan)
            .first;
        expect(nextMonth, hasLength(1));
        expect(nextMonth.single.event.id, created.id);
        expect(
          nextMonth.single.occurrenceDate,
          const HebrewDate(year: 5786, month: HebrewMonth.cheshvan, day: 5),
        );
      },
    );

    test(
      'adding an occurrence date to exceptions removes just that occurrence',
      () async {
        final Event created = await repository.create(
          _draftEvent().copyWith(
            recurrence: const RecurrenceRule(
              type: RecurrenceType.hebrewMonthly,
            ),
          ),
        );
        await repository.update(
          created.copyWith(
            recurrence: const RecurrenceRule(
              type: RecurrenceType.hebrewMonthly,
              exceptions: <HebrewDate>[
                HebrewDate(year: 5786, month: HebrewMonth.cheshvan, day: 5),
              ],
            ),
          ),
        );

        final List<EventOccurrence> tishreiEvents = await repository
            .watchEventsForHebrewMonth(_tishrei5.year, _tishrei5.month)
            .first;
        final List<EventOccurrence> cheshvanEvents = await repository
            .watchEventsForHebrewMonth(5786, HebrewMonth.cheshvan)
            .first;
        expect(tishreiEvents, hasLength(1));
        expect(cheshvanEvents, isEmpty);
      },
    );
  });

  group('watchOccurrencesInRange (M3b)', () {
    test('emits an empty list before anything is created', () async {
      final List<EventOccurrence> first = await repository
          .watchOccurrencesInRange(_tishrei5, _tishrei5)
          .first;
      expect(first, isEmpty);
    });

    test('a range straddling a Hebrew month boundary returns occurrences from '
        'both months, in chronological order', () async {
      await repository.create(
        _draftEvent(
          title: 'סוף תשרי',
          hebrewDate: const HebrewDate(
            year: 5786,
            month: HebrewMonth.tishrei,
            day: 29,
          ),
        ),
      );
      await repository.create(
        _draftEvent(
          title: 'תחילת חשוון',
          hebrewDate: const HebrewDate(
            year: 5786,
            month: HebrewMonth.cheshvan,
            day: 2,
          ),
        ),
      );
      // Falls outside the queried range below (Tishrei 20).
      await repository.create(
        _draftEvent(
          title: 'לא רלוונטי',
          hebrewDate: const HebrewDate(
            year: 5786,
            month: HebrewMonth.tishrei,
            day: 20,
          ),
        ),
      );

      final List<EventOccurrence> occurrences = await repository
          .watchOccurrencesInRange(
            const HebrewDate(year: 5786, month: HebrewMonth.tishrei, day: 28),
            const HebrewDate(year: 5786, month: HebrewMonth.cheshvan, day: 3),
          )
          .first;

      expect(
        occurrences.map((EventOccurrence o) => o.event.title).toList(),
        <String>['סוף תשרי', 'תחילת חשוון'],
      );
    });

    test(
      'expands a recurring event across the range, respecting exceptions',
      () async {
        final Event created = await repository.create(
          _draftEvent().copyWith(
            recurrence: const RecurrenceRule(
              type: RecurrenceType.hebrewMonthly,
              exceptions: <HebrewDate>[
                HebrewDate(year: 5786, month: HebrewMonth.kislev, day: 5),
              ],
            ),
          ),
        );

        final List<EventOccurrence> occurrences = await repository
            .watchOccurrencesInRange(
              _tishrei5,
              const HebrewDate(year: 5786, month: HebrewMonth.tevet, day: 5),
            )
            .first;

        expect(
          occurrences.map((EventOccurrence o) => o.occurrenceDate).toList(),
          <HebrewDate>[
            _tishrei5,
            const HebrewDate(year: 5786, month: HebrewMonth.cheshvan, day: 5),
            // Kislev 5 is skipped: it's an exception.
            const HebrewDate(year: 5786, month: HebrewMonth.tevet, day: 5),
          ],
        );
        expect(
          occurrences.every((EventOccurrence o) => o.event.id == created.id),
          isTrue,
        );
      },
    );

    test('watchEventsForHebrewMonth delegates to the same expansion as an '
        'equivalent watchOccurrencesInRange call', () async {
      await repository.create(_draftEvent());
      final List<EventOccurrence> viaMonth = await repository
          .watchEventsForHebrewMonth(_tishrei5.year, _tishrei5.month)
          .first;
      final List<EventOccurrence> viaRange = await repository
          .watchOccurrencesInRange(
            const HebrewDate(year: 5786, month: HebrewMonth.tishrei, day: 1),
            const HebrewDate(year: 5786, month: HebrewMonth.tishrei, day: 30),
          )
          .first;
      expect(viaMonth, viaRange);
    });
  });
}
