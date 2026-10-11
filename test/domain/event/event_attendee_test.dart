// M11: participant helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/event/event_attendee.dart';

void main() {
  test('email validation', () {
    expect(isValidAttendeeEmail('a@example.com'), isTrue);
    expect(isValidAttendeeEmail(' a@example.co.il '), isTrue);
    expect(isValidAttendeeEmail('a@example'), isFalse);
    expect(isValidAttendeeEmail('not an email'), isFalse);
  });

  test('Google replies are merged in by email, case-insensitively', () {
    final List<EventAttendee> merged = mergeAttendeeResponses(
      const <EventAttendee>[
        EventAttendee(email: 'Dana@Example.com'),
        EventAttendee(email: 'yossi@example.com'),
      ],
      const <EventAttendee>[
        EventAttendee(
          email: 'dana@example.com',
          response: AttendeeResponse.accepted,
        ),
        EventAttendee(
          email: 'stranger@example.com',
          response: AttendeeResponse.declined,
        ),
      ],
    );
    expect(merged, const <EventAttendee>[
      EventAttendee(
        email: 'Dana@Example.com',
        response: AttendeeResponse.accepted,
      ),
      EventAttendee(email: 'yossi@example.com'),
    ]);
  });

  test('stored maps round-trip and tolerate junk', () {
    const List<EventAttendee> attendees = <EventAttendee>[
      EventAttendee(
        email: 'a@example.com',
        response: AttendeeResponse.tentative,
      ),
    ];
    expect(attendeesFromMaps(attendeesToMaps(attendees)), attendees);
    expect(attendeesFromMaps(null), isEmpty);
    expect(
      attendeesFromMaps(<Object?>[
        42,
        <String, Object?>{'x': 1},
      ]),
      isEmpty,
    );
  });
}
