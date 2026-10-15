// Owner request 2026-10-15: in a busy month the day's letters jumped up and
// down with how much text a day had. Now the letters sit at the same height
// in every cell and the event dots at the bottom.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/hebrew_date/jewish_day_info.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/day_cell.dart';
import 'package:hebrew_calendar/features/zmanim/presentation/shabbat_times.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';

Widget _cell(
  int day, {
  JewishDayLabel? label,
  ShabbatTime? shabbat,
  List<Color> dots = const <Color>[],
}) => Expanded(
  child: DayCell(
    hebrewDay: day,
    gregorianDay: day + 10,
    isToday: false,
    isSelected: false,
    isShabbat: false,
    drawEndLine: true,
    label: label,
    shabbatTime: shabbat,
    eventColors: dots,
  ),
);

void main() {
  for (final double height in <double>[72, 100]) {
    testWidgets('letters level and dots at the bottom ($height high)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('he'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _cell(1),
                  _cell(
                    2,
                    label: const JewishDayLabel(
                      kind: JewishDayKind.roshChodesh,
                      name: 'ראש חודש',
                    ),
                    dots: const <Color>[Colors.red, Colors.blue],
                  ),
                  _cell(
                    3,
                    label: const JewishDayLabel(
                      kind: JewishDayKind.parsha,
                      name: 'לך לך',
                    ),
                    shabbat: ShabbatTime(
                      isCandleLighting: false,
                      time: DateTime(2026, 10, 24, 18, 34),
                    ),
                    dots: const <Color>[Colors.green],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final List<double> tops = <double>[
        for (final String n in <String>['א׳', 'ב׳', 'ג׳'])
          tester.getTopLeft(find.text(n)).dy,
      ];
      expect(tops[1], moreOrLessEquals(tops[0], epsilon: 0.5));
      expect(tops[2], moreOrLessEquals(tops[0], epsilon: 0.5));
      final double dots2 = tester
          .getBottomLeft(find.byKey(const ValueKey<String>('event-dot-2')))
          .dy;
      final double dots3 = tester
          .getBottomLeft(find.byKey(const ValueKey<String>('event-dot-3')))
          .dy;
      expect(dots3, moreOrLessEquals(dots2, epsilon: 0.5));
      expect(dots2, greaterThan(height - 12));
      expect(tester.takeException(), isNull);
    });
  }
}
