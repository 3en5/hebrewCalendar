// Owner request 2026-10-16: in the agenda the title read "אג'נדה", like
// the view menu next to it. Now it shows the month of the day at the top of
// the list, as the other views show theirs, and follows the scroll.

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

/// The agenda, where tapping an event opens the editor directly.
class _FixedDayNotifier extends CalendarViewNotifier {
  _FixedDayNotifier(this._day);

  final HebrewDate _day;

  @override
  CalendarViewState build() =>
      CalendarViewState(viewType: CalendarViewType.agenda, focusedDate: _day);
}

const HebrewDate _start = HebrewDate(
  year: 5787,
  month: HebrewMonth.cheshvan,
  day: 1,
);

Future<void> _pump(WidgetTester tester) async {
  final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
  final InMemoryEventRepository repository = InMemoryEventRepository();
  addTearDown(auth.dispose);
  addTearDown(repository.dispose);
  final DateTime now = DateTime(2026, 1, 1);
  await repository.create(
    Event(
      id: '',
      ownerUid: testUser.uid,
      calendarId: 'default',
      title: 'שיעור',
      hebrewDate: _start,
      recurrence: const RecurrenceRule(type: RecurrenceType.weekly),
      createdAt: now,
      updatedAt: now,
    ),
  );
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
        calendarViewProvider.overrideWith(() => _FixedDayNotifier(_start)),
      ],
      child: const HebrewCalendarApp(),
    ),
  );
  await tester.pumpAndSettle();
}

final Finder _title = find.byKey(const ValueKey<String>('calendar-title'));

void main() {
  testWidgets(
    'the agenda title is the month at the top, and follows the scroll',
    (WidgetTester tester) async {
      await _pump(tester);
      expect(
        find.descendant(of: _title, matching: find.text('חשוון תשפ״ז')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _title, matching: find.text("אג'נדה")),
        findsNothing,
      );
      // Scroll until a Kislev day is at the top of the list.
      for (int i = 0; i < 40; i++) {
        if (find
            .descendant(of: _title, matching: find.text('כסלו תשפ״ז'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
        await tester.drag(find.byType(ListView).first, const Offset(0, -120));
        await tester.pumpAndSettle();
      }
      expect(
        find.descendant(of: _title, matching: find.text('כסלו תשפ״ז')),
        findsOneWidget,
      );
    },
  );
}
