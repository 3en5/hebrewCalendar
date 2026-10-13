// M21: the settings section (sketch 12) and the day-view panel (sketch 10).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/zmanim/zmanim.dart';
import 'package:hebrew_calendar/features/zmanim/application/zmanim_settings.dart';
import 'package:hebrew_calendar/features/zmanim/presentation/zmanim_panel.dart';
import 'package:hebrew_calendar/features/zmanim/presentation/zmanim_settings_section.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('he'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object?>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('settings: city, candles and havdalah are picked in dialogs', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(const ZmanimSettingsSection(), c));
    await tester.pumpAndSettle();

    expect(find.text('זמני היום'), findsOneWidget);
    expect(find.text('ירושלים'), findsOneWidget);
    expect(find.text('לפי מנהג העיר (40 דקות)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('zmanim-city')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('חיפה'));
    await tester.pumpAndSettle();
    expect(c.read(zmanimSettingsProvider).cityId, 'haifa');

    await tester.tap(find.byKey(const ValueKey<String>('zmanim-candles')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('18 דקות לפני השקיעה'));
    await tester.pumpAndSettle();
    expect(c.read(zmanimSettingsProvider).candleLightingMinutes, 18);
    expect(find.text('18 דקות לפני השקיעה'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('zmanim-havdalah')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('72 דקות אחרי השקיעה (ר״ת)'));
    await tester.pumpAndSettle();
    expect(c.read(zmanimSettingsProvider).havdalah, HavdalahMethod.minutes72);
  });

  testWidgets('day panel: Friday lists candle lighting first, then the day', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(ZmanimPanel(day: DateTime(2026, 10, 23)), c));
    await tester.pumpAndSettle();
    expect(find.text('זמני היום · ירושלים'), findsOneWidget);

    await tester.tap(find.text('זמני היום · ירושלים'));
    await tester.pumpAndSettle();
    expect(find.text('הדלקת נרות'), findsOneWidget);
    expect(find.text('שקיעה'), findsOneWidget);
    expect(find.text('צאת שבת'), findsNothing);
    expect(
      tester.getTopLeft(find.text('הדלקת נרות')).dy,
      lessThan(tester.getTopLeft(find.text('עלות השחר')).dy),
    );
  });

  testWidgets('day panel is hidden when the times of day are off', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(zmanimSettingsProvider.notifier).setEnabled(false);
    await tester.pumpWidget(_wrap(ZmanimPanel(day: DateTime(2026, 10, 23)), c));
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
  });
}
