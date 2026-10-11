import '../hebrew_date/hebrew_date.dart';
import '../hebrew_date/hebrew_date_engine.dart';
import '../sync/sync_state.dart';
import 'event.dart';
import 'recurrence_rule.dart';

/// Which part of a recurring (Hebrew-date) series an edit or delete applies
/// to (M9, ARCHITECTURE.md §11).
enum RecurringEditScope {
  /// Only the occurrence the user picked.
  thisOccurrence,

  /// The picked occurrence and every later one.
  thisAndFollowing,

  /// The whole series, past occurrences included.
  allEvents,
}

/// What to write to carry out an edit/delete on a recurring series.
///
/// Apply in this order: [deleteSeries] or [updatedSeries], then [newEvent].
class RecurringChangePlan {
  const RecurringChangePlan({
    this.updatedSeries,
    this.newEvent,
    this.deleteSeries = false,
  });

  /// The existing series, rewritten (same id) — or null to leave it alone.
  final Event? updatedSeries;

  /// A brand-new event to create (empty id) — or null.
  final Event? newEvent;

  /// Whether to delete the existing series outright.
  final bool deleteSeries;
}

/// Plans an edit of [series] made from its occurrence on [occurrenceDate].
///
/// [edited] is the editor's result: [series] with the user's changes, whose
/// `hebrewDate` is the occurrence's (for [RecurringEditScope.thisOccurrence]
/// and [RecurringEditScope.thisAndFollowing]) or the series anchor (for
/// [RecurringEditScope.allEvents]).
///
/// - **this occurrence**: the series skips [occurrenceDate] (added to its
///   exceptions) and a standalone, non-recurring event takes its place.
/// - **this and following**: the series ends the day before
///   [occurrenceDate]; a new series starts on [occurrenceDate] with the
///   edits, repeating by the same Hebrew rule from there. From the series'
///   first occurrence this is the same as editing all.
/// - **all**: the series itself is rewritten.
RecurringChangePlan planRecurringEdit({
  required Event series,
  required Event edited,
  required HebrewDate occurrenceDate,
  required RecurringEditScope scope,
  required HebrewDateEngine engine,
}) {
  switch (scope) {
    case RecurringEditScope.allEvents:
      return RecurringChangePlan(updatedSeries: edited.copyWith(id: series.id));
    case RecurringEditScope.thisOccurrence:
      return RecurringChangePlan(
        updatedSeries: _withException(series, occurrenceDate),
        newEvent: _asNewEvent(
          edited.copyWith(recurrence: const RecurrenceRule()),
        ),
      );
    case RecurringEditScope.thisAndFollowing:
      if (occurrenceDate <= series.hebrewDate) {
        return RecurringChangePlan(
          updatedSeries: edited.copyWith(id: series.id),
        );
      }
      return RecurringChangePlan(
        updatedSeries: _endBefore(series, occurrenceDate, engine),
        newEvent: _asNewEvent(
          edited.copyWith(
            recurrence: edited.recurrence.copyWith(
              exceptions: edited.recurrence.exceptions
                  .where((HebrewDate d) => d >= occurrenceDate)
                  .toList(),
            ),
          ),
        ),
      );
  }
}

/// Plans deleting part of [series], from its occurrence on [occurrenceDate].
///
/// - **this occurrence**: added to the series' exceptions.
/// - **this and following**: the series ends the day before; from its first
///   occurrence that deletes the whole series.
/// - **all**: the series is deleted.
RecurringChangePlan planRecurringDelete({
  required Event series,
  required HebrewDate occurrenceDate,
  required RecurringEditScope scope,
  required HebrewDateEngine engine,
}) {
  switch (scope) {
    case RecurringEditScope.allEvents:
      return const RecurringChangePlan(deleteSeries: true);
    case RecurringEditScope.thisOccurrence:
      return RecurringChangePlan(
        updatedSeries: _withException(series, occurrenceDate),
      );
    case RecurringEditScope.thisAndFollowing:
      if (occurrenceDate <= series.hebrewDate) {
        return const RecurringChangePlan(deleteSeries: true);
      }
      return RecurringChangePlan(
        updatedSeries: _endBefore(series, occurrenceDate, engine),
      );
  }
}

Event _withException(Event series, HebrewDate date) => series.copyWith(
  recurrence: series.recurrence.copyWith(
    exceptions: <HebrewDate>{...series.recurrence.exceptions, date}.toList(),
  ),
);

/// [series] cut to end the day before [date] (keeping an earlier `until`),
/// dropping exceptions that no longer fall inside it.
Event _endBefore(Event series, HebrewDate date, HebrewDateEngine engine) {
  final HebrewDate lastDay = engine.addDays(date, -1);
  final HebrewDate? until = series.recurrence.until;
  return series.copyWith(
    recurrence: series.recurrence.copyWith(
      until: until != null && until < lastDay ? until : lastDay,
      exceptions: series.recurrence.exceptions
          .where((HebrewDate d) => d <= lastDay)
          .toList(),
    ),
  );
}

/// [event] as a new, never-synced event: no id and a fresh Google sync
/// state, so the sync engine exports it as a new Google event instead of
/// overwriting the series' ones.
Event _asNewEvent(Event event) => event.copyWith(
  id: '',
  googleSync: const GoogleSyncState(),
  googleInstanceSync: const <String, GoogleSyncState>{},
);
