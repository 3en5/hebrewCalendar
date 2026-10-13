// M20: an event's location opens in Google Maps or Waze.

import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/features/calendar/presentation/widgets/location_actions.dart';

void main() {
  test('the Maps and Waze links carry the location as typed', () {
    const String place = 'אבי דוד 11, גני מודיעין';

    final Uri maps = googleMapsUri(place);
    expect(maps.host, 'www.google.com');
    expect(maps.path, '/maps/search/');
    expect(maps.queryParameters['api'], '1');
    expect(maps.queryParameters['query'], place);

    final Uri waze = wazeUri(place);
    expect(waze.host, 'waze.com');
    expect(waze.queryParameters['q'], place);
    expect(waze.queryParameters['navigate'], 'yes');
  });
}
