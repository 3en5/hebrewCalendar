/// Which part of a Google sync pass is running (device request 2026-10-12:
/// show sync progress).
enum SyncPhase {
  /// Fetching the changes from Google; how many is not known yet.
  downloading,

  /// Writing Google's changes into the app.
  applying,

  /// Sending the app's changes to Google.
  uploading,
}

/// How far a sync pass is: [done] of [total] items in [phase] ([total] 0
/// while it isn't known, e.g. during [SyncPhase.downloading]).
class SyncProgress {
  const SyncProgress(this.phase, {this.done = 0, this.total = 0});

  final SyncPhase phase;
  final int done;
  final int total;

  /// 0..1, or null when there is nothing to measure yet.
  double? get fraction => total <= 0 ? null : (done / total).clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      other is SyncProgress &&
      other.phase == phase &&
      other.done == done &&
      other.total == total;

  @override
  int get hashCode => Object.hash(phase, done, total);
}

/// Receives [SyncProgress] updates during a pass.
typedef SyncProgressCallback = void Function(SyncProgress progress);
