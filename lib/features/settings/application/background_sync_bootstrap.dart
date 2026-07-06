/// M5b's WorkManager entry point (ARCHITECTURE.md §5): registered once from
/// `main.dart` via `Workmanager().initialize(callbackDispatcher, ...)`
/// (Android only). WorkManager spawns a *separate* headless Flutter
/// engine/isolate to run [callbackDispatcher] — it shares no memory with
/// the foreground app, so everything it needs (Firebase, the Google
/// account's silently-restored session, the signed-in user's
/// Firestore-backed sync settings/events) is reconstructed from scratch
/// here on every tick; nothing from a foreground provider/state is ever
/// available (see docs/LESSONS.md on `google_sign_in` v7 and Firebase
/// initialization).
///
/// Deliberately as thin as possible (task brief M5b §2: "the
/// callbackDispatcher itself is just wiring") — every actual decision
/// (signed in? sync enabled? did the pass succeed/fail/time out?) lives in
/// [BackgroundSyncRunner], unit-tested directly with fakes. This file
/// cannot itself be exercised without a real Android WorkManager + emulator
/// (not available in this dev environment — docs/LESSONS.md, M2b), so it is
/// kept to the minimum glue that could plausibly be wrong.
library;

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:workmanager/workmanager.dart';

import '../../../data/firestore_event_repository.dart';
import '../../../data/sync/firestore_sync_settings_store.dart';
import '../../../data/sync/google_calendar_api_impl.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../domain/hebrew_date/hebrew_date_engine.dart';
import 'background_sync_runner.dart';
import 'background_sync_scheduler.dart';

/// OAuth scope needed to silently confirm the Google Calendar grant is
/// still available — mirrors `google_calendar_api_impl.dart`'s
/// `_kCalendarScopes` (kept private there; duplicated here rather than
/// exported, since this is the only other file that needs it and a shared
/// constant would be a needless cross-file coupling for one string).
const List<String> _kCalendarScopes = <String>[
  'https://www.googleapis.com/auth/calendar.events',
];

/// The WorkManager background task callback. Must be a top-level (or
/// static) function annotated `@pragma('vm:entry-point')` so the Flutter
/// engine can find it by name from native code after an app restart —
/// an instance method or closure would be tree-shaken/unreachable.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((
    String task,
    Map<String, dynamic>? inputData,
  ) async {
    if (task != kGoogleCalendarSyncTaskName) {
      // Not a task we registered — nothing to do, nothing to retry.
      return true;
    }
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await _ensureFirebaseInitialized();

      final fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Firebase Auth's own session persists across isolates/restarts —
        // if there's no current user here, the app is signed out and there
        // is nothing to sync (permanent skip, not worth retrying).
        return true;
      }

      final BackgroundSyncRunner runner = BackgroundSyncRunner(
        isSignedIn: _attemptSilentGoogleAuth,
        settingsStore: FirestoreSyncSettingsStore(uid: user.uid),
        engineFactory: () => SyncEngine(
          repository: FirestoreEventRepository(ownerUid: user.uid),
          // `allowInteractiveAuth: false` — task brief M5b §2: this runs
          // headless, with no Activity to host a consent screen; a lapsed
          // grant must surface as a (permanent) failure, never a prompt.
          api: GoogleCalendarApiImpl(allowInteractiveAuth: false),
          settingsStore: FirestoreSyncSettingsStore(uid: user.uid),
          engine: const HebrewDateEngine(),
        ),
      );

      final BackgroundSyncOutcome outcome = await runner.run();
      return outcome != BackgroundSyncOutcome.retry;
    } catch (_) {
      // Anything unexpected outside BackgroundSyncRunner's own handling
      // (e.g. Firebase/Google Sign-In initialization itself failing) —
      // ask WorkManager to retry rather than crash the background isolate.
      return false;
    }
  });
}

/// Guards against double-initializing Firebase in this isolate (mirrors
/// `main.dart`'s `_initializeFirebase`, which this isolate never runs).
Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

/// Silently restores the Google Sign-In session and confirms the
/// `calendar.events` scope is still granted — never prompts (task brief
/// M5b §2: "NEVER prompts UI from background; promptIfNecessary: false for
/// authorization headers"). A fresh isolate means `GoogleSignIn.instance`
/// has not been initialized yet, so that always happens here first (unlike
/// `features/auth/data/auth_repository.dart`'s memoized
/// `_ensureGoogleSignInInitialized`, which guards repeat calls *within one
/// long-lived foreground instance* — not needed here since this whole
/// function runs at most once per isolate).
Future<bool> _attemptSilentGoogleAuth() async {
  final GoogleSignIn googleSignIn = GoogleSignIn.instance;
  await googleSignIn.initialize();
  final GoogleSignInAccount? account =
      await (googleSignIn.attemptLightweightAuthentication() ??
          Future<GoogleSignInAccount?>.value());
  if (account == null) {
    return false;
  }
  final Map<String, String>? headers = await account.authorizationClient
      .authorizationHeaders(_kCalendarScopes, promptIfNecessary: false);
  return headers != null;
}
