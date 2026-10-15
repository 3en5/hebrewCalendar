// Owner request 2026-10-15: an event can be deleted from every view, so
// the editor (which the week, day and agenda views open) has a delete
// button too, not only the month view's event sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/in_memory_event_repository.dart';
import 'package:hebrew_calendar/data/sync/in_memory_sync_settings_store.dart';
import 'package:hebrew_calendar/domain/event/event.dart';
import 'package:hebrew_calendar/domain/event/recurrence_rule.dart';
import 'package:hebrew_calendar/domain/hebrew_date/hebrew_date.dart';
import 'package:hebrew_calendar/features/auth/application/auth_providers.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:hebrew_calendar/features/event_editor/application/event_repository_provider.dart';
import 'package:hebrew_calendar/features/notifications/application/reminder_providers.dart';
import 'package:hebrew_calendar/features/settings/application/google_sync_providers.dart';
import 'package:hebrew_calendar/main.dart';

import '../../test_support/fake_auth_repository.dart';
import '../../test_support/fake_google_calendar_api.dart';
import '../../test_support/fake_notification_scheduler.dart';

/// The agenda, where tapping an event opens the editor directly.
class _FixedDayNotifier extends CalendarViewNotifier {
  _FixedDayNotifier(this._day);

  final HebrewDate _day;

  @override
  CalendarViewState build() =>
      CalendarViewState(viewType: CalendarViewType.agenda, focusedDate: _day);
}

const HebrewDate _day = HebrewDate(
  year: 5787,
  month: HebrewMonth.cheshvan,
  day: 12,
);

Event _event(String title, {RecurrenceType type = RecurrenceType.none}) {
  final DateTime now = DateTime(2026, 1, 1);
  return Event(
    id: '',
    ownerUid: testUser.uid,
    calendarId: 'default',
    title: title,
    hebrewDate: _day,
    recurrence: RecurrenceRule(type: type),
    createdAt: now,
    updatedAt: now,
  );
}

Future<InMemoryEventRepository> _pump(WidgetTester tester, Event event) async {
  final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
  final InMemoryEventRepository repository = InMemoryEventRepository();
  addTearDown(auth.dispose);
  addTearDown(repository.dispose);
  await repository.create(event);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(auth),
        eventRepositoryProvider.overrideWithValue(repository),
        notificationSchedulerProvider.overrideWithValue(
          FakeNotificationScheduler(),
        ),
        googleCalendarApiProvider.overrideWithValue(FakeGoogleCalendarApi()),
        syncSettingsStoreProvider.overrideWithValue(
          InMemorySyncSettingsStore(),
        ),
        calendarViewProvider.overrideWith(() => _FixedDayNotifier(_day)),
      ],
      child: const HebrewCalendarApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

final Finder _deleteButton = find.byKey(
  const ValueKey<String>('editor-delete'),
);

void main() {
  testWidgets('a single event is deleted from the editor', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = await _pump(
      tester,
      _event('תור לרופא'),
    );
    await tester.tap(find.text('תור לרופא').first);
    await tester.pumpAndSettle();
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('מחיקת אירוע'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('מחיקה'),
      ),
    );
    await tester.pumpAndSettle();
    expect(await repository.getAllForSearch(), isEmpty);
    // Back on the agenda, without the event.
    expect(_deleteButton, findsNothing);
    expect(find.text('תור לרופא'), findsNothing);
  });

  testWidgets('cancelling keeps the event and stays in the editor', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = await _pump(
      tester,
      _event('תור לרופא'),
    );
    await tester.tap(find.text('תור לרופא').first);
    await tester.pumpAndSettle();
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ביטול'));
    await tester.pumpAndSettle();
    expect(await repository.getAllForSearch(), hasLength(1));
    expect(_deleteButton, findsOneWidget);
  });

  testWidgets('one occurrence of a series is deleted from the editor', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = await _pump(
      tester,
      _event('שיעור', type: RecurrenceType.weekly),
    );
    await tester.tap(find.text('שיעור').first);
    await tester.pumpAndSettle();
    // The edit scope first, then the delete scope.
    await tester.tap(find.text('כל הסדרה'));
    await tester.pumpAndSettle();
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('מופע זה בלבד'));
    await tester.pumpAndSettle();
    final List<Event> left = await repository.getAllForSearch();
    expect(left, hasLength(1));
    expect(left.single.recurrence.exceptions, <HebrewDate>[_day]);
    expect(_deleteButton, findsNothing);
  });

  testWidgets('a new event has no delete button', (WidgetTester tester) async {
    await _pump(tester, _event('תור לרופא'));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('add-menu-new-event')));
    await tester.pumpAndSettle();
    expect(_deleteButton, findsNothing);
  });
}
