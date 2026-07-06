// Widget test for DayViewScreen (M3b): only the focused day's events show,
// not events on other days.

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

const HebrewDate _focusedDay = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 10,
);
const HebrewDate _otherDay = HebrewDate(
  year: 5786,
  month: HebrewMonth.tishrei,
  day: 11,
);

class _FixedDayNotifier extends CalendarViewNotifier {
  @override
  CalendarViewState build() => const CalendarViewState(
    viewType: CalendarViewType.day,
    focusedDate: _focusedDay,
  );
}

Event _allDayEvent(String title, HebrewDate date) {
  final DateTime now = DateTime(2026, 1, 1);
  return Event(
    id: 'ignored-on-create',
    ownerUid: 'uid-1',
    calendarId: 'default',
    title: title,
    hebrewDate: date,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('shows only the focused day\'s events', (
    WidgetTester tester,
  ) async {
    final InMemoryEventRepository repository = InMemoryEventRepository();
    final FakeAuthRepository auth = FakeAuthRepository(initialUser: testUser);
    addTearDown(repository.dispose);
    addTearDown(auth.dispose);
    await repository.create(_allDayEvent('אירוע היום', _focusedDay));
    await repository.create(_allDayEvent('אירוע יום אחר', _otherDay));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(auth),
          eventRepositoryProvider.overrideWithValue(repository),
          calendarViewProvider.overrideWith(_FixedDayNotifier.new),
        ],
        child: const HebrewCalendarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('אירוע היום'), findsOneWidget);
    expect(find.text('אירוע יום אחר'), findsNothing);
  });
}
