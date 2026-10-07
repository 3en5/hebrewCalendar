import '../hebrew_date/hebrew_date.dart';
import '../sync/export_candidate.dart';
import '../sync/remote_event_snapshot.dart';
import '../sync/sync_state.dart';
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
  ///
  /// M5a: if the removed event had any Google sync state
  /// (`Event.googleSync`/`Event.googleInstanceSync`), a [PendingGoogleDeletion]
  /// recording its remote instance(s) is queued (drainable via
  /// [takePendingGoogleDeletions]) so the sync engine can delete them
  /// remotely on its next push — ARCHITECTURE.md §5 "deletions propagate
  /// both ways". Kept in the repository layer (RULES.md §6), not the UI.
  Future<void> delete(String id);

  /// Every one of this repository's events, regardless of Hebrew
  /// date/range — used by the M5a sync engine to find every dirty event to
  /// push, and every event's current Google sync state to reconcile against
  /// an incoming remote snapshot.
  Future<List<Event>> getAllForSync();

  /// The local event whose [Event.googleSync]/[Event.googleInstanceSync]
  /// references [googleEventId], or null if none does — used by the M5a
  /// sync engine's import path to tell "already-imported, check for
  /// changes" apart from "brand new, import it".
  Future<Event?> getByGoogleEventId(String googleEventId);

  /// Records the outcome of a successful export push for [eventId]: updates
  /// [googleSync] (the event's own single sync state, for a non-recurring
  /// event) and/or merges [googleInstanceSync] entries (for a recurring
  /// event's per-occurrence state) without touching any other field —
  /// crucially, without re-marking the event dirty (unlike [update], which
  /// is the user-facing mutation path).
  Future<void> updateSyncState(
    String eventId, {
    GoogleSyncState? googleSync,
    Map<String, GoogleSyncState>? googleInstanceSync,
  });

  /// Drains and returns every [PendingGoogleDeletion] queued by [delete]
  /// since the last call — each call empties the queue, so a deletion is
  /// only ever handed to the sync engine once.
  Future<List<PendingGoogleDeletion>> takePendingGoogleDeletions();

  /// Creates a new local event from an imported Google Calendar [snapshot]
  /// (`source: EventSource.google`), or updates the existing local event
  /// [existingEventId] with it — the M5a sync engine's import-side write
  /// path, used for both [CreateLocalAction] and [UpdateLocalAction].
  Future<Event> upsertFromGoogle(
    RemoteEventSnapshot snapshot, {
    String? existingEventId,
  });

  /// Removes the local event [id] because Google Calendar reported its
  /// counterpart deleted — unlike [delete], this never queues a
  /// [PendingGoogleDeletion] (it is already gone remotely; queuing one would
  /// try to delete it again next push).
  Future<void> applyRemoteDelete(String id);
}
