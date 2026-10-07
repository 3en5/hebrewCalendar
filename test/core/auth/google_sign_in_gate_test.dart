// Tests for the process-wide idempotent GoogleSignIn.initialize() guard
// (device-feedback round #3 — see `lib/core/auth/google_sign_in_gate.dart`'s
// doc for the confirmed root cause it fixes). The initializer is injected as
// a plain callback rather than a real `GoogleSignIn`, so these tests never
// touch the actual plugin (no channel handler under `flutter test`).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/core/auth/google_sign_in_gate.dart';

void main() {
  setUp(GoogleSignInGate.resetForTesting);

  test(
    'ensure() calls the initializer exactly once across repeated calls',
    () async {
      int callCount = 0;
      Future<void> initializer() async {
        callCount++;
      }

      await GoogleSignInGate.ensure(initializer);
      await GoogleSignInGate.ensure(initializer);
      await GoogleSignInGate.ensure(initializer);

      expect(callCount, 1);
    },
  );

  test('concurrent ensure() calls before the initializer resolves still only '
      'run it once — every caller awaits the same in-flight future', () async {
    int callCount = 0;
    final List<void Function()> pendingCompletions = <void Function()>[];
    Future<void> initializer() {
      callCount++;
      final Completer<void> completer = Completer<void>();
      pendingCompletions.add(completer.complete);
      return completer.future;
    }

    final Future<void> first = GoogleSignInGate.ensure(initializer);
    final Future<void> second = GoogleSignInGate.ensure(initializer);
    expect(callCount, 1);

    pendingCompletions.single();
    await first;
    await second;

    expect(callCount, 1);
  });

  test('a different initializer after resetForTesting() runs again — the '
      'guard is per-process-lifetime, not permanent', () async {
    int firstCount = 0;
    int secondCount = 0;
    await GoogleSignInGate.ensure(() async => firstCount++);
    expect(firstCount, 1);

    GoogleSignInGate.resetForTesting();
    await GoogleSignInGate.ensure(() async => secondCount++);

    expect(firstCount, 1);
    expect(secondCount, 1);
  });
}
