// Captures the raw phone screens for the Play Store screenshots from the
// real app widgets with sample events (not run in CI: it lives outside
// test/). Run from the repo root:
//   flutter test tool/screenshots/capture_store_screens_test.dart
// then frame them: python3 tool/brand/make_store_screenshots.py
// Output: build/store_raw/*.png (1080x2400).

// A test file kept outside test/, so the analyzer doesn't know it is one.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_harness.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await loadShotFonts();
  });
  // A fresh preferences store per screen, so dark mode doesn't carry over.
  setUp(() => SharedPreferences.setMockInitialValues(shotPrefs()));

  testWidgets('month', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await shot(tester, '1_month');
  });

  testWidgets('month dark', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.dark);
    await shot(tester, '6_month_dark');
  });

  testWidgets('week', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    c.read(calendarViewProvider.notifier).setViewType(CalendarViewType.week);
    await shot(tester, '2_week');
  });

  testWidgets('agenda', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    c.read(calendarViewProvider.notifier).setViewType(CalendarViewType.agenda);
    await shot(tester, '8_agenda');
  });

  testWidgets('editor', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    // A date in Adar of a leap year, so the leap-year Adar choice shows.
    c
        .read(calendarViewProvider.notifier)
        .setFocusedDate(
          const HebrewDate(year: 5787, month: HebrewMonth.adarII, day: 10),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('add-menu-new-event')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'יום הולדת לדוד');
    await tester.tap(find.byIcon(Icons.repeat));
    await tester.pumpAndSettle();
    await tester.tap(find.text('כל שנה (עברי)'));
    await tester.pumpAndSettle();
    await shot(tester, '3b_editor_recurrence');
    await tester.ensureVisible(find.text('סיום'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('סיום'));
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await shot(tester, '3_editor');
  });

  testWidgets('search', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'יום');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await shot(tester, '4_search');
  });

  testWidgets('settings', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('הגדרות'));
    await shot(tester, '5_settings');
  });

  testWidgets('halacha', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_halacha_mode_v1': 'on',
    });
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await shot(tester, '9_halacha');
  });

  testWidgets('significant', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('add-menu-significant-date')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('significant-name')),
      'דוד',
    );
    Future<void> pick(String key, String text) async {
      await tester.tap(find.byKey(ValueKey<String>(key)));
      await tester.pumpAndSettle();
      final Finder menu = find.byType(Scrollable).last;
      final Finder item = find.descendant(of: menu, matching: find.text(text));
      await tester.scrollUntilVisible(item, 200, scrollable: menu);
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    await pick('significant-day', '15');
    await pick('significant-month', 'מרץ');
    await pick('significant-year', '1985');
    await tester.tap(find.text('אחרי השקיעה'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await shot(tester, '10_significant');
  });

  testWidgets('day zmanim', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    c.read(calendarViewProvider.notifier).setViewType(CalendarViewType.day);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile).first);
    await shot(tester, '11_day');
  });

  testWidgets('settings halacha', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('הגדרות'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await shot(tester, '12_settings_more');
  });

  testWidgets('about', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('אודות').last);
    await shot(tester, '7_about');
  });
}
