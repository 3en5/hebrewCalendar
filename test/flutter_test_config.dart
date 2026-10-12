import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Runs before every test file. `SharedPreferences` has no platform side
/// under `flutter test`, and a call to it never completes there — which
/// hangs any test whose code path awaits it (e.g. the sync engine's
/// one-time full-resync flag). An empty in-memory store stands in for it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await testMain();
}
