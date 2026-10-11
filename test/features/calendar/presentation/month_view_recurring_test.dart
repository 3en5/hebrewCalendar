// Widget tests for M3a recurring-event display/deletion in the month view:
// a recurring event's occurrences show up in a later month, and deleting
// "this occurrence only" from the day sheet removes just that one
// occurrence while leaving the rest of the series intact.

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

import '../../../test_support/fake_auth_repository.dart';
import '../../../test_support/fake_google_calendar_api.dart';
import '../../../test_support/fake_notification_scheduler.dart';

const HebrewDate _tishrei = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 1,
);
const HebrewDate _cheshvan = HebrewDate(
  year: 5786,
  month: HebrewMonth.cheshvan,
  day: 1,
);
const HebrewDate _baseDate = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 10,
);
const ValueKey<String> _dotKey = ValueKey<String>('event-dot-10');

class _MonthNotifier extends CalendarViewNotifier {
  _MonthNotifier(this._month);
  final HebrewDate _month;
  @override
  CalendarViewState build() =>
      CalendarViewState(viewType: CalendarViewType.month, focusedDate: _month);
}

Event _monthlyRecurringEvent() {
  final DateTime now = DateTime(2026, 1, 1);
  return Event(
    id: 'ignored-on-create',
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: 'שיעור חודשי',
    hebrewDate: _baseDate,
    recurrence: const RecurrenceRule(type: RecurrenceType.hebrewMonthly),
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpMonth(
  WidgetTester tester,
  InMemoryEventRepository repository,
  HebrewDate month,
) async {
  final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        calendarViewProvider.overrideWith(() => _MonthNotifier(month)),
        eventRepositoryProvider.overrideWithValue(repository),
        authRepositoryProvider.overrideWithValue(auth),
        notificationSchedulerProvider.overrideWithValue(
          FakeNotificationScheduler(),
        ),
        googleCalendarApiProvider.overrideWithValue(FakeGoogleCalendarApi()),
        syncSettingsStoreProvider.overrideWithValue(
          InMemorySyncSettingsStore(),
        ),
      ],
      child: const HebrewCalendarApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a monthly recurring event appears as an occurrence in a '
      'later month', (WidgetTester tester) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);
    await repository.create(_monthlyRecurringEvent());

    await _pumpMonth(tester, repository, _cheshvan);

    expect(find.byKey(_dotKey), findsOneWidget);
  });

  testWidgets(
    'deleting "this occurrence only" removes just that month\'s occurrence '
    'and keeps the rest of the series',
    (WidgetTester tester) async {
      final InMemoryEventRepository repository = InMemoryEventRepository();
      addTearDown(repository.dispose);
      await repository.create(_monthlyRecurringEvent());

      await _pumpMonth(tester, repository, _tishrei);
      expect(find.byKey(_dotKey), findsOneWidget);

      await tester.tap(find.byKey(_dotKey));
      await tester.pumpAndSettle();
      expect(find.text('שיעור חודשי'), findsOneWidget);

      // Tapping a day selects it; its events are listed one per row under
      // the grid, and tapping a row opens the edit/delete sheet.
      await tester.tap(find.text('שיעור חודשי'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      // The recurring-delete dialog offers three choices; cancel is not one
      // we want here.
      expect(find.text('מופע זה בלבד'), findsOneWidget);
      expect(find.text('כל הסדרה'), findsOneWidget);

      await tester.tap(find.text('מופע זה בלבד'));
      await tester.pumpAndSettle();

      expect(find.byKey(_dotKey), findsNothing);

      await _pumpMonth(tester, repository, _cheshvan);
      expect(
        find.byKey(_dotKey),
        findsOneWidget,
        reason: 'the Cheshvan occurrence must survive a Tishrei-only delete',
      );
    },
  );
}
