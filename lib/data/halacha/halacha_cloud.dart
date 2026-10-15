import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/halacha/daily_halacha.dart';

/// M25: the cloud side of the daily halacha: the day's dedication and the
/// anonymous counters. An interface so widget tests and demo mode never
/// touch Firestore.
abstract class HalachaCloud {
  /// The dedication for [day] ("לעילוי נשמת..."), else the default one,
  /// else null. The last value seen is kept for offline use.
  Future<String?> dedicationFor(DateTime day);

  /// The share of users who keep the daily halacha on (0..1), or null when
  /// unknown.
  Future<double?> enabledShare();

  /// Moves this device's vote from [from] (null if it never voted) to [to].
  Future<void> recordChoice({required bool? from, required bool to});

  /// One more learner on [day].
  Future<void> recordLearned(DateTime day);
}

/// No cloud at all (demo mode, tests): no dedication, no statistics.
class OfflineHalachaCloud implements HalachaCloud {
  const OfflineHalachaCloud();

  @override
  Future<String?> dedicationFor(DateTime day) async => null;

  @override
  Future<double?> enabledShare() async => null;

  @override
  Future<void> recordChoice({required bool? from, required bool to}) async {}

  @override
  Future<void> recordLearned(DateTime day) async {}
}

const String _dedicationCachePrefix = 'daily_halacha_dedication_';

class FirestoreHalachaCloud implements HalachaCloud {
  FirestoreHalachaCloud({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;

  /// Resolved lazily, inside each call's try, so a missing Firebase app
  /// (widget tests) only means "no cloud".
  FirebaseFirestore get _firestore => _injected ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _stats =>
      _firestore.doc('stats/dailyHalacha');

  @override
  Future<String?> dedicationFor(DateTime day) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = dedicationDayKey(day);
    Future<String?> read(String id) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
          .doc('dedications/$id')
          .get()
          .timeout(const Duration(seconds: 8));
      final Object? text = snap.data()?['text'];
      return text is String && text.trim().isNotEmpty ? text.trim() : null;
    }

    try {
      final String? text = await read(key) ?? await read('default');
      if (text != null) {
        await prefs.setString('$_dedicationCachePrefix$key', text);
      }
      return text;
    } catch (_) {
      return prefs.getString('$_dedicationCachePrefix$key') ??
          prefs.getString('${_dedicationCachePrefix}default');
    }
  }

  @override
  Future<double?> enabledShare() async {
    try {
      final Map<String, dynamic>? data = (await _stats.get().timeout(
        const Duration(seconds: 8),
      )).data();
      final int on = (data?['enabled'] as num?)?.toInt() ?? 0;
      final int off = (data?['disabled'] as num?)?.toInt() ?? 0;
      return on + off == 0 ? null : on / (on + off);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> recordChoice({required bool? from, required bool to}) async {
    if (from == to) {
      return;
    }
    final Map<String, Object> change = <String, Object>{
      (to ? 'enabled' : 'disabled'): FieldValue.increment(1),
      if (from != null)
        (from ? 'enabled' : 'disabled'): FieldValue.increment(-1),
    };
    try {
      await _stats.set(change, SetOptions(merge: true));
    } catch (_) {
      // Statistics are best effort.
    }
  }

  @override
  Future<void> recordLearned(DateTime day) async {
    try {
      await _stats.collection('days').doc(dedicationDayKey(day)).set(
        <String, Object>{'learned': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Best effort.
    }
  }
}
