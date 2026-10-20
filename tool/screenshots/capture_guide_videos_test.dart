// Captures the steps of the user guide's short videos (site/guide.html)
// from the real app widgets, and where each thing a step points at is
// (not run in CI: it lives outside test/). Run from the repo root:
//   TZ=Asia/Jerusalem flutter test tool/screenshots/capture_guide_videos_test.dart
// then animate them: python3 tool/screenshots/make_guide_videos.py
// Output: build/store_raw/v_<video>_<n>.png and build/store_raw/video_marks.json.

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
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_harness.dart';

/// Step image name -> mark name -> [left, top, right, bottom] in image
/// pixels. The mark "tap" is what the next step's finger presses.
final Map<String, Map<String, List<double>>> _marks =
    <String, Map<String, List<double>>>{};

List<double> _box(String name, String key, Finder finder) {
  Rect? box;
  for (final Element e in finder.evaluate()) {
    final RenderBox r = e.renderObject! as RenderBox;
    final Rect rect = MatrixUtils.transformRect(
      r.getTransformTo(null),
      Offset.zero & r.size,
    );
    box = box == null ? rect : box.expandToInclude(rect);
  }
  if (box == null) {
    throw StateError('$name: nothing found for $key');
  }
  return <double>[
    box.left * shotDpr,
    box.top * shotDpr,
    box.right * shotDpr,
    box.bottom * shotDpr,
  ];
}

/// Shoots step [name] and records [marks]; [tap] is then pressed.
Future<void> _step(
  WidgetTester tester,
  String name, {
  Map<String, Finder> marks = const <String, Finder>{},
  Finder? tap,
}) async {
  // Not [shot]: it turns shadows off after each step, and widgets built
  // after that would keep the flat outline (the test resets it at its end).
  await tester.pumpAndSettle();
  await shotNow(tester, name);
  _marks[name] = <String, List<double>>{
    for (final MapEntry<String, Finder> m in marks.entries)
      m.key: _box(name, m.key, m.value),
    if (tap != null) 'tap': _box(name, 'tap', tap),
  };
  if (tap != null) {
    await tester.tap(tap);
    await tester.pumpAndSettle();
  }
}

Finder _tile(String text) =>
    find.ancestor(of: find.text(text).last, matching: find.byType(ListTile));

Finder _day(int hebrewDay) => find.byWidgetPredicate(
  (Widget w) => w is DayCell && w.onTap != null && w.hebrewDay == hebrewDay,
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await loadShotFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues(shotPrefs()));
  tearDownAll(() {
    File(
      'build/store_raw/video_marks.json',
    ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(_marks));
  });

  // "אירוע חוזר לפי התאריך העברי": a birthday on 10 Adar II, every year.
  testWidgets('recurrence video', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    final CalendarViewNotifier view = c.read(calendarViewProvider.notifier);
    view.setFocusedDate(
      const HebrewDate(year: 5787, month: HebrewMonth.adarII, day: 10),
    );
    await tester.pumpAndSettle();
    await _step(tester, 'v_rec_1', tap: find.byType(FloatingActionButton));
    await _step(
      tester,
      'v_rec_2',
      tap: find.byKey(const ValueKey<String>('add-menu-new-event')),
    );
    await tester.enterText(find.byType(TextField).first, 'יום הולדת לדוד');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _step(
      tester,
      'v_rec_3',
      marks: <String, Finder>{'title': find.byType(TextField).first},
      tap: find.byIcon(Icons.repeat),
    );
    await _step(tester, 'v_rec_4', tap: _tile('כל שנה (עברי)'));
    await _step(
      tester,
      'v_rec_5',
      marks: <String, Finder>{
        'yearly': _tile('כל שנה (עברי)'),
        'adar': find.byType(ChoiceChip),
      },
      tap: find.text('סיום'),
    );
    await _step(
      tester,
      'v_rec_6',
      marks: <String, Finder>{'repeat': find.text('כל שנה (עברי)')},
      tap: find.byIcon(Icons.check),
    );
    await _step(
      tester,
      'v_rec_7',
      marks: <String, Finder>{
        'event': find.text('יום הולדת לדוד').first,
        'cell': _day(10),
      },
    );
    // A year later: 5788 has one Adar, and the birthday is there.
    view.setFocusedDate(
      const HebrewDate(year: 5788, month: HebrewMonth.adar, day: 10),
    );
    await tester.pumpAndSettle();
    await _step(
      tester,
      'v_rec_8',
      marks: <String, Finder>{
        'event': find.text('יום הולדת לדוד').first,
        'cell': _day(10),
      },
    );
    debugDisableShadows = true;
  });
}
