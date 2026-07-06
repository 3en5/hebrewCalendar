import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/event/event.dart';
import '../domain/event/event_repository.dart';
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

  @override
  Stream<List<Event>> watchEventsForHebrewMonth(int year, HebrewMonth month) {
    final ({DateTime start, DateTime endExclusive}) range =
        hebrewMonthGregorianRange(_engine, year, month);
    return _events
        .where('ownerUid', isEqualTo: ownerUid)
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
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    eventFromFirestoreData(doc.id, doc.data()),
              )
              .toList(),
        );
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
