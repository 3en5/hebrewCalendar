import '../../domain/sync/sync_settings_store.dart';

/// In-memory [SyncSettingsStore]: the fallback used before a user is
/// signed in (mirrors `InMemoryEventRepository`'s role for
/// `eventRepositoryProvider`) and the implementation used directly by
/// `sync_engine`/`google_sync_trigger_service` tests — no Firestore
/// involved, matching the "no network access to Google APIs from tests"
/// constraint (M5a task brief).
class InMemorySyncSettingsStore implements SyncSettingsStore {
  SyncSettings _settings = const SyncSettings();

  @override
  Future<SyncSettings> load() async => _settings;

  @override
  Future<void> setEnabled(bool enabled) async {
    _settings = _settings.copyWith(enabled: enabled);
  }

  @override
  Future<void> saveSyncToken(String? token) async {
    _settings = token == null
        ? _settings.copyWith(clearSyncToken: true)
        : _settings.copyWith(syncToken: token);
  }

  @override
  Future<void> saveLastSyncedAt(DateTime at) async {
    _settings = _settings.copyWith(lastSyncedAt: at);
  }

  @override
  Future<void> saveLastError(String? message) async {
    _settings = message == null
        ? _settings.copyWith(clearLastErrorMessage: true)
        : _settings.copyWith(lastErrorMessage: message);
  }
}
