// Widget tests for the event editor screen: saving a valid event into an
// overridden repository, and inline validation error display.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/event_occurrence.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
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

    const EventEditorArgs args = EventEditorArgs(initialDate: _fixedDate);

    await tester.pumpWidget(
      _wrap(const EventEditorScreen(args: args), repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'יום הולדת');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final List<EventOccurrence> saved = await repository
        .watchEventsForHebrewMonth(_fixedDate.year, _fixedDate.month)
        .first;
    expect(saved, hasLength(1));
    expect(saved.single.event.title, 'יום הולדת');
    expect(saved.single.event.hebrewDate, _fixedDate);
  });

  testWidgets('invites participants by email, rejecting a bad one (M11)', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);
    const EventEditorArgs args = EventEditorArgs(initialDate: _fixedDate);

    await tester.pumpWidget(
      _wrap(const EventEditorScreen(args: args), repository),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'ישיבה');

    final Finder field = find.byKey(
      const ValueKey<String>('attendee-email-field'),
    );
    await tester.dragUntilVisible(
      field,
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.enterText(field, 'not-an-email');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      find.text('כתובת מייל לא תקינה, או שהיא כבר ברשימה'),
      findsOneWidget,
    );

    await tester.enterText(field, 'guest@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('guest@example.com'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    final List<EventOccurrence> saved = await repository
        .watchEventsForHebrewMonth(_fixedDate.year, _fixedDate.month)
        .first;
    expect(saved.single.event.attendees.single.email, 'guest@example.com');
  });

  testWidgets('saves the picked event color (M10)', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);
    const EventEditorArgs args = EventEditorArgs(initialDate: _fixedDate);

    await tester.pumpWidget(
      _wrap(const EventEditorScreen(args: args), repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'צבעוני');
    await tester.dragUntilVisible(
      find.byKey(const ValueKey<String>('event-color-11')),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('event-color-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final List<EventOccurrence> saved = await repository
        .watchEventsForHebrewMonth(_fixedDate.year, _fixedDate.month)
        .first;
    expect(saved.single.event.colorId, '11');
  });

  testWidgets('shows an inline error when saving with an empty title', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);

    const EventEditorArgs args = EventEditorArgs(initialDate: _fixedDate);

    await tester.pumpWidget(
      _wrap(const EventEditorScreen(args: args), repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('יש להזין כותרת'), findsOneWidget);
    final List<EventOccurrence> saved = await repository
        .watchEventsForHebrewMonth(_fixedDate.year, _fixedDate.month)
        .first;
    expect(saved, isEmpty);
  });

  testWidgets('saves a weekly recurring event with an until date', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);

    const EventEditorArgs args = EventEditorArgs(initialDate: _fixedDate);

    await tester.pumpWidget(
      _wrap(const EventEditorScreen(args: args), repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'שיעור שבועי');
    // The recurrence section sits below the fold of the editor's ListView.
    // `dragUntilVisible` stops as soon as a widget enters the sliver's
    // cache extent, which can be slightly before it's actually within the
    // visible viewport (hit-testable) — nudge a little further afterwards
    // so `tap()` lands on it.
    await tester.dragUntilVisible(
      find.text('כל שבוע'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -50));
    await tester.pumpAndSettle();
    await tester.tap(find.text('כל שבוע'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('עד תאריך'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -50));
    await tester.pumpAndSettle();
    await tester.tap(find.text('עד תאריך'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('אישור'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final List<EventOccurrence> saved = await repository
        .watchEventsForHebrewMonth(_fixedDate.year, _fixedDate.month)
        .first;
    expect(saved, hasLength(1));
    final Event savedEvent = saved.single.event;
    expect(savedEvent.recurrence.type, RecurrenceType.weekly);
    expect(savedEvent.recurrence.until, isNotNull);
  });

  testWidgets(
    'the last form field stays reachable by scrolling on a small screen',
    (WidgetTester tester) async {
      // Regression test for the "form cut off, no scrolling" device report:
      // render at a small real-device-like surface (360x640, e.g. a compact
      // phone) instead of flutter test's roomy default (800x600) and prove
      // the bottom-most field ("עד תאריך", only shown once a recurrence type
      // is picked) can still be scrolled into view and tapped.
      final Size originalSize = tester.view.physicalSize;
      final double originalRatio = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = originalSize;
        tester.view.devicePixelRatio = originalRatio;
      });

      final InMemoryEventRepository repository = InMemoryEventRepository();
      addTearDown(repository.dispose);

      const EventEditorArgs args = EventEditorArgs(initialDate: _fixedDate);

      await tester.pumpWidget(
        _wrap(const EventEditorScreen(args: args), repository),
      );
      await tester.pumpAndSettle();

      // The recurrence type chips sit below the fold on this small surface.
      await tester.dragUntilVisible(
        find.text('כל שבוע'),
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -50));
      await tester.pumpAndSettle();
      await tester.tap(find.text('כל שבוע'));
      await tester.pumpAndSettle();

      // Now the very last field, "עד תאריך", must also be reachable and
      // tappable (not cut off past the bottom of the screen).
      await tester.dragUntilVisible(
        find.text('עד תאריך'),
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -50));
      await tester.pumpAndSettle();

      final Finder untilField = find.text('עד תאריך');
      expect(untilField, findsOneWidget);
      final Offset position = tester.getCenter(untilField);
      expect(position.dy, lessThan(tester.view.physicalSize.height));
      await tester.tap(untilField);
      await tester.pumpAndSettle();
      expect(find.text('אישור'), findsOneWidget);
    },
  );
}
