// Captures the steps of the user guide's short videos for chapters 4-7,
// holidays and times of day, daily learning, sync and backup
// (site/guide.html), from the real app widgets (not run in CI: it lives
// outside test/). Run from the repo root:
//   TZ=Asia/Jerusalem flutter test tool/screenshots/capture_guide_videos_learning_test.dart
// then animate them: python3 tool/screenshots/make_guide_videos.py
// Output: build/store_raw/v_*.png and build/store_raw/video_marks_learning.json.

// A test file kept outside test/, so the analyzer doesn't know it is one.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/learning/application/daily_parsha_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_harness.dart';
import 'video_steps.dart';

/// Lets the study texts load from site/ (real file reads).
Future<void> _load(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpVideos('learning');

  testWidgets('holidays', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await step(
      tester,
      'v_hol_1',
      marks: <String, Finder>{
        'cell': dayCell(15),
        'strip': byKey('day-features-carousel'),
      },
    );
    await openSettings(tester);
    await step(
      tester,
      'v_hol_2',
      marks: <String, Finder>{'israel': tileOf('לוח ארץ ישראל')},
    );
    endVideo();
  });

  testWidgets('zmanim', (WidgetTester tester) async {
    final ProviderContainer c = await pumpShotApp(
      tester,
      mode: ThemeMode.light,
    );
    c.read(calendarViewProvider.notifier).setViewType(CalendarViewType.day);
    await step(tester, 'v_zm_1', tap: find.byType(ExpansionTile).first);
    await step(
      tester,
      'v_zm_2',
      marks: <String, Finder>{'zmanim': find.byType(ExpansionTile).first},
    );
    await openSettings(tester);
    await scrollSettingsTo(tester, byKey('zmanim-havdalah'));
    await step(
      tester,
      'v_zm_3',
      marks: <String, Finder>{
        'city': byKey('zmanim-city'),
        'candles': byKey('zmanim-candles'),
        'havdalah': byKey('zmanim-havdalah'),
      },
      tap: byKey('zmanim-city'),
    );
    await step(tester, 'v_zm_4');
    endVideo();
  });

  testWidgets('halacha', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_halacha_mode_v1': 'on',
    });
    await pumpShotApp(tester, mode: ThemeMode.light);
    await _load(tester);
    await step(
      tester,
      'v_hal_1',
      marks: <String, Finder>{'dedication': byKey('daily-halacha-dedication')},
      tap: byKey('daily-halacha-learned'),
    );
    await step(tester, 'v_hal_2');
    endVideo();
  });

  testWidgets('parsha', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await openSettings(tester);
    final Finder tile = byKey('daily-learning-tile');
    await scrollSettingsTo(tester, tile);
    await step(tester, 'v_par_1', tap: tile);
    await step(
      tester,
      'v_par_2',
      marks: <String, Finder>{'switch': byKey('daily-parsha-switch')},
      tap: byKey('daily-parsha-switch'),
    );
    await step(
      tester,
      'v_par_3',
      marks: <String, Finder>{
        'modes': find.byWidgetPredicate(
          (Widget w) => w is RadioListTile<ParshaStudyMode>,
        ),
      },
      tap: byKey('daily-parsha-mode-targumRashi'),
    );
    await step(tester, 'v_par_4', tap: byKey('daily-parsha-open'));
    await _load(tester);
    await step(
      tester,
      'v_par_5',
      marks: <String, Finder>{'rashi': byKey('parsha-rashi').first},
    );
    endVideo();
  });

  testWidgets('sync', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await openSettings(tester);
    await step(
      tester,
      'v_sync_1',
      marks: <String, Finder>{'card': cardOf('סנכרון עם יומן Google')},
      tap: find.text('סנכרן עכשיו'),
    );
    await step(
      tester,
      'v_sync_2',
      marks: <String, Finder>{'card': cardOf('סנכרון עם יומן Google')},
    );
    endVideo();
  });

  testWidgets('backup', (WidgetTester tester) async {
    await pumpShotApp(tester, mode: ThemeMode.light);
    await openSettings(tester);
    final Finder card = cardOf('גיבוי ושחזור');
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await step(
      tester,
      'v_backup_1',
      marks: <String, Finder>{
        'card': card,
        'export': find.text('ייצוא').first,
        'share': find.text('שיתוף').first,
        'import': find.text('שחזור').first,
      },
    );
    endVideo();
  });
}
