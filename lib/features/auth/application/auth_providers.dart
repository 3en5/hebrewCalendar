import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/auth/app_user.dart';
import '../../../domain/auth/auth_repository.dart';
import '../data/auth_repository.dart';

/// The app-wide [AuthRepository]. Not `autoDispose` for the same reason as
/// `eventRepositoryProvider` (RULES.md §6.3 scopes screen state, not a
/// service that must outlive every screen) — overridden in widget tests with
/// a fake so no test ever constructs a real `FirebaseAuthRepository`.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => FirebaseAuthRepository());

/// Streams the current [AppUser] (null when signed out), driving the app
/// gate in `main.dart` and every screen that needs to know who's signed in.
final StreamProvider<AppUser?> authStateProvider = StreamProvider<AppUser?>(
  (Ref ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The current [AppUser], or null while loading/signed out/on error.
///
/// A plain synchronous read for call sites (like
/// `eventRepositoryProvider`) that only care about "who is signed in right
/// now", without needing to handle [AsyncValue]'s loading/error cases
/// themselves.
final Provider<AppUser?> currentUserProvider = Provider<AppUser?>(
  (Ref ref) => ref.watch(authStateProvider).value,
);
