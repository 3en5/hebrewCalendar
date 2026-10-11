// The "מצב כהה" switch's state (as in PowerWatch): follows the system until
// set, then the choice is stored per device and restored on the next start.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/features/settings/application/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('follows the system until the user chooses', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('setDark stores the choice and a new start restores it', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer first = ProviderContainer();
    await first.read(themeModeProvider.notifier).setDark(true);
    expect(first.read(themeModeProvider), ThemeMode.dark);
    first.dispose();

    final ProviderContainer second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(themeModeProvider);
    await Future<void>.delayed(Duration.zero);
    expect(second.read(themeModeProvider), ThemeMode.dark);

    await second.read(themeModeProvider.notifier).setDark(false);
    expect(second.read(themeModeProvider), ThemeMode.light);
  });
}
