// M10: Google event JSON mapping carries the event color both ways.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/sync/google_calendar_api.dart';
import 'package:hebrew_calendar/data/sync/google_event_json.dart';

GoogleEventWrite _write({String? colorId}) => GoogleEventWrite(
  summary: 'פגישה',
  description: '',
  location: '',
  isAllDay: true,
  start: DateTime(2026, 10, 12),
  end: DateTime(2026, 10, 13),
  hebcalEventId: 'e1',
  hebcalOccurrence: 'o1',
  colorId: colorId,
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
}
