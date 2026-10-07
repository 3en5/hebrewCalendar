import 'dart:async';

import 'package:hebrew_calendar/domain/auth/app_user.dart';
import 'package:hebrew_calendar/domain/auth/auth_repository.dart';

/// A signed-in [AppUser] test fixture shared by widget tests that need the
/// auth gate to show the signed-in (month view) branch.
const AppUser testUser = AppUser(
  uid: 'test-uid',
  displayName: 'משתמש בדיקה',
  email: 'test@example.com',
);

/// A controllable [AuthRepository] test double.
///
/// Backed by a single-subscription [StreamController] rather than a
/// broadcast one: single-subscription controllers queue events added before
/// a listener attaches (delivering them in order once `authStateChanges()`
/// is listened to), so there's no risk of the subscription-timing race
/// documented in `docs/LESSONS.md` for broadcast controllers. Exactly one
/// listener (the `authStateProvider` `StreamProvider`) is expected per
/// instance, which single-subscription supports.
///
/// No test using this ever touches real Firebase (task brief M2b §5).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? initialUser})
    : _controller = StreamController<AppUser?>() {
    _controller.add(initialUser);
  }

  final StreamController<AppUser?> _controller;

  /// Number of times [signOut] was called, for tests asserting the
  /// sign-out action actually invoked the repository.
  int signOutCallCount = 0;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  /// Pushes a new auth state, simulating a sign-in/out happening elsewhere.
  void emit(AppUser? user) => _controller.add(user);

  @override
  Future<AppUser?> signInWithGoogle() async {
    emit(testUser);
    return testUser;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    emit(null);
  }

  /// Closes the underlying stream controller; call from test teardown.
  void dispose() => unawaited(_controller.close());
}
