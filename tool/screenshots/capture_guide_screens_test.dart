// Captures the user guide's screens (site/guide.html) from the real app
// widgets, and where each thing the guide points at is on them (not run in
// CI: it lives outside test/). Run from the repo root:
//   TZ=Asia/Jerusalem flutter test tool/screenshots/capture_guide_screens_test.dart
// then draw the frames and arrows: python3 tool/screenshots/annotate_guide.py
// Output: build/store_raw/g_*.png and build/store_raw/guide_marks.json.

// A test file kept outside test/, so the analyzer doesn't know it is one.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/day_cell.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/event_block.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_harness.dart';

/// Shot name -> mark name -> [left, top, right, bottom] in image pixels.
final Map<String, Map<String, List<double>>> _marks =
    <String, Map<String, List<double>>>{};

/// Records where [finders] are on the screen of shot [name]; a finder that
/// matches several widgets marks the box around all of them.
void _mark(String name, Map<String, Finder> finders) {
  final Map<String, List<double>> marks = <String, List<double>>{};
  finders.forEach((String key, Finder finder) {
    Rect? box;
    for (final Element e in finder.evaluate()) {
      final RenderBox r = e.renderObject! as RenderBox;
      // Through every transform on the way, so a scaled widget (the day
      // pop) is marked at the size it is drawn.
      final Rect rect = MatrixUtils.transformRect(
        r.getTransformTo(null),
        Offset.zero & r.size,
      );
      box = box == null ? rect : box.expandToInclude(rect);
    }
    if (box == null) {
      throw StateError('$name: nothing found for $key');
    }
    marks[key] = <double>[
      box.left * shotDpr,
      box.top * shotDpr,
      box.right * shotDpr,
      box.bottom * shotDpr,
    ];
  });
  _marks[name] = marks;
}

Finder _tile(String text) =>
    find.ancestor(of: find.text(text).last, matching: find.byType(ListTile));

Finder _card(String text) =>
    find.ancestor(of: find.text(text).first, matching: find.byType(Card)).first;

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('הגדרות'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await loadShotFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues(shotPrefs()));
  tearDownAll(() {
    File(
      'build/store_raw/guide_marks.json',
    ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(_marks));
  });

  testWidgets('month', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await shot(tester, 'g_month');
    _mark('g_month', <String, Finder>{
      'cell': find.byWidgetPredicate(
        (Widget w) => w is DayCell && w.onTap != null && w.hebrewDay == 15,
      ),
      'day': find.byKey(const ValueKey<String>('day-swipe-area')),
    });
  });

  testWidgets('overflow menu', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byIcon(Icons.more_vert));
    await shot(tester, 'g_overflow');
  });

  testWidgets('view menu', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
    await shot(tester, 'g_view_menu');
    _mark('g_view_menu', <String, Finder>{
      'menu': find.byType(PopupMenuItem<CalendarViewType>),
    });
  });

  testWidgets('week', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    c.read(calendarViewProvider.notifier).setViewType(CalendarViewType.week);
    await shot(tester, 'g_week');
    _mark('g_week', <String, Finder>{
      'event': find
          .ancestor(
            of: find.text('ארוחת חג אצל סבתא'),
            matching: find.byType(EventBlock),
          )
          .first,
    });
  });

  testWidgets('day', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    c.read(calendarViewProvider.notifier).setViewType(CalendarViewType.day);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile).first);
    await shot(tester, 'g_day');
    _mark('g_day', <String, Finder>{
      'zmanim': find.byType(ExpansionTile).first,
    });
  });

  testWidgets('agenda', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    c.read(calendarViewProvider.notifier).setViewType(CalendarViewType.agenda);
    await shot(tester, 'g_agenda');
  });

  testWidgets('day pop', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    final Finder cell = find.byWidgetPredicate(
      (Widget w) => w is DayCell && w.onTap != null && w.hebrewDay == 10,
    );
    final TestGesture finger = await tester.startGesture(
      tester.getCenter(cell),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    await shotNow(tester, 'g_day_pop');
    _mark('g_day_pop', <String, Finder>{
      'pop': find.byKey(const ValueKey<String>('day-pop')),
    });
    await finger.up();
    await tester.pumpAndSettle();
    debugDisableShadows = true;
  });

  testWidgets('go to', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byTooltip('מעבר לתאריך'));
    await shot(tester, 'g_goto');
    _mark('g_goto', <String, Finder>{
      'button': find.byTooltip('מעבר לתאריך'),
      'items': find.ancestor(
        of: find.byType(ListTile),
        matching: find.byType(BottomSheet),
      ),
    });
  });

  testWidgets('search', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'יום');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await shot(tester, 'g_search');
    _mark('g_search', <String, Finder>{'field': find.byType(TextField).first});
  });

  testWidgets('dark', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.dark);
    await shot(tester, 'g_dark');
  });

  testWidgets('add menu', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.tap(find.byType(FloatingActionButton));
    await shot(tester, 'g_add_menu');
    _mark('g_add_menu', <String, Finder>{
      'items': find.ancestor(
        of: find.byType(ListTile),
        matching: find.byType(BottomSheet),
      ),
    });
  });

  testWidgets('recurrence', (WidgetTester tester) async {
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
    await shot(tester, 'g_recurrence');
    _mark('g_recurrence', <String, Finder>{
      'yearly': _tile('כל שנה (עברי)'),
      'adar': find.byType(ChoiceChip),
    });
  });

  testWidgets('event sheet', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.tap(find.text('ארוחת חג אצל סבתא').first);
    await shot(tester, 'g_event_sheet');
    _mark('g_event_sheet', <String, Finder>{
      'map': find.byWidgetPredicate((Widget w) => w is OutlinedButton),
    });
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
    await shot(tester, 'g_significant');
    final Finder segments = find.byWidgetPredicate(
      (Widget w) => w is SegmentedButton,
    );
    _mark('g_significant', <String, Finder>{
      'kinds': segments.first,
      'sunset': segments.last,
      'preview': find.byKey(const ValueKey<String>('significant-preview')),
    });
  });

  testWidgets('settings', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await _openSettings(tester);
    await shot(tester, 'g_settings');
    _mark('g_settings', <String, Finder>{
      'sync': _card('סנכרון עם יומן Google'),
    });
  });

  testWidgets('settings more', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await _openSettings(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await shot(tester, 'g_settings_more');
    _mark('g_settings_more', <String, Finder>{
      'backup': _card('גיבוי ושחזור'),
      'guide': find.byKey(const ValueKey<String>('user-guide')),
    });
  });

  testWidgets('halacha', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_halacha_mode_v1': 'on',
    });
    await pumpShotApp(tester, mode: ThemeMode.light);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await shot(tester, 'g_halacha');
    _mark('g_halacha', <String, Finder>{
      'dedication': find.byKey(
        const ValueKey<String>('daily-halacha-dedication'),
      ),
      'learned': find.byKey(const ValueKey<String>('daily-halacha-learned')),
    });
  });
}
