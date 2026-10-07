/// M5b's background sync decision layer (ARCHITECTURE.md §5): the *only*
/// place that decides whether a periodic WorkManager tick should actually
/// run a sync pass, and how to map its outcome onto WorkManager's retry
/// contract (`Future<bool>` — see `background_sync_bootstrap.dart`).
///
/// Deliberately Riverpod/workmanager/Firebase-free — every dependency is
/// injected as a plain function/interface, so this class is unit-testable
/// with fakes exactly like `google_sync_trigger_service.dart` (M5a) and
/// `reminder_sync_service.dart` (M4). The actual plugin entry point
/// (`background_sync_bootstrap.dart`'s `callbackDispatcher`) is thin wiring
/// around this class — it can't itself be exercised without a real Android
/// WorkManager + emulator (not available in this dev environment, see
/// docs/LESSONS.md), so it is kept to the minimum glue that could plausibly
/// be wrong, while every actual decision here gets full unit test coverage.
library;

import 'dart:async';

import '../../../data/sync/sync_engine.dart';
import '../../../domain/sync/sync_run_result.dart';
import '../../../domain/sync/sync_settings_store.dart';

/// The result WorkManager needs (task brief M5b §2: "returns true/false for
/// retry semantics — true=success or permanent skip; false only for
/// transient failures worth retrying").
enum BackgroundSyncOutcome {
  /// Ran a sync pass successfully.
  success,

  /// Nothing to retry: not signed in, sync disabled, a concurrent pass was
  /// already running (its own owner reports the real outcome), or a
  /// permanent failure (e.g. the Google grant was revoked — retrying
  /// immediately would fail identically). Maps to `true`.
  permanentSkip,

  /// A transient failure (network hiccup) or a hard timeout — worth
  /// retrying on WorkManager's own backoff schedule. Maps to `false`.
  retry,
}

/// Decides whether to run one background sync pass, and runs it.
///
/// Every dependency is injected so this is fully testable without Firebase,
/// Google Sign-In, or WorkManager:
/// - [isSignedIn]: in production, a silent (never-prompting) check via
///   `google_sign_in` v7's `attemptLightweightAuthentication` (see
///   `background_sync_bootstrap.dart`).
/// - [settingsStore]: the signed-in user's [SyncSettingsStore] — checked
///   for the enabled flag.
/// - [engineFactory]: builds the [SyncEngine] to run, lazily — only
///   constructed once we know we're actually going to sync.
/// - [now]: injected clock (matches the rest of the codebase's pattern —
///   `sync_engine.dart`/`google_sync_trigger_service.dart`/
///   `reminder_sync_service.dart` all take one); recorded as [lastAttemptAt]
///   for diagnostics.
class BackgroundSyncRunner {
  BackgroundSyncRunner({
    required Future<bool> Function() isSignedIn,
    required SyncSettingsStore settingsStore,
    required SyncEngine Function() engineFactory,
    DateTime Function() now = DateTime.now,
    Duration timeout = const Duration(minutes: 4),
  }) : _isSignedIn = isSignedIn,
       _settingsStore = settingsStore,
       _engineFactory = engineFactory,
       _now = now,
       _timeout = timeout;

  final Future<bool> Function() _isSignedIn;
  final SyncSettingsStore _settingsStore;
  final SyncEngine Function() _engineFactory;
  final DateTime Function() _now;
  final Duration _timeout;

  /// When [run] was last invoked — exposed for diagnostics/tests; not used
  /// in the decision itself.
  DateTime? lastAttemptAt;

  /// Decides whether to run a sync pass and, if so, runs exactly one via
  /// [engineFactory], enforcing [timeout] as a hard ceiling (task brief M5b
  /// §2: "hard timeout (e.g. 4 minutes)"). Never throws — every failure
  /// mode maps to a [BackgroundSyncOutcome].
  Future<BackgroundSyncOutcome> run() async {
    lastAttemptAt = _now();

    final bool signedIn = await _isSignedIn();
    if (!signedIn) {
      // No point constructing an engine at all: every Calendar API call
      // would fail immediately with no signed-in account, and retrying a
      // background tick moments later wouldn't change that.
      return BackgroundSyncOutcome.permanentSkip;
    }

    final SyncSettings settings = await _settingsStore.load();
    if (!settings.enabled) {
      return BackgroundSyncOutcome.permanentSkip;
    }

    try {
      final SyncRunResult result = await _engineFactory().runSync().timeout(
        _timeout,
      );
      if (result.wasConcurrentSkip) {
        // Another pass (a foreground trigger, or a previous still-running
        // background tick) already owns this work; it will persist its own
        // outcome. Nothing for this tick to retry.
        return BackgroundSyncOutcome.permanentSkip;
      }
      if (!result.isError) {
        return BackgroundSyncOutcome.success;
      }
      return result.permanent
          ? BackgroundSyncOutcome.permanentSkip
          : BackgroundSyncOutcome.retry;
    } on TimeoutException {
      return BackgroundSyncOutcome.retry;
    }
  }
}
