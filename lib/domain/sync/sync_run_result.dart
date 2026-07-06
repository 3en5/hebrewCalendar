import 'sync_state.dart';

/// The outcome of one `sync_engine.dart` sync pass — surfaced by the
/// settings screen (M5a task brief §3: "error surface (Hebrew)").
class SyncRunResult {
  const SyncRunResult({required this.status, this.errorMessage});

  const SyncRunResult.disabled() : this(status: SyncStatus.idle);

  const SyncRunResult.success() : this(status: SyncStatus.idle);

  const SyncRunResult.failure(String message)
    : this(status: SyncStatus.error, errorMessage: message);

  final SyncStatus status;
  final String? errorMessage;

  bool get isError => status == SyncStatus.error;
}
