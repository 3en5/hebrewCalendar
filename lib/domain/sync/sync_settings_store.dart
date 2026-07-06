/// The Google Calendar sync feature's persisted, user-scoped settings:
/// whether it's enabled, the incremental sync token, and when it last ran
/// successfully. Stored on the `users/{uid}` document
/// (ARCHITECTURE.md §4 "users/{uid} ... מצב סנכרון").
class SyncSettings {
  const SyncSettings({this.enabled = false, this.syncToken, this.lastSyncedAt});

  final bool enabled;

  /// Google Calendar `events.list` incremental sync token, or null before
  /// the first successful sync (or after a 410 GONE forced a full resync —
  /// ARCHITECTURE.md §5).
  final String? syncToken;

  final DateTime? lastSyncedAt;

  SyncSettings copyWith({
    bool? enabled,
    String? syncToken,
    bool clearSyncToken = false,
    DateTime? lastSyncedAt,
  }) => SyncSettings(
    enabled: enabled ?? this.enabled,
    syncToken: clearSyncToken ? null : (syncToken ?? this.syncToken),
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
}

/// Abstract storage for [SyncSettings] — implemented against Firestore
/// (`lib/data/sync/firestore_sync_settings_store.dart`) so
/// `google_sync_trigger_service.dart`/`sync_engine.dart` stay testable with
/// an in-memory fake, matching the `EventRepository`/`NotificationScheduler`
/// port pattern.
abstract class SyncSettingsStore {
  Future<SyncSettings> load();

  Future<void> setEnabled(bool enabled);

  Future<void> saveSyncToken(String? token);

  Future<void> saveLastSyncedAt(DateTime at);
}
