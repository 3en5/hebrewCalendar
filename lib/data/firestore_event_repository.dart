import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/event/event.dart';
import '../domain/event/event_attendee.dart';
import '../domain/event/event_occurrence.dart';
import '../domain/event/event_repository.dart';
import '../domain/event/recurrence_expander.dart';
import '../domain/hebrew_date/hebrew_date.dart';
import '../domain/hebrew_date/hebrew_date_engine.dart';
import '../domain/sync/export_candidate.dart';
import '../domain/sync/remote_event_snapshot.dart';
import '../domain/sync/sync_state.dart';
import 'event_firestore_mapper.dart';
import 'firestore_event_sync_support.dart';

/// [EventRepository] backed by the `events` root Firestore collection
/// (ARCHITECTURE.md §4), scoped to a single signed-in [ownerUid].
///
/// Every document this instance creates/updates has its `ownerUid`
/// overwritten with [ownerUid] regardless of what's on the passed-in
/// [Event] — callers (the event editor) never need to know the signed-in
/// uid themselves; ownership is enforced here and mirrored by
/// `firebase/firestore.rules` (`request.auth.uid == request.resource.data.ownerUid`).
///
/// `createdAt`/`updatedAt` are written as `FieldValue.serverTimestamp()` —
/// the authoritative values live on the server. The [Event] returned from
/// [create]/[update] approximates them with the local clock so the caller
/// gets an immediately-usable object without a round trip; the real values
/// sync back down through [watchEventsForHebrewMonth] once the write is
/// acknowledged (see `docs/LESSONS.md`).
class FirestoreEventRepository implements EventRepository {
  FirestoreEventRepository({
    required this.ownerUid,
    FirebaseFirestore? firestore,
    HebrewDateEngine engine = const HebrewDateEngine(),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _engine = engine,
       _sync = FirestoreEventSyncSupport(
         firestore: firestore ?? FirebaseFirestore.instance,
         ownerUid: ownerUid,
         engine: engine,
       );

  final String ownerUid;
  final FirebaseFirestore _firestore;
  final HebrewDateEngine _engine;

  /// M5a sync-support methods (`getAllForSync`/`updateSyncState`/etc.) live
  /// in a separate helper class, not inline here — RULES.md §2, a
  /// sync-aware repository combining CRUD/watch/sync in one file would
  /// exceed 500 lines.
  final FirestoreEventSyncSupport _sync;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  /// Delegates to [watchOccurrencesInRange] for the month's `[1,
  /// daysInMonth]` range (M3b) rather than duplicating the query/merge
  /// logic.
  @override
  Stream<List<EventOccurrence>> watchEventsForHebrewMonth(
    int year,
    HebrewMonth month,
  ) {
    final HebrewDate from = HebrewDate(year: year, month: month, day: 1);
    final HebrewDate to = HebrewDate(
      year: year,
      month: month,
      day: _engine.daysInMonth(year, month),
    );
    return watchOccurrencesInRange(from, to);
  }

  /// M3a: a recurring event's `gregorianStart` only reflects its anchor
  /// date, which may fall in a completely different month/range than an
  /// occurrence being displayed — so recurring events can't be filtered by
  /// [from]/[to]'s Gregorian range server-side. Instead this combines two
  /// queries: non-recurring events within that Gregorian range (as before,
  /// `isRecurring == false` added so recurring events aren't
  /// double-counted), and *all* of this user's recurring events
  /// (`isRecurring == true`, unfiltered by date — there are only ever as
  /// many of these as the user has created series), expanding the latter
  /// into occurrences for `[from, to]` via `recurrence_expander.dart` — the
  /// same expansion `InMemoryEventRepository` uses (M3b — generalized from
  /// a single Hebrew month to an arbitrary range for the week/day/agenda
  /// views).
  @override
  Stream<List<EventOccurrence>> watchOccurrencesInRange(
    HebrewDate from,
    HebrewDate to,
  ) {
    final DateTime start = _engine.toGregorian(from);
    final DateTime toDay = _engine.toGregorian(to);
    // Exclusive upper bound: the calendar day after `to` at midnight. Built
    // via the `DateTime` constructor (which normalizes an out-of-range day
    // field, e.g. day 32, into the following month) rather than `add(const
    // Duration(days: 1))`, since only the calendar day matters here — no
    // `Duration` arithmetic across a possible daylight-saving transition
    // (see docs/LESSONS.md, M3a) is needed for a single +1 day step.
    final DateTime endExclusive = DateTime(
      toDay.year,
      toDay.month,
      toDay.day + 1,
    );
    final Stream<List<Event>> nonRecurring = _events
        .where('ownerUid', isEqualTo: ownerUid)
        .where('isRecurring', isEqualTo: false)
        .where(
          'gregorianStart',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where('gregorianStart', isLessThan: Timestamp.fromDate(endExclusive))
        .orderBy('gregorianStart')
        .snapshots()
        .map(_mapDocs);
    final Stream<List<Event>> recurring = _events
        .where('ownerUid', isEqualTo: ownerUid)
        .where('isRecurring', isEqualTo: true)
        .snapshots()
        .map(_mapDocs);

    return _combineAndExpand(nonRecurring, recurring, from, to);
  }

  static List<Event> _mapDocs(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                eventFromFirestoreData(doc.id, doc.data()),
          )
          .toList();

  /// Combines the latest values of [nonRecurringStream] and
  /// [recurringStream] (expanding the latter for `[from, to]`) into one
  /// merged, sorted [EventOccurrence] stream — re-emitting whenever either
  /// source updates. Both `snapshots()` streams are broadcast streams that
  /// replay their current server/cache state to a new listener (unlike the
  /// bare in-memory `StreamController` documented in `docs/LESSONS.md`), so
  /// no special first-emission handling is needed here beyond waiting for
  /// both sides to have emitted at least once.
  Stream<List<EventOccurrence>> _combineAndExpand(
    Stream<List<Event>> nonRecurringStream,
    Stream<List<Event>> recurringStream,
    HebrewDate from,
    HebrewDate to,
  ) {
    late final StreamController<List<EventOccurrence>> controller;
    List<Event>? latestNonRecurring;
    List<Event>? latestRecurring;
    StreamSubscription<List<Event>>? nonRecurringSub;
    StreamSubscription<List<Event>>? recurringSub;

    void emitIfReady() {
      final List<Event>? nonRecurring = latestNonRecurring;
      final List<Event>? recurring = latestRecurring;
      if (nonRecurring == null || recurring == null) {
        return;
      }
      final List<EventOccurrence> merged = <EventOccurrence>[
        for (final Event event in nonRecurring)
          EventOccurrence(event: event, occurrenceDate: event.hebrewDate),
        for (final Event event in recurring)
          ...occurrencesForEventInRange(
            event: event,
            from: from,
            to: to,
            engine: _engine,
          ),
      ]..sort(compareEventOccurrences);
      controller.add(merged);
    }

    controller = StreamController<List<EventOccurrence>>.broadcast(
      onListen: () {
        nonRecurringSub = nonRecurringStream.listen((List<Event> events) {
          latestNonRecurring = events;
          emitIfReady();
        });
        recurringSub = recurringStream.listen((List<Event> events) {
          latestRecurring = events;
          emitIfReady();
        });
      },
      onCancel: () {
        unawaited(nonRecurringSub?.cancel());
        unawaited(recurringSub?.cancel());
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }

  @override
  Future<Event?> getById(String id) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _events
        .doc(id)
        .get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return null;
    }
    return eventFromFirestoreData(snapshot.id, data);
  }

  @override
  Future<Event> create(Event event) async {
    final DateTime now = DateTime.now();
    // A newly-created event always needs exporting (M5a: repository update
    // hook, RULES.md §6 — kept here, not in UI callers).
    final Event toStore = event.copyWith(
      ownerUid: ownerUid,
      createdAt: now,
      updatedAt: now,
      googleSync: event.googleSync.copyWith(dirty: true),
    );
    final DocumentReference<Map<String, dynamic>> docRef = _events.doc();
    final Map<String, dynamic> data =
        eventToFirestoreData(event: toStore, engine: _engine)
          ..['createdAt'] = FieldValue.serverTimestamp()
          ..['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.set(data);
    _notifyLocalEdit();
    return toStore.copyWith(id: docRef.id);
  }

  @override
  Future<Event> update(Event event) async {
    final DocumentReference<Map<String, dynamic>> docRef = _events.doc(
      event.id,
    );
    final DocumentSnapshot<Map<String, dynamic>> existing = await docRef.get();
    final Map<String, dynamic>? existingData = existing.data();
    if (existingData == null) {
      throw StateError('No event with id "${event.id}" exists.');
    }
    final DateTime createdAt =
        (existingData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    // Every local edit marks the event dirty again (M5a repository hook) —
    // only `updateSyncState` (used exclusively by the sync engine) may
    // leave `dirty` alone.
    final Event toStore = event.copyWith(
      ownerUid: ownerUid,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      googleSync: event.googleSync.copyWith(dirty: true),
    );
    final Map<String, dynamic> data =
        eventToFirestoreData(event: toStore, engine: _engine)
          ..['updatedAt'] = FieldValue.serverTimestamp()
          ..remove('createdAt');
    await docRef.update(data);
    _notifyLocalEdit();
    return toStore;
  }

  @override
  Future<void> delete(String id) async {
    final DocumentReference<Map<String, dynamic>> docRef = _events.doc(id);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data != null) {
      await _sync.enqueuePendingDeletionIfNeeded(
        eventFromFirestoreData(snapshot.id, data),
      );
    }
    await docRef.delete();
    _notifyLocalEdit();
  }

  @override
  Future<List<Event>> getAllForSync() => _sync.getAllForSync();

  @override
  Future<List<Event>> getDirtyForSync() => _sync.getDirtyForSync();

  final StreamController<void> _localEdits = StreamController<void>.broadcast();

  @override
  Stream<void> get localEdits => _localEdits.stream;

  void _notifyLocalEdit() {
    if (!_localEdits.isClosed) {
      _localEdits.add(null);
    }
  }

  /// Closes [localEdits] (RULES.md §6.1) — called when the provider that
  /// built this repository is disposed (e.g. on sign-out).
  void dispose() {
    unawaited(_localEdits.close());
  }

  @override
  Future<Event?> getByGoogleEventId(String googleEventId) =>
      _sync.getByGoogleEventId(googleEventId);

  @override
  Future<void> updateAttendeeResponses(
    String eventId,
    List<EventAttendee> fromGoogle,
  ) => _sync.updateAttendeeResponses(eventId, fromGoogle);

  @override
  Future<void> updateSyncState(
    String eventId, {
    GoogleSyncState? googleSync,
    Map<String, GoogleSyncState>? googleInstanceSync,
  }) => _sync.updateSyncState(
    eventId,
    googleSync: googleSync,
    googleInstanceSync: googleInstanceSync,
  );

  @override
  Future<List<PendingGoogleDeletion>> takePendingGoogleDeletions() =>
      _sync.takePendingGoogleDeletions();

  @override
  Future<Event> upsertFromGoogle(
    RemoteEventSnapshot snapshot, {
    String? existingEventId,
  }) => _sync.upsertFromGoogle(snapshot, existingEventId: existingEventId);

  @override
  Future<void> applyRemoteDelete(String id) => _sync.applyRemoteDelete(id);
}
