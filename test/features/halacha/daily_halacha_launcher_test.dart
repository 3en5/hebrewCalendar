// M25: the daily halacha opens on the day's first visit, with the
// dedication, and the first visit asks whether to keep showing it.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/halacha/daily_halacha_source.dart';
import 'package:hebrew_calendar/data/halacha/halacha_cloud.dart';
import 'package:hebrew_calendar/domain/halacha/daily_halacha.dart';
import 'package:hebrew_calendar/features/halacha/application/daily_halacha_providers.dart';
import 'package:hebrew_calendar/features/halacha/presentation/daily_halacha_launcher.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hebrew_calendar/features/learning/application/daily_parsha_providers.dart';
import 'package:hebrew_calendar/features/learning/presentation/daily_learning_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCloud implements HalachaCloud {
  final List<String> calls = <String>[];

  @override
  Future<String?> dedicationFor(DateTime day) async =>
      'לעילוי נשמת משה בן יעקב';

  @override
  Future<double?> enabledShare() async => 0.45;

  @override
  Future<void> recordChoice({required bool? from, required bool to}) async =>
      calls.add('choice $from->$to');

  @override
  Future<void> recordLearned(DateTime day) async => calls.add('learned');
}

DailyHalachaSource _source() => DailyHalachaSource(
  baseUrl: 'https://example.test/ksa',
  client: MockClient(
    (http.Request r) async => http.Response.bytes(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'title': 'סימן ח׳, סעיפים א׳–ב׳',
          'sections': <Object?>[
            <String, Object?>{
              'siman': 8,
              'seif': 1,
              'text': 'מִשֶּׁעָלָה עַמּוּד הַשַּׁחַר',
            },
            <String, Object?>{
              'siman': 8,
              'seif': 2,
              'text': 'וְאָסוּר לֶאֱכוֹל',
            },
          ],
        }),
      ),
      200,
    ),
  ),
);

Future<_FakeCloud> _pump(WidgetTester tester) async {
  final _FakeCloud cloud = _FakeCloud();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        dailyHalachaSourceProvider.overrideWithValue(_source()),
        halachaCloudProvider.overrideWithValue(cloud),
      ],
      child: const MaterialApp(
        locale: Locale('he'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: <LocalizationsDelegate<Object>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: DailyHalachaLauncher(child: Scaffold(body: Text('home'))),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
  return cloud;
}

const ValueKey<String> _dialog = ValueKey<String>('daily-halacha-dialog');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('first visit: the dedication, and keep-showing learns', (
    WidgetTester tester,
  ) async {
    final _FakeCloud cloud = await _pump(tester);
    expect(find.byKey(_dialog), findsOneWidget);
    expect(find.text('לעילוי נשמת משה בן יעקב'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('daily-halacha-stop')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('daily-halacha-learned')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsNothing);
    expect(cloud.calls, containsAll(<String>['learned', 'choice null->true']));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_halacha_mode_v1'), 'on');
    expect(
      prefs.getString('daily_halacha_last_shown_v1'),
      dedicationDayKey(DateTime.now()),
    );
  });

  testWidgets('"don\'t show again" turns it off', (WidgetTester tester) async {
    final _FakeCloud cloud = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey<String>('daily-halacha-stop')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(cloud.calls, <String>['choice null->false']);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('daily_halacha_mode_v1'), 'off');
  });

  testWidgets('already shown today: it does not open again', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_halacha_mode_v1': 'on',
      'daily_halacha_last_shown_v1': dedicationDayKey(DateTime.now()),
    });
    await _pump(tester);
    expect(find.byKey(_dialog), findsNothing);
  });

  testWidgets('turned off: it does not open', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_halacha_mode_v1': 'off',
    });
    await _pump(tester);
    expect(find.byKey(_dialog), findsNothing);
  });

  testWidgets('later visits show only "שיננתי"', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_halacha_mode_v1': 'on',
      'daily_halacha_last_shown_v1': '2000-01-01',
    });
    await _pump(tester);
    expect(find.byKey(_dialog), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('daily-halacha-stop')),
      findsNothing,
    );
  });

  testWidgets('the daily learning page shows the share of learners', (
    WidgetTester tester,
  ) async {
    final _FakeCloud cloud = _FakeCloud();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          dailyHalachaSourceProvider.overrideWithValue(_source()),
          halachaCloudProvider.overrideWithValue(cloud),
        ],
        child: const MaterialApp(
          locale: Locale('he'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DailyLearningSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('45% לומדים כל יום'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('daily-halacha-switch')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(cloud.calls, <String>['choice null->false']);
  });

  testWidgets('the vote counts anyone with any daily study on', (
    WidgetTester tester,
  ) async {
    // Owner request 2026-10-20: the share is of users who learn anything.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_halacha_mode_v1': 'on',
      'daily_parsha_enabled_v1': true,
    });
    final _FakeCloud cloud = _FakeCloud();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[halachaCloudProvider.overrideWithValue(cloud)],
    );
    addTearDown(container.dispose);
    await container.read(dailyHalachaSettingsProvider.notifier).ready;
    await container.read(dailyParshaSettingsProvider.notifier).ready;
    // The halacha off, the portion still on: still learning, no change.
    await container
        .read(dailyHalachaSettingsProvider.notifier)
        .setEnabled(false);
    expect(cloud.calls, isEmpty);
    // The portion off too: now not learning.
    await container
        .read(dailyParshaSettingsProvider.notifier)
        .setEnabled(false);
    expect(cloud.calls, <String>['choice true->false']);
    // Either one on again: learning.
    await container.read(dailyParshaSettingsProvider.notifier).setEnabled(true);
    expect(cloud.calls, <String>['choice true->false', 'choice false->true']);
  });
}
