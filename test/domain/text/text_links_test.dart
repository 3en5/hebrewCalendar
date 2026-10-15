import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/domain/text/text_links.dart';

List<String> _texts(String s) =>
    findTextLinks(s).map((TextLink l) => '${l.kind.name}:${l.text}').toList();

void main() {
  test('finds an Israeli mobile number with dashes', () {
    expect(_texts('להתקשר לפאבל – 052-834-4147 • אחריות'), <String>[
      'phone:052-834-4147',
    ]);
  });

  test('finds numbers without separators, with spaces and international', () {
    expect(_texts('0528344147'), <String>['phone:0528344147']);
    expect(_texts('טל 03 123 4567.'), <String>['phone:03 123 4567']);
    expect(_texts('+972 52-834-4147'), <String>['phone:+972 52-834-4147']);
  });

  test('times, dates, prices and short numbers are not phones', () {
    expect(_texts('בשעה 10:00 ב-15.10.2026, מחיר 1,250 ש"ח, חדר 12'), isEmpty);
  });

  test('finds emails and links, without the sentence punctuation', () {
    expect(
      _texts('מייל: dana@example.co.il, אתר https://zoom.us/j/123.'),
      <String>['email:dana@example.co.il', 'url:https://zoom.us/j/123'],
    );
    expect(_texts('www.gov.il'), <String>['url:www.gov.il']);
    expect(_texts('ל-dana@example.co.il'), <String>[
      'email:dana@example.co.il',
    ]);
  });

  test('digits inside a link are not a phone', () {
    expect(_texts('https://zoom.us/j/98765432101'), <String>[
      'url:https://zoom.us/j/98765432101',
    ]);
  });

  test('WhatsApp numbers get the Israeli country code', () {
    expect(whatsAppNumber('052-834-4147'), '972528344147');
    expect(whatsAppNumber('+972 52-834-4147'), '972528344147');
    expect(whatsAppNumber('00972528344147'), '972528344147');
    expect(dialableNumber('052-834-4147'), '0528344147');
  });
}
