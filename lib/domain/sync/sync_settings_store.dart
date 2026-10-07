/// The Google Calendar sync feature's persisted, user-scoped settings:
/// whether it's enabled, the incremental sync token, and when it last ran
/// successfully. Stored on the `users/{uid}` document
/// (ARCHITECTURE.md §4 "users/{uid} ... מצב סנכרון").
class SyncSettings {
  const SyncSettings({
    this.enabled = false,
    this.syncToken,
    this.lastSyncedAt,
    this.lastErrorMessage,
  });

  final bool enabled;

  /// Google Calendar `events.list` incremental sync token, or null before
  /// the first successful sync (or after a 410 GONE forced a full resync —
  /// ARCHITECTURE.md §5).
  final String? syncToken;

  final DateTime? lastSyncedAt;

  /// M5b: the error message from the most recently *failed* sync pass
  /// (foreground or background), or null if the last pass succeeded (or
  /// none has run yet). Persisted — not just kept in
  /// `google_sync_trigger_service.dart`'s in-memory state — because a
  /// background pass runs in a separate WorkManager isolate with no live
  /// settings-screen listener; without this, a background failure would be
  /// invisible until the next foreground sync happened to succeed or fail
  /// again. `sync_engine.dart` clears it on every successful pass.
  final String? lastErrorMessage;

  SyncSettings copyWith({
    bool? enabled,
    String? syncToken,
    bool clearSyncToken = false,
    DateTime? lastSyncedAt,
    String? lastErrorMessage,
    bool clearLastErrorMessage = false,
  }) => SyncSettings(
    enabled: enabled ?? this.enabled,
    syncToken: clearSyncToken ? null : (syncToken ?? this.syncToken),
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    lastErrorMessage: clearLastErrorMessage
        ? null
        : (lastErrorMessage ?? this.lastErrorMessage),
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

  /// M5b: persists (or clears, when [message] is null) the most recent
  /// sync pass's error message alongside the other sync bookkeeping.
  Future<void> saveLastError(String? message);
}
