import 'package:shared_preferences/shared_preferences.dart';

/// A one-time request for a full Google listing (no sync token), e.g. to
/// backfill a field older imports lack. [SyncEngine] asks [isPending]
/// before a pass and calls [markDone] after a successful one.
abstract class FullResyncFlag {
  Future<bool> isPending();
  Future<void> markDone();
}

/// [FullResyncFlag] kept per device in `SharedPreferences`. Version 1
/// (M17): imported Google events were stored without their start/end
/// times; one full listing fills them in.
class PrefsFullResyncFlag implements FullResyncFlag {
  const PrefsFullResyncFlag();

  static const String _key = 'sync_full_resync_done_v1';

  @override
  Future<bool> isPending() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_key) ?? false);
    } catch (_) {
      // No platform channel (e.g. under `flutter test`): nothing pending.
      return false;
    }
  }

  @override
  Future<void> markDone() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // Best effort: at worst the full listing runs once more.
    }
  }
}
