// Owner report 2026-10-15 (a phone with a larger font): the Maps and Waze
// buttons stacked, and one participant read "1 משתתפים, 1 אישרו".

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event_attendee.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/day_events_sheet.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/location_actions.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';

EventAttendee _a(String email, AttendeeResponse response) =>
    EventAttendee(email: email, response: response);

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('he'));
  });

  test('the participants summary reads right for one and for many', () {
    const AttendeeResponse yes = AttendeeResponse.accepted;
    const AttendeeResponse none = AttendeeResponse.needsAction;
    expect(
      attendeesSummary(l10n, <EventAttendee>[_a('a@x.com', yes)]),
      'משתתף אחד, אישר/ה',
    );
    expect(
      attendeesSummary(l10n, <EventAttendee>[_a('a@x.com', none)]),
      'משתתף אחד, טרם השיב/ה',
    );
    expect(
      attendeesSummary(l10n, <EventAttendee>[
        _a('a@x.com', none),
        _a('b@x.com', none),
      ]),
      '2 משתתפים, טרם אישרו',
    );
    expect(
      attendeesSummary(l10n, <EventAttendee>[
        _a('a@x.com', yes),
        _a('b@x.com', none),
        _a('c@x.com', none),
      ]),
      '3 משתתפים, אחד אישר/ה',
    );
    expect(
      attendeesSummary(l10n, <EventAttendee>[
        _a('a@x.com', yes),
        _a('b@x.com', yes),
        _a('c@x.com', none),
      ]),
      '3 משתתפים, 2 אישרו',
    );
  });

  for (final double scale in <double>[1.0, 1.4]) {
    testWidgets('the Maps and Waze buttons share one row at ${scale}x text', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('he'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: LocationActions(location: 'דרך טורי זהב 44, מודיעין עילית'),
            ),
          ),
        ),
      );
      final Rect maps = tester.getRect(
        find.byKey(const ValueKey<String>('location-maps')),
      );
      final Rect waze = tester.getRect(
        find.byKey(const ValueKey<String>('location-waze')),
      );
      expect(maps.top, waze.top);
      expect(tester.takeException(), isNull);
    });
  }
}
