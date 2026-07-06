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
  });

  final bool enabled;
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  GoogleSyncSettingsState copyWith({
    bool? enabled,
    SyncStatus? status,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => GoogleSyncSettingsState(
    enabled: enabled ?? this.enabled,
    status: status ?? this.status,
    lastSyncedAt: clearLastSyncedAt
        ? null
        : (lastSyncedAt ?? this.lastSyncedAt),
    errorMessage: clearErrorMessage
        ? null
        : (errorMessage ?? this.errorMessage),
  );
}
