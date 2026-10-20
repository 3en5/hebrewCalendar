// Captures the steps of the user guide's short videos for chapters 2-3,
// "אירועים" and "מתאריך לועזי לעברי" (site/guide.html), from the real app
// widgets (not run in CI: it lives outside test/). Run from the repo root:
//   TZ=Asia/Jerusalem flutter test tool/screenshots/capture_guide_videos_events_test.dart
// then animate them: python3 tool/screenshots/make_guide_videos.py
// Output: build/store_raw/v_*.png and build/store_raw/video_marks_events.json.

// A test file kept outside test/, so the analyzer doesn't know it is one.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';

import 'screens_harness.dart';
import 'video_steps.dart';

Finder _addMenuNewEvent() => byKey('add-menu-new-event');

void main() {
  setUpVideos('events');

  testWidgets('new event', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await step(tester, 'v_new_1', tap: find.byType(FloatingActionButton));
    await step(
      tester,
      'v_new_2',
      marks: <String, Finder>{
        'items': find.ancestor(
          of: find.byType(ListTile),
          matching: find.byType(BottomSheet),
        ),
      },
      tap: _addMenuNewEvent(),
    );
    await tester.enterText(find.byType(TextField).first, 'ארוחת ערב משפחתית');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await step(
      tester,
      'v_new_3',
      marks: <String, Finder>{'title': find.byType(TextField).first},
      tap: find.byType(Switch).first,
    );
    await step(
      tester,
      'v_new_4',
      marks: <String, Finder>{'date': find.text('תאריך עברי')},
      tap: find.text('שעת התחלה'),
    );
    await step(
      tester,
      'v_new_5',
      tap: find.descendant(
        of: find.byType(Dialog),
        matching: find.text('אישור'),
      ),
    );
    await step(
      tester,
      'v_new_6',
      marks: <String, Finder>{'time': find.text('שעת התחלה')},
      tap: find.byIcon(Icons.notifications_none),
    );
    await step(tester, 'v_new_7', tap: find.text('10 דקות לפני').last);
    await step(
      tester,
      'v_new_8',
      marks: <String, Finder>{'ten': tileOf('10 דקות לפני')},
      tap: find.text('סיום').last,
    );
    await step(tester, 'v_new_9', tap: find.textContaining('צבע:').first);
    await step(tester, 'v_new_10', tap: find.byTooltip('בזיליקום'));
    await step(tester, 'v_new_11', tap: find.byIcon(Icons.check));
    await step(
      tester,
      'v_new_12',
      marks: <String, Finder>{'event': find.text('ארוחת ערב משפחתית').first},
    );
    endVideo();
  });

  // "אירוע חוזר לפי התאריך העברי": a birthday on 10 Adar II, every year.
  testWidgets('recurrence', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    final CalendarViewNotifier view = c.read(calendarViewProvider.notifier);
    view.setFocusedDate(
      const HebrewDate(year: 5787, month: HebrewMonth.adarII, day: 10),
    );
    await tester.pumpAndSettle();
    await step(tester, 'v_rec_1', tap: find.byType(FloatingActionButton));
    await step(tester, 'v_rec_2', tap: _addMenuNewEvent());
    await tester.enterText(find.byType(TextField).first, 'יום הולדת לדוד');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await step(
      tester,
      'v_rec_3',
      marks: <String, Finder>{'title': find.byType(TextField).first},
      tap: find.byIcon(Icons.repeat),
    );
    await step(tester, 'v_rec_4', tap: tileOf('כל שנה (עברי)'));
    await step(
      tester,
      'v_rec_5',
      marks: <String, Finder>{
        'yearly': tileOf('כל שנה (עברי)'),
        'adar': find.byType(ChoiceChip),
      },
      tap: find.text('סיום'),
    );
    await step(
      tester,
      'v_rec_6',
      marks: <String, Finder>{'repeat': find.text('כל שנה (עברי)')},
      tap: find.byIcon(Icons.check),
    );
    await step(
      tester,
      'v_rec_7',
      marks: <String, Finder>{
        'event': find.text('יום הולדת לדוד').first,
        'cell': dayCell(10),
      },
    );
    // A year later: 5788 has one Adar, and the birthday is there.
    view.setFocusedDate(
      const HebrewDate(year: 5788, month: HebrewMonth.adar, day: 10),
    );
    await tester.pumpAndSettle();
    await step(
      tester,
      'v_rec_8',
      marks: <String, Finder>{
        'event': find.text('יום הולדת לדוד').first,
        'cell': dayCell(10),
      },
    );
    endVideo();
  });

  testWidgets('event details', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await step(
      tester,
      'v_details_1',
      tap: find.text('ארוחת חג אצל סבתא').first,
    );
    await step(
      tester,
      'v_details_2',
      marks: <String, Finder>{
        'maps': byKey('location-maps'),
        'waze': byKey('location-waze'),
      },
    );
    endVideo();
  });

  testWidgets('attendees', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    c.read(calendarViewProvider.notifier).setViewType(CalendarViewType.agenda);
    await step(tester, 'v_att_1', tap: find.text('פגישת צוות').first);
    // A weekly meeting: the app first asks what the edit applies to.
    await step(
      tester,
      'v_att_2',
      marks: <String, Finder>{'scopes': find.byType(Dialog)},
      tap: find.text('כל הסדרה'),
    );
    final Finder field = byKey('attendee-email-field');
    await tester.scrollUntilVisible(
      field,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(field, 'noa@example.com');
    await step(
      tester,
      'v_att_3',
      marks: <String, Finder>{'field': field},
      tap: find.descendant(of: field, matching: find.byType(IconButton)),
    );
    await step(
      tester,
      'v_att_4',
      marks: <String, Finder>{'list': find.textContaining('@example.com')},
    );
    endVideo();
  });

  testWidgets('delete', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await step(tester, 'v_del_1', tap: find.text('רופא שיניים').first);
    await step(tester, 'v_del_2', tap: find.byTooltip('מחיקה').last);
    await step(
      tester,
      'v_del_3',
      tap: find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('מחיקה'),
      ),
    );
    await step(tester, 'v_del_4');
    await step(tester, 'v_del_5', tap: find.text('פגישת צוות').first);
    await step(tester, 'v_del_6', tap: find.byTooltip('מחיקה').last);
    await step(
      tester,
      'v_del_7',
      marks: <String, Finder>{'scopes': find.byType(Dialog)},
    );
    endVideo();
  });

  testWidgets('significant', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    await step(tester, 'v_sig_1', tap: find.byType(FloatingActionButton));
    await step(tester, 'v_sig_2', tap: byKey('add-menu-significant-date'));
    final Finder segments = find.byWidgetPredicate(
      (Widget w) => w is SegmentedButton,
    );
    await step(
      tester,
      'v_sig_3',
      marks: <String, Finder>{'kinds': segments.first},
      tap: byKey('significant-name'),
    );
    await tester.enterText(byKey('significant-name'), 'דוד');
    Future<void> pick(String key, String text) async {
      await tester.tap(byKey(key));
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
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await step(
      tester,
      'v_sig_4',
      marks: <String, Finder>{
        'name': byKey('significant-name'),
        'date': byKey('significant-month'),
      },
      tap: find.text('אחרי השקיעה'),
    );
    await step(
      tester,
      'v_sig_5',
      marks: <String, Finder>{
        'sunset': segments.last,
        'preview': byKey('significant-preview'),
      },
    );
    await tester.scrollUntilVisible(
      byKey('significant-save'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await step(
      tester,
      'v_sig_6',
      marks: <String, Finder>{'preview': byKey('significant-preview')},
      tap: byKey('significant-save'),
    );
    await step(
      tester,
      'v_sig_7',
      marks: <String, Finder>{'snack': find.byType(SnackBar)},
    );
    // 15.3.1985 after sunset is 23 Adar 5745; this year, 23 Adar II.
    c
        .read(calendarViewProvider.notifier)
        .setFocusedDate(
          const HebrewDate(year: 5787, month: HebrewMonth.adarII, day: 23),
        );
    await step(tester, 'v_sig_8', marks: <String, Finder>{'cell': dayCell(23)});
    endVideo();
  });
}
