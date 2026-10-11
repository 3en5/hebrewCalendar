// M10: Google event JSON mapping carries the event color both ways.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/sync/google_calendar_api.dart';
import 'package:hebrew_calendar/data/sync/google_event_json.dart';
import 'package:hebrew_calendar/domain/event/event_attendee.dart';

GoogleEventWrite _write({
  String? colorId,
  List<String> guests = const <String>[],
}) => GoogleEventWrite(
  summary: 'פגישה',
  description: '',
  location: '',
  isAllDay: true,
  start: DateTime(2026, 10, 12),
  end: DateTime(2026, 10, 13),
  hebcalEventId: 'e1',
  hebcalOccurrence: 'o1',
  colorId: colorId,
  attendeeEmails: guests,
);

void main() {
  test('a picked color is sent as colorId', () {
    expect(googleEventToJson(_write(colorId: '5'))['colorId'], '5');
  });

  test('the default color sends no colorId (Google keeps its own)', () {
    expect(googleEventToJson(_write()).containsKey('colorId'), isFalse);
  });

  test('an imported event keeps its Google color', () {
    final snapshot = googleEventFromJson(<String, dynamic>{
      'id': 'g1',
      'etag': '"1"',
      'updated': '2026-10-01T10:00:00Z',
      'summary': 'ישיבה',
      'colorId': '9',
      'start': <String, String>{'date': '2026-10-12'},
      'end': <String, String>{'date': '2026-10-13'},
    });
    expect(snapshot.colorId, '9');
  });

  test('M11: guests are sent as attendees; none sends no attendees', () {
    final Map<String, dynamic> json = googleEventToJson(
      _write(guests: <String>['a@example.com']),
    );
    expect(json['attendees'], <Map<String, String>>[
      <String, String>{'email': 'a@example.com'},
    ]);
    expect(googleEventToJson(_write()).containsKey('attendees'), isFalse);
  });

  test('M11: imported guests keep their reply; the owner is left out', () {
    final snapshot = googleEventFromJson(<String, dynamic>{
      'id': 'g2',
      'etag': '"1"',
      'updated': '2026-10-01T10:00:00Z',
      'start': <String, String>{'date': '2026-10-12'},
      'end': <String, String>{'date': '2026-10-13'},
      'attendees': <Map<String, dynamic>>[
        <String, dynamic>{'email': 'me@example.com', 'self': true},
        <String, dynamic>{
          'email': 'b@example.com',
          'responseStatus': 'accepted',
        },
      ],
    });
    expect(snapshot.attendees, hasLength(1));
    expect(snapshot.attendees.single.email, 'b@example.com');
    expect(snapshot.attendees.single.response, AttendeeResponse.accepted);
  });
}
