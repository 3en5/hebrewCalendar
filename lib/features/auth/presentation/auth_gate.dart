import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/auth/app_user.dart';
import '../../calendar/presentation/calendar_shell_screen.dart';
import '../application/auth_providers.dart';
import 'sign_in_screen.dart';

/// The app's root gate: renders [SignInScreen] while signed out and
/// [CalendarShellScreen] once signed in, keyed off [authStateProvider].
///
/// This is the only place the app branches on auth state — everything
/// downstream of [CalendarShellScreen] can assume a signed-in user exists.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> authState = ref.watch(authStateProvider);
    return authState.when(
      data: (AppUser? user) =>
          user != null ? const CalendarShellScreen() : const SignInScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Falling back to the sign-in screen on a stream error (rather than an
      // error screen with no way forward) lets the user retry sign-in, which
      // is the only actionable recovery available at this gate.
      error: (Object error, StackTrace stackTrace) => const SignInScreen(),
    );
  }
}
