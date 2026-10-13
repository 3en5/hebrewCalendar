// Widget tests for AgendaViewScreen (M3b): occurrences are grouped by
// Hebrew date (recurring events show one row per upcoming occurrence,
// across multiple date groups), and an empty window shows the Hebrew
// empty-state message.

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

const HebrewDate _anchor = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 10,
);

class _FixedAgendaNotifier extends CalendarViewNotifier {
  @override
  CalendarViewState build() => const CalendarViewState(
    viewType: CalendarViewType.agenda,
    focusedDate: _anchor,
  );
}

Event _monthlyRecurringEvent() {
  final DateTime now = DateTime(2026, 1, 1);
  return Event(
    id: 'ignored-on-create',
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: 'שיעור חודשי',
    hebrewDate: _anchor,
    recurrence: const RecurrenceRule(type: RecurrenceType.hebrewMonthly),
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpAgenda(
  WidgetTester tester,
  InMemoryEventRepository repository,
) async {
  final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
  addTearDown(auth.dispose);
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
        calendarViewProvider.overrideWith(_FixedAgendaNotifier.new),
      ],
      child: const HebrewCalendarApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'groups a recurring event\'s upcoming occurrences by date, across '
    'multiple months',
    (WidgetTester tester) async {
      final InMemoryEventRepository repository = InMemoryEventRepository();
      addTearDown(repository.dispose);
      await repository.create(_monthlyRecurringEvent());

      await _pumpAgenda(tester, repository);

      // The default 3-month rolling window from the anchor date covers (at
      // least) Tishrei, Cheshvan and Kislev — one occurrence each.
      expect(find.text('שיעור חודשי'), findsAtLeastNWidgets(2));
      expect(find.textContaining('תשרי'), findsWidgets);
      expect(find.textContaining('חשוון'), findsWidgets);
      // Device request 2026-10-13: the Gregorian date, dd/MM/yy.
      expect(find.textContaining(RegExp(r'\(\d\d/\d\d/\d\d\)')), findsWidgets);
    },
  );

  testWidgets('shows the Hebrew empty-state message when there are no '
      'occurrences in the loaded window', (WidgetTester tester) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    addTearDown(repository.dispose);

    await _pumpAgenda(tester, repository);

    expect(find.text('אין אירועים קרובים'), findsOneWidget);
  });
}
