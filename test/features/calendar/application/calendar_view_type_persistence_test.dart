// Tester request 2026-10-14: the app reopens in the last view type.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/features/calendar/application/calendar_view_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a stored view type is restored on start', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'calendar_view_type_v1': 'week',
    });
    await preloadCalendarViewType();
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(calendarViewProvider).viewType,
      CalendarViewType.week,
    );
  });

  test('choosing a view stores it', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await preloadCalendarViewType();
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(calendarViewProvider, (_, _) {});
    expect(
      container.read(calendarViewProvider).viewType,
      CalendarViewType.month,
    );
    container
        .read(calendarViewProvider.notifier)
        .setViewType(CalendarViewType.day);
    await Future<void>.delayed(Duration.zero);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('calendar_view_type_v1'), 'day');
  });
}
