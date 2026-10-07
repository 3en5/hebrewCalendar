import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds and mutates whether the app is in "demo mode".
///
/// Not `autoDispose`: this is app-session state, not screen-scoped UI state
/// — it must survive navigating between the sign-in screen and the
/// calendar shell exactly like the auth state provider does.
class DemoModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Enters demo mode — the sign-in screen's "כניסה במצב הדגמה" button.
  void enable() => state = true;

  /// Leaves demo mode — the calendar shell's overflow menu "התחבר" action,
  /// which returns to the sign-in screen (task brief #5).
  void disable() => state = false;
}

/// Whether the app is in "demo mode" (task brief #5 — the Google Play
/// review requirement: a reviewer must be able to see the full calendar UI
/// without creating/using a Google account). Read by the auth gate
/// (bypasses the normal signed-in check) and by every provider/screen that
/// must behave differently with no real signed-in user:
/// `eventRepositoryProvider` (seeds sample events instead of Firestore),
/// the settings screen's Google sync section (shows a fixed "requires
/// signing in" message, never calls Google/Firestore), and the calendar
/// shell's reminder sync trigger (must not start, so no notification
/// permission prompt appears during review).
final NotifierProvider<DemoModeNotifier, bool> demoModeProvider =
    NotifierProvider<DemoModeNotifier, bool>(DemoModeNotifier.new);
