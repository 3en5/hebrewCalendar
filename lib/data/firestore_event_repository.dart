import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/event/event.dart';
import '../domain/event/event_occurrence.dart';
import '../domain/event/event_repository.dart';
import '../domain/event/recurrence_expander.dart';
import '../domain/hebrew_date/hebrew_date.dart';
import '../domain/hebrew_date/hebrew_date_engine.dart';
import 'event_firestore_mapper.dart';

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
       _engine = engine;

  final String ownerUid;
  final FirebaseFirestore _firestore;
  final HebrewDateEngine _engine;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  /// M3a: a recurring event's `gregorianStart` only reflects its anchor
  /// date, which may fall in a completely different month than an
  /// occurrence being displayed — so recurring events can't be filtered by
  /// the displayed month's Gregorian range server-side. Instead this
  /// combines two queries: non-recurring events within the month's
  /// Gregorian range (as before, `isRecurring == false` added so recurring
  /// events aren't double-counted), and *all* of this user's recurring
  /// events (`isRecurring == true`, unfiltered by date — there are only
  /// ever as many of these as the user has created series), expanding the
  /// latter into occurrences for [year]/[month] via `recurrence_expander.dart`
  /// — the same expansion `InMemoryEventRepository` uses.
  @override
  Stream<List<EventOccurrence>> watchEventsForHebrewMonth(
    int year,
    HebrewMonth month,
  ) {
    final ({DateTime start, DateTime endExclusive}) range =
        hebrewMonthGregorianRange(_engine, year, month);
    final Stream<List<Event>> nonRecurring = _events
        .where('ownerUid', isEqualTo: ownerUid)
        .where('isRecurring', isEqualTo: false)
        .where(
          'gregorianStart',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where(
          'gregorianStart',
          isLessThan: Timestamp.fromDate(range.endExclusive),
        )
        .orderBy('gregorianStart')
        .snapshots()
        .map(_mapDocs);
    final Stream<List<Event>> recurring = _events
        .where('ownerUid', isEqualTo: ownerUid)
        .where('isRecurring', isEqualTo: true)
        .snapshots()
        .map(_mapDocs);

    return _combineAndExpand(nonRecurring, recurring, year, month);
  }

  static List<Event> _mapDocs(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                eventFromFirestoreData(doc.id, doc.data()),
          )
          .toList();

  /// Combines the latest values of [nonRecurringStream] and
  /// [recurringStream] (expanding the latter for [year]/[month]) into one
  /// merged, sorted [EventOccurrence] stream — re-emitting whenever either
  /// source updates. Both `snapshots()` streams are broadcast streams that
  /// replay their current server/cache state to a new listener (unlike the
  /// bare in-memory `StreamController` documented in `docs/LESSONS.md`), so
  /// no special first-emission handling is needed here beyond waiting for
  /// both sides to have emitted at least once.
  Stream<List<EventOccurrence>> _combineAndExpand(
    Stream<List<Event>> nonRecurringStream,
    Stream<List<Event>> recurringStream,
    int year,
    HebrewMonth month,
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
          ...occurrencesInHebrewMonth(
            event: event,
            year: year,
            month: month,
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
    final Event toStore = event.copyWith(
      ownerUid: ownerUid,
      createdAt: now,
      updatedAt: now,
    );
    final DocumentReference<Map<String, dynamic>> docRef = _events.doc();
    final Map<String, dynamic> data =
        eventToFirestoreData(event: toStore, engine: _engine)
          ..['createdAt'] = FieldValue.serverTimestamp()
          ..['updatedAt'] = FieldValue.serverTimestamp();
    await docRef.set(data);
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
    final Event toStore = event.copyWith(
      ownerUid: ownerUid,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
    final Map<String, dynamic> data =
        eventToFirestoreData(event: toStore, engine: _engine)
          ..['updatedAt'] = FieldValue.serverTimestamp()
          ..remove('createdAt');
    await docRef.update(data);
    return toStore;
  }

  @override
  Future<void> delete(String id) async {
    await _events.doc(id).delete();
  }
}
