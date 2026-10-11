// Widget tests for task brief #5's demo mode (Google Play review
// requirement): the sign-in screen's "כניסה במצב הדגמה" button must enter
// the full calendar UI with sample data and no authentication at all, the
// overflow menu must offer a way back to sign-in instead of sign-out, and
// the settings screen's Google sync section must show a fixed disabled
// message rather than spinning or making any Google/Firestore call.
//
// Deliberately does NOT override `eventRepositoryProvider`: the whole point
// is to exercise the real demo-mode seeding logic in
// `event_repository_provider.dart` (`buildDemoEvents`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/auth/presentation/sign_in_screen.dart';
import 'package:hebrew_calendar/features/calendar/presentation/calendar_shell_screen.dart';
import 'package:hebrew_calendar/l10n/app_localizations_he.dart';
import 'package:hebrew_calendar/main.dart';

import '../../../test_support/fake_auth_repository.dart';

Widget _wrap(List<Override> overrides) {
  return ProviderScope(overrides: overrides, child: const HebrewCalendarApp());
}

void main() {
  testWidgets(
    'the demo button enters the calendar shell with sample events visible',
    (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        _wrap(<Override>[authRepositoryProvider.overrideWithValue(auth)]),
      );
      await tester.pumpAndSettle();

      final AppLocalizationsHe l10n = AppLocalizationsHe();
      expect(find.text(l10n.signInDemoModeButton), findsOneWidget);
      await tester.tap(find.text(l10n.signInDemoModeButton));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(CalendarShellScreen), findsOneWidget);

      // The agenda view shows event titles as plain text (unlike the month
      // grid's single dot indicator), so switch to it to assert the sample
      // events are real, visible content — not an empty calendar.
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.calendarViewAgenda).last);
      await tester.pumpAndSettle();

      expect(find.text('יום הולדת עברי'), findsOneWidget);
      expect(find.text('פגישה עם הצוות'), findsOneWidget);
    },
  );

  testWidgets(
    'the overflow menu shows a return-to-sign-in action in demo mode, which '
    'clears demo state',
    (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        _wrap(<Override>[authRepositoryProvider.overrideWithValue(auth)]),
      );
      await tester.pumpAndSettle();

      final AppLocalizationsHe l10n = AppLocalizationsHe();
      await tester.tap(find.text(l10n.signInDemoModeButton));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarShellScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Demo mode: "התחבר" (return to sign-in), never "התנתקות" (sign out)
      // — there is no real session, so no confirmation dialog either.
      expect(find.text(l10n.signInReturnToSignInAction), findsOneWidget);
      expect(find.text(l10n.signOutAction), findsNothing);

      await tester.tap(find.text(l10n.signInReturnToSignInAction));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(CalendarShellScreen), findsNothing);
    },
  );

  testWidgets(
    'the settings screen shows the Google sync section as disabled in demo '
    'mode, with no spinner and no sync controls',
    (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        _wrap(<Override>[authRepositoryProvider.overrideWithValue(auth)]),
      );
      await tester.pumpAndSettle();

      final AppLocalizationsHe l10n = AppLocalizationsHe();
      await tester.tap(find.text(l10n.signInDemoModeButton));
      await tester.pumpAndSettle();

      // Settings lives in the app bar's overflow menu (KALFAPP rebrand).
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsTooltip));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.settingsGoogleSyncDisabledDemoMessage),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
    },
  );
}
