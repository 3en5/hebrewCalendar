import 'package:flutter/foundation.dart' show debugPrint;

/// Process-wide idempotent guard around `google_sign_in` v7's
/// `GoogleSignIn.instance.initialize()` (device-feedback round #3 — the
/// settings screen's Google-sync enable toggle silently doing nothing).
///
/// `google_sign_in` v7's contract (docs/LESSONS.md, M2b): `GoogleSignIn.instance`
/// MUST have `initialize()` called exactly once, and its future awaited,
/// before ANY other method is called on it — calling anything else first is
/// undefined behavior (throws in practice). Every call site in this app that
/// touches `GoogleSignIn.instance` — the interactive sign-in flow
/// (`FirebaseAuthRepository.signInWithGoogle`), the Calendar sync API
/// adapter (`GoogleCalendarApiImpl`), and the WorkManager background isolate
/// (`background_sync_bootstrap.dart`) — must call [ensure] first.
///
/// Round #3's root cause: a **restored** FirebaseAuth session (the app
/// relaunching while already signed in) never runs `signInWithGoogle()` at
/// all — `AuthGate` goes straight from `authStateChanges()`'s persisted user
/// to the calendar shell. Without a guard *shared* across every call site,
/// `GoogleSignIn.instance` would never be initialized this process, and the
/// first other code to touch it — e.g. tapping the settings screen's
/// "enable sync" switch — would throw. A `Future` memoized per *instance* of
/// `FirebaseAuthRepository`/`GoogleCalendarApiImpl` is not enough for this,
/// since a restored session never constructs/calls the one instance that
/// used to do the initializing (the sign-in screen's repository); this
/// guard is a single process-wide static instead, so whichever call site
/// happens to run first satisfies it for every other one.
///
/// [ensure] takes the initializer as a callback (typically a tear-off of
/// `GoogleSignIn.instance.initialize`) rather than a `GoogleSignIn` directly,
/// so this guard's own idempotency is unit-testable
/// (`test/core/auth/google_sign_in_gate_test.dart`) without touching the
/// real plugin, which has no channel handler under `flutter test` (same
/// constraint as every other plugin adapter in this app — see
/// docs/LESSONS.md).
class GoogleSignInGate {
  GoogleSignInGate._();

  static Future<void>? _initialization;

  /// Ensures the one-time initializer has run (and awaits it) — safe to
  /// call any number of times, from any number of call sites, in this
  /// isolate. Every caller after the first awaits the same in-flight or
  /// already-completed initialization instead of re-running it.
  static Future<void> ensure(Future<void> Function() initializer) {
    return _initialization ??= _run(initializer);
  }

  static Future<void> _run(Future<void> Function() initializer) async {
    debugPrint('[sync-settings] GoogleSignIn.initialize() starting');
    await initializer();
    debugPrint('[sync-settings] GoogleSignIn.initialize() done');
  }

  /// Test-only: clears the memoized initialization between test cases. Real
  /// production code never calls this — this guard is meant to run its
  /// initializer at most once per app process/isolate.
  static void resetForTesting() {
    _initialization = null;
  }
}
