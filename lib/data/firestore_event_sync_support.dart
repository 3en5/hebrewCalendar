/// The M5a sync-support half of `FirestoreEventRepository`, split into its
/// own file (RULES.md §2 — a monolithic sync-aware repository would exceed
/// 500 lines): everything `sync_engine.dart` needs beyond plain event
/// CRUD/watch — reading every event for a full reconciliation pass, looking
/// an event up by its Google counterpart id, recording sync bookkeeping
/// without re-marking an event dirty, and a durable queue of deletions still
/// awaiting remote cleanup.
///
/// Pending deletions are persisted at
/// `users/{uid}/pendingGoogleDeletions/{eventId}` (not just kept in memory
/// like `InMemoryEventRepository`'s equivalent queue) so a delete made while
/// offline/about to be killed is not silently lost before the next sync pass
/// — M5a is foreground-triggered only (no WorkManager yet, that's M5b), so
/// surviving a process restart matters more here than it would once a
/// periodic background worker exists to retry promptly.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/event/default_calendar_id.dart';
import '../domain/event/event.dart';
import '../domain/event/event_attendee.dart';
import '../domain/event/event_source.dart';
import '../domain/event/recurrence_rule.dart';
import '../domain/hebrew_date/hebrew_date.dart';
import '../domain/hebrew_date/hebrew_date_engine.dart';
import '../domain/sync/export_candidate.dart';
import '../domain/sync/remote_event_snapshot.dart';
import '../domain/sync/sync_state.dart';
import 'event_firestore_mapper.dart';

class FirestoreEventSyncSupport {
  FirestoreEventSyncSupport({
    required FirebaseFirestore firestore,
    required String ownerUid,
    required HebrewDateEngine engine,
  }) : _firestore = firestore,
       _ownerUid = ownerUid,
       _engine = engine;

  final FirebaseFirestore _firestore;
  final String _ownerUid;
  final HebrewDateEngine _engine;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  CollectionReference<Map<String, dynamic>> get _pendingDeletions => _firestore
      .collection('users')
      .doc(_ownerUid)
      .collection('pendingGoogleDeletions');

