import '../hebrew_date/hebrew_date.dart';
import 'event.dart';

/// Abstract event storage, defined purely in terms of domain types
/// (ARCHITECTURE.md §3: features/data consume this interface; nothing
/// above the data layer knows whether it's backed by Firestore or memory).
///
/// Implemented by `InMemoryEventRepository` (lib/data) for M2a and widget
/// tests; a Firestore-backed implementation lands in M2b.
abstract class EventRepository {
  /// Streams every event whose [Event.hebrewDate] falls in the given
  /// Hebrew [year]/[month], re-emitting whenever that set changes.
  Stream<List<Event>> watchEventsForHebrewMonth(int year, HebrewMonth month);

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
