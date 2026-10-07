import 'sync_state.dart';

/// The outcome of one `sync_engine.dart` sync pass — surfaced by the
/// settings screen (M5a task brief §3: "error surface (Hebrew)") and, from
/// M5b, read by `BackgroundSyncRunner` to decide WorkManager retry
/// semantics.
class SyncRunResult {
  const SyncRunResult({
    required this.status,
    this.errorMessage,
    this.permanent = false,
    this.wasConcurrentSkip = false,
  });

  const SyncRunResult.disabled() : this(status: SyncStatus.idle);

  const SyncRunResult.success() : this(status: SyncStatus.idle);

  const SyncRunResult.failure(String message, {bool permanent = false})
    : this(
        status: SyncStatus.error,
        errorMessage: message,
        permanent: permanent,
      );

  /// M5b: another `runSync()` call was already in flight (the concurrency
  /// guard — see `sync_engine.dart`'s `_inFlight`), so this call did
  /// nothing. Treated as idle/success, not an error — the in-flight call
  /// owns reporting the actual outcome.
  const SyncRunResult.concurrentSkip()
    : this(status: SyncStatus.idle, wasConcurrentSkip: true);

  final SyncStatus status;
  final String? errorMessage;

  /// M5b: whether `sync_engine.dart`'s catch-all classified this failure as
  /// permanent — retrying immediately would fail identically (an
  /// expired/revoked Google grant, HTTP 401/403) — rather than transient
  /// (network hiccups, or anything unrecognized, which default to `false`
  /// so a background retry is attempted rather than silently giving up).
  /// Only meaningful when [isError].
  final bool permanent;

  /// M5b: true when this result came from finding a sync pass already in
  /// flight rather than actually running (or skipping due to being
  /// disabled).
  final bool wasConcurrentSkip;

  bool get isError => status == SyncStatus.error;
}
