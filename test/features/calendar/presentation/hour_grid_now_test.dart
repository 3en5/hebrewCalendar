// Tester requests 2026-10-14: the hour grid opens an hour before the
// current time, and today's column carries a "now" line.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/core/theme/dimens.dart';
import 'package:hebrew_calendar/domain/event/event_occurrence.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date_engine.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/day_occurrences.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/hour_grid.dart';

const HebrewDateEngine _engine = HebrewDateEngine();

Future<void> _pumpGrid(WidgetTester tester, List<HebrewDate> days) =>
    tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: HourGrid(
                columns: <DayOccurrences>[
                  for (final HebrewDate day in days)
                    DayOccurrences(
                      date: day,
                      occurrences: const <EventOccurrence>[],
                    ),
                ],
                onEmptySlotTap: (_, _) {},
                onEventTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  final Finder nowLine = find.byKey(
    const ValueKey<String>('hour-grid-now-line'),
  );

  testWidgets("today's column shows the now line", (WidgetTester tester) async {
    final HebrewDate today = _engine.fromGregorian(DateTime.now());
    await _pumpGrid(tester, <HebrewDate>[
      _engine.addDays(today, -1),
      today,
      _engine.addDays(today, 1),
    ]);
    expect(nowLine, findsOneWidget);
  });

  testWidgets('no now line on a page without today', (
    WidgetTester tester,
  ) async {
    final HebrewDate today = _engine.fromGregorian(DateTime.now());
    await _pumpGrid(tester, <HebrewDate>[_engine.addDays(today, 10)]);
    expect(nowLine, findsNothing);
  });

  testWidgets('opens scrolled to an hour before now', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final HebrewDate today = _engine.fromGregorian(now);
    await _pumpGrid(tester, <HebrewDate>[today]);
    final ScrollController controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    final double viewport = tester
        .getSize(find.byType(SingleChildScrollView))
        .height;
    final double wanted = now.hour < 1
        ? 0
        : ((now.hour - 1) * 60 + now.minute) / 60 * hourRowHeight;
    final double expected = math.max(
      0,
      math.min(wanted, hourRowHeight * 24 - viewport),
    );
    expect(controller.offset, closeTo(expected, hourRowHeight / 20));
  });
}
