import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrewcalendar/app.dart';
import 'package:hebrewcalendar/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
      child: const HebrewCalendarApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Hebrew UI is right-to-left', (tester) async {
    await _pumpApp(tester, {'settings.language': 'he'});
    expect(find.text('תאריך עברי'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('תאריך עברי')));
    expect(dir, TextDirection.rtl);
  });

  testWidgets('English UI and navigation to settings', (tester) async {
    await _pumpApp(tester, {'settings.language': 'en'});
    expect(find.text('Hebrew date'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Calendar location'), findsOneWidget);

    // Switch the app language to Hebrew from the settings screen.
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('עברית'));
    await tester.pumpAndSettle();
    expect(find.text('הגדרות'), findsWidgets);
  });
}
