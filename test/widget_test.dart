// Verifies the M0 app shell: the placeholder home screen renders under a
// right-to-left Directionality (Hebrew locale) and shows the app title.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hebrew_calendar/main.dart';

void main() {
  testWidgets('renders placeholder screen in RTL with app title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HebrewCalendarApp()));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(Scaffold));
    expect(Directionality.of(context), TextDirection.rtl);

    expect(find.text('יומן עברי'), findsWidgets);
    expect(find.text('M0 — תשתית מוכנה'), findsOneWidget);
  });
}
