import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/sync/sync_settings_store.dart';

/// [SyncSettingsStore] backed by the `users/{uid}` profile document
/// (ARCHITECTURE.md §4 "מצב סנכרון"): `googleSyncEnabled` (bool),
/// `googleSyncToken` (string, Google Calendar incremental sync token) and
/// `googleLastSyncedAt` (timestamp).
class FirestoreSyncSettingsStore implements SyncSettingsStore {
  FirestoreSyncSettingsStore({required this.uid, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('users').doc(uid);

  @override
  Future<SyncSettings> load() async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _doc.get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return const SyncSettings();
    }
    return SyncSettings(
      enabled: data['googleSyncEnabled'] as bool? ?? false,
      syncToken: data['googleSyncToken'] as String?,
      lastSyncedAt: (data['googleLastSyncedAt'] as Timestamp?)?.toDate(),
      lastErrorMessage: data['googleLastSyncError'] as String?,
    );
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    await _doc.set(<String, dynamic>{
      'googleSyncEnabled': enabled,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveSyncToken(String? token) async {
    await _doc.set(<String, dynamic>{
      'googleSyncToken': token,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveLastSyncedAt(DateTime at) async {
    await _doc.set(<String, dynamic>{
      'googleLastSyncedAt': Timestamp.fromDate(at),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveLastError(String? message) async {
    await _doc.set(<String, dynamic>{
      // The time goes inside the message, not in a field of its own: the
      // Security Rules whitelist the fields of this document, and a new
      // field made every write here fail (round #9). It lets a stale error
      // be told apart from a fresh one (tool/diagnose_sync.py).
      'googleLastSyncError': message == null
          ? null
          : '[${DateTime.now().toUtc().toIso8601String()}] $message',
    }, SetOptions(merge: true));
  }
}
