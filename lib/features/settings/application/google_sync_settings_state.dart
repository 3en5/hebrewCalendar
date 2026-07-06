import '../../../domain/sync/sync_state.dart';

/// Pure UI-facing snapshot of the Google Calendar sync feature's state
/// (M5a task brief §3) — enabled/disabled, when it last ran, current
/// [SyncStatus], and a Hebrew-ready error message when [status] is
/// [SyncStatus.error]. Built by `google_sync_trigger_service.dart`, rendered
/// by `settings_screen.dart`.
class GoogleSyncSettingsState {
  const GoogleSyncSettingsState({
    this.enabled = false,
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.errorMessage,
    this.initialLoadFailed = false,
  });

  final bool enabled;
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  /// Set when `GoogleSyncTriggerService.start()` could not load the
  /// persisted settings at all (Firestore read failure/timeout — real
  /// device report #2: an endless spinner where this section should be).
  /// The settings screen renders a dedicated retry card instead of the
  /// normal switch/last-sync UI while this is true, since [enabled] and
  /// [lastSyncedAt] are meaningless placeholders (the real values were
  /// never fetched).
  final bool initialLoadFailed;

  GoogleSyncSettingsState copyWith({
    bool? enabled,
    SyncStatus? status,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? initialLoadFailed,
  }) => GoogleSyncSettingsState(
    enabled: enabled ?? this.enabled,
    status: status ?? this.status,
    lastSyncedAt: clearLastSyncedAt
        ? null
        : (lastSyncedAt ?? this.lastSyncedAt),
    errorMessage: clearErrorMessage
        ? null
        : (errorMessage ?? this.errorMessage),
    initialLoadFailed: initialLoadFailed ?? this.initialLoadFailed,
  );
}
