// Shared by the guide video captures (capture_guide_videos_*_test.dart):
// a step is one screen of a video, written as build/store_raw/v_*.png,
// with where the things the video points at are on it.

// Used by test files kept outside test/, so the analyzer doesn't know them.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/day_cell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_harness.dart';

/// Step image name -> mark name -> [left, top, right, bottom] in image
/// pixels. The mark "tap" is what the finger presses at the end of the
/// step; "swipe" is the area a finger swipes across.
final Map<String, Map<String, List<double>>> _marks =
    <String, Map<String, List<double>>>{};

/// The setUp of every video capture file; the marks go to
/// build/store_raw/video_marks_[tag].json.
void setUpVideos(String tag) {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await loadShotFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues(shotPrefs()));
  tearDownAll(() {
    File(
      'build/store_raw/video_marks_$tag.json',
    ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(_marks));
  });
}

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

/// Shoots step [name] and records [marks]; [tap] is then pressed, or
/// [swipe] dragged by [by] (logical pixels).
Future<void> step(
  WidgetTester tester,
  String name, {
  Map<String, Finder> marks = const <String, Finder>{},
  Finder? tap,
  Finder? swipe,
  Offset by = const Offset(400, 0),
  bool settle = true,
}) async {
  // Not [shot]: it turns shadows off after each step, and widgets built
  // after that would keep the flat outline ([endVideo] resets it).
  if (settle) {
    await tester.pumpAndSettle();
  }
  await shotNow(tester, name);
  _marks[name] = <String, List<double>>{
    for (final MapEntry<String, Finder> m in marks.entries)
      m.key: _box(name, m.key, m.value),
    if (tap != null) 'tap': _box(name, 'tap', tap),
    if (swipe != null) 'swipe': _box(name, 'swipe', swipe),
  };
  if (tap != null) {
    await tester.tap(tap);
    await tester.pumpAndSettle();
  }
  if (swipe != null) {
    await tester.fling(swipe, by, 1200);
    await tester.pumpAndSettle();
  }
}

/// The last line of every video test (the framework checks it is reset).
void endVideo() => debugDisableShadows = true;

Finder tileOf(String text) =>
    find.ancestor(of: find.text(text).last, matching: find.byType(ListTile));

Finder cardOf(String text) =>
    find.ancestor(of: find.text(text).first, matching: find.byType(Card)).first;

Finder byKey(String key) => find.byKey(ValueKey<String>(key));

/// The month view's cell of [hebrewDay] in the shown month.
Finder dayCell(int hebrewDay) => find.byWidgetPredicate(
  (Widget w) => w is DayCell && w.onTap != null && w.hebrewDay == hebrewDay,
);

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('הגדרות'));
  await tester.pumpAndSettle();
}

/// Scrolls the settings until [target] is in view, near the top.
Future<void> scrollSettingsTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// The app bar's back arrow (the app's own, not Cupertino's).
Finder backButton() => find.byType(BackButton);
