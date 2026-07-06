import '../hebrew_date/hebrew_date.dart';
import 'event.dart';
import 'event_occurrence.dart';

/// Abstract event storage, defined purely in terms of domain types
/// (ARCHITECTURE.md §3: features/data consume this interface; nothing
/// above the data layer knows whether it's backed by Firestore or memory).
///
/// Implemented by `InMemoryEventRepository` (lib/data) for M2a and widget
/// tests; a Firestore-backed implementation lands in M2b.
abstract class EventRepository {
  /// Streams every occurrence (see [EventOccurrence]) that falls in the
  /// given Hebrew [year]/[month], re-emitting whenever that set changes.
  ///
  /// A non-recurring event contributes at most one [EventOccurrence] (on
  /// its own [Event.hebrewDate]); a recurring event contributes one
  /// [EventOccurrence] per date `recurrence_expander.dart` computes for it
  /// within that month (M3a — ARCHITECTURE.md §4 "materialize nothing,
  /// expand at runtime"). Implementations delegate to
  /// [watchOccurrencesInRange] for the month's `[1, daysInMonth]` range
  /// rather than duplicating the query/expansion logic (M3b).
  Stream<List<EventOccurrence>> watchEventsForHebrewMonth(
    int year,
    HebrewMonth month,
  );

  /// Streams every occurrence that falls within `[from, to]` (both
  /// boundaries inclusive, an arbitrary Hebrew-date range — not
  /// month-shaped), re-emitting whenever that set changes.
  ///
  /// The week/day/agenda views (M3b) use this directly instead of
  /// [watchEventsForHebrewMonth]: a week or a single day rarely aligns with
  /// Hebrew month boundaries, and the agenda view needs a wide rolling
  /// window. Expansion of recurring events follows the exact same
  /// `recurrence_expander.dart` semantics as [watchEventsForHebrewMonth].
  Stream<List<EventOccurrence>> watchOccurrencesInRange(
    HebrewDate from,
    HebrewDate to,
  );

  /// Fetches a single event by id, or null if it doesn't exist.
  Future<Event?> getById(String id);

  /// Persists a new event. Implementations assign the final [Event.id]
  /// (any id on [event] is ignored) and set `createdAt`/`updatedAt`.
  Future<Event> create(Event event);

  /// Persists changes to an existing event (matched by [Event.id]).
  /// Implementations set `updatedAt` and preserve the original `createdAt`.
  Future<Event> update(Event event);

  /// Removes the event with the given id, if it exists.
  Future<void> delete(String id);
}
