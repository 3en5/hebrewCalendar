// Owner request 2026-10-15: an online meeting's location opens its link
// (no maps buttons), and participants' emails are tappable.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/core/widgets/linkified_text.dart';
import 'package:hebrew_calendar/domain/event/event_attendee.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/event_attendees_list.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/location_actions.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('he'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  ),
);

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('he'));
  });

  testWidgets('a street address keeps the maps and Waze buttons', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const LocationActions(location: 'יפו 97, ירושלים'));
    expect(find.text(l10n.locationOpenInMaps), findsOneWidget);
    expect(find.text(l10n.locationNavigateWaze), findsOneWidget);
  });

  testWidgets('a meeting link shows the link, without maps buttons', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const LocationActions(location: 'Zoom: https://zoom.us/j/123456'),
    );
    expect(find.text(l10n.locationOpenInMaps), findsNothing);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.byType(LinkifiedText), findsOneWidget);
  });

  testWidgets('participants show their email and reply', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const EventAttendeesList(
        attendees: <EventAttendee>[
          EventAttendee(
            email: 'dana@example.co.il',
            response: AttendeeResponse.accepted,
          ),
          EventAttendee(email: 'yossi@example.com'),
        ],
      ),
    );
    expect(find.byType(LinkifiedText), findsNWidgets(2));
    expect(find.text(l10n.attendeeAccepted), findsOneWidget);
    expect(find.text(l10n.attendeeNoReply), findsOneWidget);
  });
}