  Future<List<Event>> getAllForSync() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _events
        .where('ownerUid', isEqualTo: _ownerUid)
        .get();
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              eventFromFirestoreData(doc.id, doc.data()),
        )
        .toList();
  }

  /// Cache first (no server reads, works offline); the server only when
  /// the cache has nothing yet.
  Future<List<Event>> getAllForSearch() async {
    final Query<Map<String, dynamic>> query = _events.where(
      'ownerUid',
      isEqualTo: _ownerUid,
    );
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.get(const GetOptions(source: Source.cache));
    } catch (_) {
      snapshot = await query.get();
    }
    if (snapshot.docs.isEmpty) {
      snapshot = await query.get();
    }
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              eventFromFirestoreData(doc.id, doc.data()),
        )
        .toList();
  }

  /// Filtered in memory from the cached events: recurring events are few,
  /// and a query on the recurrence type would need its own index.
  Future<List<Event>> getRecurringForSync() async => (await getAllForSearch())
      .where((Event event) => event.recurrence.type != RecurrenceType.none)
      .toList();

  Future<List<Event>> getDirtyForSync() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _events
        .where('ownerUid', isEqualTo: _ownerUid)
        .where('googleSync.dirty', isEqualTo: true)
        .get();
    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              eventFromFirestoreData(doc.id, doc.data()),
        )
        .toList();
  }

  Future<Event?> getByGoogleEventId(String googleEventId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _events
        .where('ownerUid', isEqualTo: _ownerUid)
        .where('googleSync.googleEventId', isEqualTo: googleEventId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final QueryDocumentSnapshot<Map<String, dynamic>> doc = snapshot.docs.first;
    return eventFromFirestoreData(doc.id, doc.data());
  }

  Future<void> updateAttendeeResponses(
    String eventId,
    List<EventAttendee> fromGoogle,
  ) async {
    final DocumentReference<Map<String, dynamic>> docRef = _events.doc(eventId);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return;
    }
    final Event existing = eventFromFirestoreData(snapshot.id, data);
    await docRef.update(<String, dynamic>{
      'attendees': attendeesToMaps(
        mergeAttendeeResponses(existing.attendees, fromGoogle),
      ),
    });
  }

  Future<void> updateSyncState(
    String eventId, {
    GoogleSyncState? googleSync,
    Map<String, GoogleSyncState>? googleInstanceSync,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef = _events.doc(eventId);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return;
    }
    final Event existing = eventFromFirestoreData(snapshot.id, data);
    final Map<String, GoogleSyncState> merged = <String, GoogleSyncState>{
      ...existing.googleInstanceSync,
      ...?googleInstanceSync,
    };
    await docRef.update(<String, dynamic>{
      'googleSync': syncStateToMap(googleSync ?? existing.googleSync),
      'googleInstanceSync': merged.map(
        (String key, GoogleSyncState value) =>
            MapEntry<String, dynamic>(key, syncStateToMap(value)),
      ),
    });
  }

  Future<List<PendingGoogleDeletion>> takePendingGoogleDeletions() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _pendingDeletions
        .get();
    final List<PendingGoogleDeletion> drained = <PendingGoogleDeletion>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String eventId = data['eventId'] as String? ?? doc.id;
      final List<dynamic> rawInstances =
          data['remoteInstances'] as List<dynamic>? ?? const <dynamic>[];
      final List<GoogleSyncState> instances = rawInstances
          .map(
            (dynamic raw) =>
                syncStateFromMap(Map<String, dynamic>.from(raw as Map)),
          )
          .toList();
      drained.add(
        PendingGoogleDeletion(eventId: eventId, remoteInstances: instances),
      );
      await doc.reference.delete();
    }
    return drained;
  }

  /// Called by `FirestoreEventRepository.delete` before it removes the
  /// document — persists a tombstone iff [event] actually has Google sync
  /// state to clean up remotely.
  Future<void> enqueuePendingDeletionIfNeeded(Event event) async {
    final List<GoogleSyncState> instances = <GoogleSyncState>[
      if (event.googleSync.googleEventId != null) event.googleSync,
      ...event.googleInstanceSync.values.where(
        (GoogleSyncState state) => state.googleEventId != null,
      ),
    ];
    if (instances.isEmpty) {
      return;
    }
    await _pendingDeletions.doc(event.id).set(<String, dynamic>{
      'eventId': event.id,
      'remoteInstances': instances.map(syncStateToMap).toList(),
    });
  }

  Future<Event> upsertFromGoogle(
    RemoteEventSnapshot snapshot, {
    String? existingEventId,
  }) async {
    final DateTime start = snapshot.start ?? DateTime.now();
    final HebrewDate hebrewDate = _engine.fromGregorian(start);
    final GoogleSyncState syncState = GoogleSyncState(
      googleEventId: snapshot.googleEventId,
      etag: snapshot.etag,
      lastSyncedAt: DateTime.now(),
    );
    final DocumentReference<Map<String, dynamic>> docRef =
        existingEventId == null ? _events.doc() : _events.doc(existingEventId);
    DateTime createdAt = DateTime.now();
    if (existingEventId != null) {
      final DocumentSnapshot<Map<String, dynamic>> existingSnap = await docRef
          .get();
      final Map<String, dynamic>? existingData = existingSnap.data();
      if (existingData != null) {
        createdAt =
            (existingData['createdAt'] as Timestamp?)?.toDate() ?? createdAt;
      }
    }
    final Event toStore = Event(
      id: docRef.id,
      ownerUid: _ownerUid,
      calendarId: kDefaultCalendarId,
      title: snapshot.summary,
      description: snapshot.description,
      location: snapshot.location,
      colorId: snapshot.colorId,
      attendees: snapshot.attendees,
      hebrewDate: hebrewDate,
      allDay: snapshot.isAllDay,
      createdAt: createdAt,
      updatedAt: snapshot.updatedAt,
      source: EventSource.google,
      googleSync: syncState,
    );
    await docRef.set(eventToFirestoreData(event: toStore, engine: _engine));
    return toStore;
  }

  Future<void> applyRemoteDelete(String id) async {
    await _events.doc(id).delete();
  }
}
