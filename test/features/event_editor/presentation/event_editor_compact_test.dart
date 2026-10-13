// The compact editor (owner-approved sketches 4-7, 2026-10-13): one row per
// setting; the reminders sheet allows several reminders and a custom one.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_editor_controller.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/event_editor/presentation/event_editor_screen.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';

const HebrewDate _date = HebrewDate(
  year: 5787,
  month: HebrewMonth.cheshvan,
  day: 8,
);

Widget _wrap(InMemoryEventRepository repository) => ProviderScope(
  overrides: <Override>[eventRepositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(
    locale: Locale('he'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: <LocalizationsDelegate<Object?>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: EventEditorScreen(args: EventEditorArgs(initialDate: _date)),
  ),
);

void main() {
  testWidgets('several reminders, including a custom one, are saved', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'רופא');

    expect(find.text('ללא תזכורת'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 דקות לפני'));
    await tester.tap(find.text('יום לפני'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('מותאם אישית'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('מותאם אישית'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('custom-reminder-amount')),
      '3',
    );
    await tester.tap(find.text('אישור'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('סיום'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('סיום'));
    await tester.pumpAndSettle();
    expect(find.text('30 דקות לפני, 3 שעות לפני, יום לפני'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    final Event saved = (await repository.getAllForSync()).single;
    expect(saved.reminderMinutesBefore, <int>[30, 180, 1440]);
  });
}
