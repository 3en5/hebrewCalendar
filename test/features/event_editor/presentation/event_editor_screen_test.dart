// Widget tests for the event editor screen: saving a valid event into an
// overridden repository, and inline validation error display.

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

const HebrewDate _fixedDate = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 5,
);

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

void main() {
  testWidgets('saves a valid new event into the overridden repository', (
    WidgetTester tester,
  ) async {
    int idCounter = 0;
    final InMemoryEventRepository repository = InMemoryEventRepository(
      idGenerator: () => 'test-event-${idCounter++}',
    );
    addTearDown(repository.dispose);

    const EventEditorArgs args = (initialDate: _fixedDate, existing: null);

    await tester.pumpWidget(
      _wrap(const EventEditorScreen(args: args), repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'יום הולדת');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final List<Event> saved = await repository
        .watchEventsForHebrewMonth(_fixedDate.year, _fixedDate.month)
        .first;
    expect(saved, hasLength(1));
    expect(saved.single.title, 'יום הולדת');
    expect(saved.single.hebrewDate, _fixedDate);
  });

  testWidgets('shows an inline error when saving with an empty title', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);

    const EventEditorArgs args = (initialDate: _fixedDate, existing: null);

    await tester.pumpWidget(
      _wrap(const EventEditorScreen(args: args), repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('יש להזין כותרת'), findsOneWidget);
    final List<Event> saved = await repository
        .watchEventsForHebrewMonth(_fixedDate.year, _fixedDate.month)
        .first;
    expect(saved, isEmpty);
  });
}
