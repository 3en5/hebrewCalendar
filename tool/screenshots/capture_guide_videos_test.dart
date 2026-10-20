// Captures the steps of the user guide's short videos for chapter 1,
// "צעדים ראשונים" (site/guide.html), from the real app widgets (not run in
// CI: it lives outside test/). Chapters 2 and 4-7 are in
// capture_guide_videos_events_test.dart and _learning_test.dart. Run from
// the repo root:
//   TZ=Asia/Jerusalem flutter test tool/screenshots/capture_guide_videos_test.dart
// then animate them: python3 tool/screenshots/make_guide_videos.py
// Output: build/store_raw/v_*.png and build/store_raw/video_marks_start.json.

// A test file kept outside test/, so the analyzer doesn't know it is one.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_display_mode_provider.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/settings/application/text_size_provider.dart';
import 'package:hebrew_calendar/features/settings/presentation/widgets/text_size_tile.dart';

import 'screens_harness.dart';
import 'video_steps.dart';

void main() {
  setUpVideos('start');

  testWidgets('views', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    final CalendarViewNotifier view = c.read(calendarViewProvider.notifier);
    await step(
      tester,
      'v_views_1',
      tap: find.byIcon(Icons.arrow_drop_down).first,
    );
    await step(
      tester,
      'v_views_2',
      marks: <String, Finder>{
        'menu': find.byType(PopupMenuItem<CalendarViewType>),
      },
      tap: find.text('שבוע').last,
    );
    await step(tester, 'v_views_3');
    view.setViewType(CalendarViewType.day);
    await step(tester, 'v_views_4', tap: find.byType(ExpansionTile).first);
    await step(
      tester,
      'v_views_5',
      marks: <String, Finder>{'zmanim': find.byType(ExpansionTile).first},
    );
    view.setViewType(CalendarViewType.agenda);
    await step(tester, 'v_views_6');
    endVideo();
  });

  testWidgets('swipe', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    final Finder grid = find.byType(PageView).first;
    await step(
      tester,
      'v_swipe_1',
      swipe: grid,
      marks: <String, Finder>{'title': byKey('calendar-title')},
    );
    await step(
      tester,
      'v_swipe_2',
      marks: <String, Finder>{'title': byKey('calendar-title')},
      swipe: byKey('day-swipe-area'),
    );
    await step(
      tester,
      'v_swipe_3',
      marks: <String, Finder>{'day': byKey('day-swipe-area')},
    );
    endVideo();
  });

  testWidgets('day pop', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    final Finder cell = dayCell(10);
    await step(tester, 'v_pop_1', marks: <String, Finder>{'tap': cell});
    final TestGesture finger = await tester.startGesture(
      tester.getCenter(cell),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    await step(
      tester,
      'v_pop_2',
      settle: false,
      marks: <String, Finder>{'pop': byKey('day-pop')},
    );
    await finger.up();
    await tester.pumpAndSettle();
    endVideo();
  });

  testWidgets('go to', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await step(tester, 'v_goto_1', tap: find.byTooltip('מעבר לתאריך'));
    await step(
      tester,
      'v_goto_2',
      marks: <String, Finder>{
        'items': find.ancestor(
          of: find.byType(ListTile),
          matching: find.byType(BottomSheet),
        ),
      },
      tap: find.text('דילוג לתאריך עברי'),
    );
    await step(
      tester,
      'v_goto_3',
      tap: find.byType(DropdownButtonFormField<HebrewMonth>),
    );
    await step(tester, 'v_goto_4', tap: find.text('כסלו').last);
    await step(
      tester,
      'v_goto_5',
      marks: <String, Finder>{
        'month': find.byType(DropdownButtonFormField<HebrewMonth>),
      },
      tap: find.text('אישור'),
    );
    await step(
      tester,
      'v_goto_6',
      marks: <String, Finder>{'title': byKey('calendar-title')},
    );
    endVideo();
  });

  testWidgets('gregorian', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    await step(tester, 'v_greg_1', tap: byKey('calendar-title'));
    await step(tester, 'v_greg_2', tap: find.text('תצוגה לועזית').last);
    await step(
      tester,
      'v_greg_3',
      marks: <String, Finder>{
        'title': byKey('calendar-title'),
        'cell': find.byType(PageView).first,
      },
    );
    // Kept by the app past this test; the next videos are Hebrew again.
    await c
        .read(calendarDisplayModeProvider.notifier)
        .set(CalendarDisplayMode.hebrew);
    await tester.pumpAndSettle();
    endVideo();
  });

  testWidgets('search', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await step(tester, 'v_search_1', tap: find.byIcon(Icons.search));
    await tester.enterText(find.byType(TextField).first, 'יום');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await step(
      tester,
      'v_search_2',
      marks: <String, Finder>{'field': find.byType(TextField).first},
      tap: find.text('יום נישואין').last,
    );
    await step(tester, 'v_search_3');
    endVideo();
  });

  testWidgets('text size', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    await step(tester, 'v_size_1', tap: find.byIcon(Icons.more_vert));
    await step(tester, 'v_size_2', tap: find.text('הגדרות'));
    await scrollSettingsTo(tester, find.byType(TextSizeTile));
    await step(
      tester,
      'v_size_3',
      marks: <String, Finder>{'size': find.byType(TextSizeTile)},
      swipe: byKey('text-size-slider'),
      by: const Offset(-160, 0),
    );
    await c.read(textSizeProvider.notifier).set(1.25);
    await step(
      tester,
      'v_size_4',
      marks: <String, Finder>{'size': find.byType(TextSizeTile)},
      tap: backButton(),
    );
    await step(tester, 'v_size_5');
    await c.read(textSizeProvider.notifier).set(1.0);
    await tester.pumpAndSettle();
    endVideo();
  });

  testWidgets('dark', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await openSettings(tester);
    await scrollSettingsTo(tester, byKey('dark-mode-switch'));
    await step(tester, 'v_dark_1', tap: byKey('dark-mode-switch'));
    await step(
      tester,
      'v_dark_2',
      marks: <String, Finder>{'switch': byKey('dark-mode-switch')},
      tap: backButton(),
    );
    await step(tester, 'v_dark_3');
    endVideo();
  });
}
