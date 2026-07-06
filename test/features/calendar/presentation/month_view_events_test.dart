// Widget tests for calendar/event integration: the month grid's event
// indicator dot, and the day-events sheet's delete flow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/main.dart';

import '../../../test_support/fake_auth_repository.dart';

const HebrewDate _fixedMonth = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 1,
);
const HebrewDate _eventDate = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 5,
);
const ValueKey<String> _eventDotKey = ValueKey<String>('event-dot-5');

class _FixedMonthNotifier extends CalendarViewNotifier {
  @override
  CalendarViewState build() => const CalendarViewState(
    viewType: CalendarViewType.month,
    focusedDate: _fixedMonth,
  );
}

Event _buildEvent() {
  final DateTime now = DateTime(2026, 1, 1);
  return Event(
    id: 'ignored-on-create',
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: 'יום הולדת',
    hebrewDate: _eventDate,
    createdAt: now,
    updatedAt: now,
  );
}

Future<InMemoryEventRepository> _pumpFixedMonth(WidgetTester tester) async {
  final InMemoryEventRepository repository = InMemoryEventRepository();
  final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
  addTearDown(repository.dispose);
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        calendarViewProvider.overrideWith(_FixedMonthNotifier.new),
        eventRepositoryProvider.overrideWithValue(repository),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      child: const HebrewCalendarApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('shows no indicator on a day with no events', (
    WidgetTester tester,
  ) async {
    await _pumpFixedMonth(tester);
    expect(find.byKey(_eventDotKey), findsNothing);
  });

  testWidgets('shows an indicator on a day after adding an event', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = await _pumpFixedMonth(tester);

    await repository.create(_buildEvent());
    await tester.pumpAndSettle();

    expect(find.byKey(_eventDotKey), findsOneWidget);
  });

  testWidgets('delete flow removes the event and its indicator', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = await _pumpFixedMonth(tester);
    final Event created = await repository.create(_buildEvent());
    await tester.pumpAndSettle();
    expect(find.byKey(_eventDotKey), findsOneWidget);

    await tester.tap(find.byKey(_eventDotKey));
    await tester.pumpAndSettle();
    expect(find.text('יום הולדת'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    expect(find.text('מחיקה'), findsOneWidget);

    await tester.tap(find.text('מחיקה'));
    await tester.pumpAndSettle();

    expect(await repository.getById(created.id), isNull);
    expect(find.byKey(_eventDotKey), findsNothing);
    expect(find.text('יום הולדת'), findsNothing);
  });
}
