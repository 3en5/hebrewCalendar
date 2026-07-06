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
}
