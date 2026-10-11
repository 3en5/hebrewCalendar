// Tests for recurring_edit.dart (M9): editing/deleting one occurrence,
// this-and-following, or a whole Hebrew-date series.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/recurrence_expander.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/event/recurring_edit.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/domain/sync/sync_state.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

HebrewDate _d(int year, HebrewMonth month, int day) =>
    HebrewDate(year: year, month: month, day: day);

/// A birthday on כ״ג חשוון, every Hebrew year from תשפ״ה.
final Event _series = Event(
  id: 'series-1',
  ownerUid: 'uid-1',
  calendarId: 'default',
  title: 'יום הולדת',
  hebrewDate: _d(5785, HebrewMonth.cheshvan, 23),
  recurrence: const RecurrenceRule(type: RecurrenceType.hebrewYearly),
  googleSync: const GoogleSyncState(googleEventId: 'g-1', dirty: false),
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

List<HebrewDate> _dates(Event event, int fromYear, int toYear) =>
    occurrencesForEventInRange(
      event: event,
      from: _d(fromYear, HebrewMonth.tishrei, 1),
      to: _d(toYear, HebrewMonth.elul, 29),
      engine: _engine,
    ).map((o) => o.occurrenceDate).toList();

void main() {
  final HebrewDate occ5787 = _d(5787, HebrewMonth.cheshvan, 23);

  test('this occurrence: series skips it, a standalone event replaces it', () {
    final RecurringChangePlan plan = planRecurringEdit(
      series: _series,
      edited: _series.copyWith(title: 'מסיבה', hebrewDate: occ5787),
      occurrenceDate: occ5787,
      scope: RecurringEditScope.thisOccurrence,
      engine: _engine,
    );

    expect(plan.deleteSeries, isFalse);
    expect(plan.updatedSeries!.id, 'series-1');
    expect(_dates(plan.updatedSeries!, 5785, 5789), isNot(contains(occ5787)));
    expect(_dates(plan.updatedSeries!, 5785, 5789), hasLength(4));

    final Event single = plan.newEvent!;
    expect(single.id, isEmpty);
    expect(single.title, 'מסיבה');
    expect(single.hebrewDate, occ5787);
    expect(single.recurrence.type, RecurrenceType.none);
    // A fresh sync state, so it's exported as a new Google event.
    expect(single.googleSync.googleEventId, isNull);
  });

  test('this and following: old series ends, a new one starts there', () {
    final RecurringChangePlan plan = planRecurringEdit(
      series: _series,
      edited: _series.copyWith(title: 'יום הולדת לאמא', hebrewDate: occ5787),
      occurrenceDate: occ5787,
      scope: RecurringEditScope.thisAndFollowing,
      engine: _engine,
    );

    expect(_dates(plan.updatedSeries!, 5785, 5790), <HebrewDate>[
      _d(5785, HebrewMonth.cheshvan, 23),
      _d(5786, HebrewMonth.cheshvan, 23),
    ]);
    final Event next = plan.newEvent!;
    expect(next.title, 'יום הולדת לאמא');
    expect(next.recurrence.type, RecurrenceType.hebrewYearly);
    expect(_dates(next, 5785, 5789), <HebrewDate>[
      occ5787,
      _d(5788, HebrewMonth.cheshvan, 23),
      _d(5789, HebrewMonth.cheshvan, 23),
    ]);
  });

  test('this and following from the first occurrence edits the series', () {
    final RecurringChangePlan plan = planRecurringEdit(
      series: _series,
      edited: _series.copyWith(title: 'חדש'),
      occurrenceDate: _series.hebrewDate,
      scope: RecurringEditScope.thisAndFollowing,
      engine: _engine,
    );

    expect(plan.newEvent, isNull);
    expect(plan.updatedSeries!.id, 'series-1');
    expect(plan.updatedSeries!.title, 'חדש');
  });

  test('exceptions are split between the old and the new series', () {
    final Event withExceptions = _series.copyWith(
      recurrence: _series.recurrence.copyWith(
        exceptions: <HebrewDate>[
          _d(5786, HebrewMonth.cheshvan, 23),
          _d(5788, HebrewMonth.cheshvan, 23),
        ],
      ),
    );
    final RecurringChangePlan plan = planRecurringEdit(
      series: withExceptions,
      edited: withExceptions.copyWith(hebrewDate: occ5787),
      occurrenceDate: occ5787,
      scope: RecurringEditScope.thisAndFollowing,
      engine: _engine,
    );

    expect(plan.updatedSeries!.recurrence.exceptions, <HebrewDate>[
      _d(5786, HebrewMonth.cheshvan, 23),
    ]);
    expect(plan.newEvent!.recurrence.exceptions, <HebrewDate>[
      _d(5788, HebrewMonth.cheshvan, 23),
    ]);
  });

  test('all events rewrites the series in place', () {
    final RecurringChangePlan plan = planRecurringEdit(
      series: _series,
      edited: _series.copyWith(title: 'כולם'),
      occurrenceDate: occ5787,
      scope: RecurringEditScope.allEvents,
      engine: _engine,
    );
    expect(plan.newEvent, isNull);
    expect(plan.updatedSeries!.title, 'כולם');
  });

  group('delete', () {
    test('this occurrence adds an exception', () {
      final RecurringChangePlan plan = planRecurringDelete(
        series: _series,
        occurrenceDate: occ5787,
        scope: RecurringEditScope.thisOccurrence,
        engine: _engine,
      );
      expect(plan.updatedSeries!.recurrence.exceptions, <HebrewDate>[occ5787]);
    });

    test('this and following ends the series the day before', () {
      final RecurringChangePlan plan = planRecurringDelete(
        series: _series,
        occurrenceDate: occ5787,
        scope: RecurringEditScope.thisAndFollowing,
        engine: _engine,
      );
      expect(
        plan.updatedSeries!.recurrence.until,
        _d(5787, HebrewMonth.cheshvan, 22),
      );
      expect(_dates(plan.updatedSeries!, 5785, 5790), hasLength(2));
    });

    test('this and following from the first occurrence deletes it all', () {
      final RecurringChangePlan plan = planRecurringDelete(
        series: _series,
        occurrenceDate: _series.hebrewDate,
        scope: RecurringEditScope.thisAndFollowing,
        engine: _engine,
      );
      expect(plan.deleteSeries, isTrue);
    });

    test('an earlier "until" is kept', () {
      final Event short = _series.copyWith(
        recurrence: _series.recurrence.copyWith(
          until: _d(5786, HebrewMonth.tishrei, 1),
        ),
      );
      final RecurringChangePlan plan = planRecurringDelete(
        series: short,
        occurrenceDate: occ5787,
        scope: RecurringEditScope.thisAndFollowing,
        engine: _engine,
      );
      expect(
        plan.updatedSeries!.recurrence.until,
        _d(5786, HebrewMonth.tishrei, 1),
      );
    });
  });
}
