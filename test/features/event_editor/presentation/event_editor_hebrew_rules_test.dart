// Widget tests for the editor's Hebrew-calendar choices: the leap-year Adar
// and day-30 options of a yearly event (M15), and setting the date from a
// Gregorian date with the before/after sunset question (M16).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_editor_controller.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/event_editor/presentation/event_editor_screen.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:hebrew_calendar/l10n/app_localizations_he.dart';

Widget _wrap(Widget child, InMemoryEventRepository repository) {
  return ProviderScope(
    overrides: <Override>[
      eventRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      locale: const Locale('he'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

Future<Event> _saveAndRead(
  WidgetTester tester,
  InMemoryEventRepository repository,
) async {
  await tester.tap(find.byIcon(Icons.check));
  await tester.pumpAndSettle();
  return (await repository.getAllForSync()).single;
}

void main() {
  final AppLocalizationsHe l10n = AppLocalizationsHe();

  testWidgets('a yearly event in Adar offers the leap-year choice, '
      'defaulting to Adar II, and saves "both"', (WidgetTester tester) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);
    const HebrewDate adar = HebrewDate(
      year: 5786,
      month: HebrewMonth.adar,
      day: 10,
    );
    await tester.pumpWidget(
      _wrap(
        const EventEditorScreen(args: EventEditorArgs(initialDate: adar)),
        repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'אזכרה');

    final Finder yearly = find.text(l10n.recurrenceTypeYearly);
    await tester.dragUntilVisible(
      yearly,
      find.byType(ListView),
      const Offset(0, -100),
    );
    // dragUntilVisible can stop inside the cache extent, before the widget
    // is hit-testable (docs/LESSONS.md): nudge a little further.
    await tester.drag(find.byType(ListView), const Offset(0, -50));
    await tester.pumpAndSettle();
    await tester.tap(yearly);
    await tester.pumpAndSettle();

    final Finder both = find.text(l10n.eventLeapAdarBoth);
    await tester.dragUntilVisible(
      both,
      find.byType(ListView),
      const Offset(0, -100),
    );
    // dragUntilVisible can stop inside the cache extent, before the widget
    // is hit-testable (docs/LESSONS.md): nudge a little further.
    await tester.drag(find.byType(ListView), const Offset(0, -50));
    await tester.pumpAndSettle();
    final ChoiceChip adarII = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, l10n.eventLeapAdarII),
    );
    expect(adarII.selected, isTrue);
    expect(find.text(l10n.eventShortMonthLabel), findsNothing);

    await tester.tap(both);
    await tester.pumpAndSettle();

    final Event saved = await _saveAndRead(tester, repository);
    expect(saved.recurrence.type, RecurrenceType.hebrewYearly);
    expect(saved.recurrence.leapAdar, LeapAdarPolicy.both);
  });

  testWidgets('a yearly event on day 30 offers the short-month choice', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);
    const HebrewDate day30 = HebrewDate(
      year: 5786,
      month: HebrewMonth.cheshvan,
      day: 30,
    );
    await tester.pumpWidget(
      _wrap(
        const EventEditorScreen(args: EventEditorArgs(initialDate: day30)),
        repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'יום הולדת');

    final Finder yearly = find.text(l10n.recurrenceTypeYearly);
    await tester.dragUntilVisible(
      yearly,
      find.byType(ListView),
      const Offset(0, -100),
    );
    // dragUntilVisible can stop inside the cache extent, before the widget
    // is hit-testable (docs/LESSONS.md): nudge a little further.
    await tester.drag(find.byType(ListView), const Offset(0, -50));
    await tester.pumpAndSettle();
    await tester.tap(yearly);
    await tester.pumpAndSettle();

    final Finder last = find.text(l10n.eventShortMonthLast);
    await tester.dragUntilVisible(
      last,
      find.byType(ListView),
      const Offset(0, -100),
    );
    // dragUntilVisible can stop inside the cache extent, before the widget
    // is hit-testable (docs/LESSONS.md): nudge a little further.
    await tester.drag(find.byType(ListView), const Offset(0, -50));
    await tester.pumpAndSettle();
    final ChoiceChip next = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, l10n.eventShortMonthNext),
    );
    expect(next.selected, isTrue);
    await tester.tap(last);
    await tester.pumpAndSettle();

    final Event saved = await _saveAndRead(tester, repository);
    expect(saved.recurrence.shortMonth, ShortMonthPolicy.lastDay);
  });

  testWidgets('a Gregorian date after sunset sets the next Hebrew day (M16)', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);
    const HebrewDate start = HebrewDate(
      year: 5786,
      month: HebrewMonth.tishrei,
      day: 5,
    );
    await tester.pumpWidget(
      _wrap(
        const EventEditorScreen(args: EventEditorArgs(initialDate: start)),
        repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'יום הולדת');

    await tester.tap(find.byIcon(Icons.edit_calendar));
    await tester.pumpAndSettle();
    // Keep the picker's initial day (the event's current date).
    await tester.tap(find.text('אישור'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.eventSunsetQuestion), findsOneWidget);
    await tester.tap(find.textContaining('אחרי השקיעה'));
    await tester.pumpAndSettle();

    final Event saved = await _saveAndRead(tester, repository);
    expect(
      saved.hebrewDate,
      const HebrewDate(year: 5786, month: HebrewMonth.tishrei, day: 6),
    );
  });
}
