import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/auth_providers.dart';
import '../application/demo_mode_provider.dart';

/// The signed-out landing screen: app name, a Google sign-in button, a
/// loading state while the flow is in progress, and an error snackbar if it
/// fails for a reason other than a plain user cancellation (RULES.md §4.4 —
/// RTL via `start`/`end` only; no `left`/`right`).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _isSigningIn = false;

  Future<void> _signIn() async {
    setState(() => _isSigningIn = true);
    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      // A null result means the user cancelled — no error to show.
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.signInErrorMessage)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsetsDirectional.all(spacingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacingXxl),
                if (_isSigningIn)
                  const CircularProgressIndicator()
                else ...<Widget>[
                  FilledButton.icon(
                    onPressed: _signIn,
                    icon: const Icon(Icons.login),
                    label: Text(l10n.signInWithGoogleButton),
                  ),
                  SizedBox(height: spacingMd),
                  // Task brief #5 — Google Play review requirement: a
                  // reviewer must be able to see the full calendar UI
                  // without creating/using a Google account. This enters
                  // `CalendarShellScreen` with an in-memory repository
                  // seeded with sample events and no Firebase/Google calls
                  // at all (see `demoModeProvider`/`eventRepositoryProvider`).
                  TextButton(
                    onPressed: () =>
                        ref.read(demoModeProvider.notifier).enable(),
                    child: Text(l10n.signInDemoModeButton),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
