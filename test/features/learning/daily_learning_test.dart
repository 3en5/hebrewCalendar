// M26 (sketch 68): the daily learning page and the morning window's tabs.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hebrew_calendar/data/halacha/halacha_cloud.dart';
import 'package:hebrew_calendar/domain/halacha/daily_halacha.dart';
import 'package:hebrew_calendar/features/halacha/application/daily_halacha_providers.dart';
import 'package:hebrew_calendar/domain/learning/daily_parsha.dart';
import 'package:hebrew_calendar/features/learning/application/daily_parsha_providers.dart';
import 'package:hebrew_calendar/features/learning/presentation/daily_learning_dialog.dart';
import 'package:hebrew_calendar/features/learning/presentation/daily_learning_settings_screen.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home, {ProviderContainer? container}) {
  final Widget app = MaterialApp(
    locale: const Locale('he'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
  return container == null
      ? ProviderScope(child: app)
      : UncontrolledProviderScope(container: container, child: app);
}

const DailyHalacha _halacha = DailyHalacha(
  title: 'סימן א׳, סעיף א׳',
  sections: <HalachaSection>[
    HalachaSection(siman: 1, seif: 1, text: 'יתגבר כארי לעמוד בבוקר'),
  ],
);

ParshaOfDay _parsha(ParshaStudyMode mode) => ParshaOfDay(
  parsha: DailyParsha.fromJson(
    jsonDecode(
      File('site/learning/parsha/lech_lecha-2.json').readAsStringSync(),
    ),
  )!,
  parshaName: 'לך לך',
  aliyah: 2,
  mode: mode,
);

Future<List<LearningTrack>> _open(
  WidgetTester tester, {
  required ParshaStudyMode mode,
  required Set<LearningTrack> done,
}) async {
  final List<LearningTrack> finished = <LearningTrack>[];
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => showDailyLearningDialog(
              context,
              halacha: _halacha,
              parsha: _parsha(mode),
              dedication: 'לעילוי נשמת',
              dateLabel: 'ז׳ חשוון',
              done: done,
              onDone: (LearningTrack t) async => finished.add(t),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return finished;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('opens on the study not done yet, marked with a ✓', (
    WidgetTester tester,
  ) async {
    final List<LearningTrack> finished = await _open(
      tester,
      mode: ParshaStudyMode.targum,
      done: <LearningTrack>{LearningTrack.halacha},
    );
    expect(find.text('שניים מקרא ואחד תרגום'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('פעמיים'), findsWidgets);
    expect(find.text('ת״א'), findsWidgets);
    expect(find.byKey(const ValueKey<String>('parsha-rashi')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('daily-learning-done-parsha')),
    );
    await tester.pumpAndSettle();
    expect(finished, <LearningTrack>[LearningTrack.parsha]);
    // Both done: the window closes.
    expect(
      find.byKey(const ValueKey<String>('daily-learning-dialog')),
      findsNothing,
    );
  });

  testWidgets('"שיננתי" moves on to the portion', (WidgetTester tester) async {
    final List<LearningTrack> finished = await _open(
      tester,
      mode: ParshaStudyMode.chumashRashi,
      done: <LearningTrack>{},
    );
    expect(find.text('יתגבר כארי לעמוד בבוקר'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('daily-learning-done-halacha')),
    );
    await tester.pumpAndSettle();
    expect(finished, <LearningTrack>[LearningTrack.halacha]);
    expect(find.text('חומש עם רש״י'), findsOneWidget);
    // Chumash with Rashi: the verse once, no targum, Rashi under it.
    expect(find.text('פעמיים'), findsNothing);
    expect(find.text('ת״א'), findsNothing);
    expect(find.byKey(const ValueKey<String>('parsha-rashi')), findsWidgets);
  });

  testWidgets('the settings page turns the portion on and keeps the mode', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        halachaCloudProvider.overrideWithValue(const OfflineHalachaCloud()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _app(const DailyLearningSettingsScreen(), container: container),
    );
    await tester.pumpAndSettle();
    final Finder rashiMode = find.byKey(
      const ValueKey<String>('daily-parsha-mode-targumRashi'),
    );
    // Off: the modes can't be picked yet.
    expect(
      tester.widget<RadioListTile<ParshaStudyMode>>(rashiMode).onChanged,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey<String>('daily-parsha-switch')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(rashiMode);
    await tester.tap(rashiMode);
    await tester.pumpAndSettle();
    final DailyParshaSettings settings = container.read(
      dailyParshaSettingsProvider,
    );
    expect(settings.enabled, isTrue);
    expect(settings.mode, ParshaStudyMode.targumRashi);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('daily_parsha_enabled_v1'), isTrue);
    expect(prefs.getString('daily_parsha_mode_v1'), 'targumRashi');
  });
}
