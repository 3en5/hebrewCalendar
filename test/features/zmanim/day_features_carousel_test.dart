// Owner request 2026-10-13: the day's features in one swipeable row under
// the month grid, the most relevant one for the current hour first.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/jewish_day_info.dart';
import 'package:hebrew_calendar/features/zmanim/application/zmanim_settings.dart';
import 'package:hebrew_calendar/features/zmanim/presentation/day_features_carousel.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const JewishDayLabel _parsha = JewishDayLabel(
  kind: JewishDayKind.parsha,
  name: 'נח',
);

TimedDayFeature _t(String label, int hour) =>
    TimedDayFeature(label: label, time: DateTime(2026, 10, 16, hour));

void main() {
  final DateTime day = DateTime(2026, 10, 16);
  final List<TimedDayFeature> times = <TimedDayFeature>[
    _t('sunset', 18),
    _t('sunrise', 6),
    _t('chatzos', 12),
  ];

  group('orderDayFeatures', () {
    test('the next time leads, then labels, then the rest wrapping', () {
      final List<Object> order = orderDayFeatures(
        times: times,
        labels: const <JewishDayLabel>[_parsha],
        day: day,
        now: DateTime(2026, 10, 16, 7, 18),
      );
      expect(
        order.map((Object o) => o is TimedDayFeature ? o.label : 'parsha'),
        <String>['chatzos', 'parsha', 'sunset', 'sunrise'],
      );
    });

    test('uses the current hour on another day too', () {
      final List<Object> order = orderDayFeatures(
        times: times,
        labels: const <JewishDayLabel>[],
        day: day,
        now: DateTime(2026, 10, 13, 15),
      );
      expect((order.first as TimedDayFeature).label, 'sunset');
    });

    test('after the last time the day starts over; no times = labels', () {
      final List<Object> late = orderDayFeatures(
        times: times,
        labels: const <JewishDayLabel>[],
        day: day,
        now: DateTime(2026, 10, 16, 22),
      );
      expect((late.first as TimedDayFeature).label, 'sunrise');
      expect(
        orderDayFeatures(
          times: const <TimedDayFeature>[],
          labels: const <JewishDayLabel>[_parsha],
          day: day,
          now: DateTime(2026, 10, 16, 22),
        ),
        <Object>[_parsha],
      );
    });
  });

  testWidgets('shows labels and times in a scrollable row with arrows', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          locale: const Locale('he'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object?>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: DayFeaturesCarousel(
              // A Friday: candle lighting is among the times.
              day: day,
              labels: const <JewishDayLabel>[_parsha],
              now: DateTime(2026, 10, 16, 7),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('פרשת נח'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    // Swipe through to candle lighting, which sits late in the row.
    await tester.dragUntilVisible(
      find.textContaining('הדלקת נרות'),
      find.byKey(const ValueKey<String>('day-features-carousel')),
      const Offset(200, 0),
    );
    expect(find.textContaining('הדלקת נרות'), findsOneWidget);

    // Times of day turned off: only the labels remain.
    await c.read(zmanimSettingsProvider.notifier).setEnabled(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('הדלקת נרות'), findsNothing);
    expect(find.text('פרשת נח'), findsOneWidget);
  });
}
