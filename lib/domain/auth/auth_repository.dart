import 'app_user.dart';

/// Abstract authentication gateway, defined purely in terms of domain types
/// (ARCHITECTURE.md §3 — mirrors [EventRepository]'s pattern in
/// `domain/event/event_repository.dart`: nothing above the data layer knows
/// whether it's backed by Firebase or a fake).
///
/// Implemented by `FirebaseAuthRepository` (lib/features/auth/data) which
/// wraps `firebase_auth` + `google_sign_in`; fake implementations back
/// widget tests so no test ever touches real Firebase (task brief M2b §5).
abstract class AuthRepository {
  /// Emits the current user whenever sign-in state changes, starting with
  /// the current state (null if signed out).
  Stream<AppUser?> authStateChanges();

  /// Runs the interactive Google sign-in flow and signs into Firebase Auth
  /// with the resulting credential.
  ///
  /// Returns the signed-in [AppUser], or null if the user cancelled the
  /// flow (never throws for a plain cancellation).
  Future<AppUser?> signInWithGoogle();

  /// Signs out of both Firebase Auth and Google Sign-In.
  Future<void> signOut();
}
