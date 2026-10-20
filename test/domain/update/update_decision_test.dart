// Owner request 2026-10-20: when a newer version is on Google Play, the app
// offers it; versions below the site's minimum must update.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/update/update_decision.dart';

UpdatePrompt _decide({
  int installed = 49,
  int? available = 50,
  bool flexible = true,
  bool immediate = true,
  int? min,
  DateTime? dismissed,
}) => decideUpdatePrompt(
  installedCode: installed,
  availableCode: available,
  flexibleAllowed: flexible,
  immediateAllowed: immediate,
  minVersionCode: min,
  dismissedAt: dismissed,
  now: DateTime(2026, 10, 20, 12),
);

void main() {
  test('no newer version: nothing', () {
    expect(_decide(available: null), UpdatePrompt.none);
    expect(_decide(available: 49), UpdatePrompt.none);
  });

  test('a newer version: the banner', () {
    expect(_decide(), UpdatePrompt.flexible);
  });

  test('"not now" quiets the banner for three days', () {
    expect(_decide(dismissed: DateTime(2026, 10, 19)), UpdatePrompt.none);
    expect(
      _decide(dismissed: DateTime(2026, 10, 17, 11)),
      UpdatePrompt.flexible,
    );
  });

  test('below the minimum: the full-screen update, even after "not now"', () {
    expect(
      _decide(min: 50, dismissed: DateTime(2026, 10, 20)),
      UpdatePrompt.immediate,
    );
    // At or above the minimum: the banner as usual.
    expect(_decide(min: 49), UpdatePrompt.flexible);
    // Play doesn't allow the immediate kind: the banner instead.
    expect(_decide(min: 50, immediate: false), UpdatePrompt.flexible);
  });

  test('Play allows neither: nothing', () {
    expect(_decide(flexible: false, immediate: false), UpdatePrompt.none);
  });
}
