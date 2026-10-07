import 'package:flutter_test/flutter_test.dart';
import 'package:hebrewcalendar/calendar/hebrew_date_service.dart';

void main() {
  const service = HebrewDateService();

  group('formatDate', () {
    test('formats in English', () {
      // 1 Tishrei 5787 = 12 Sep 2026 (Rosh Hashana).
      expect(
        service.formatDate(DateTime(2026, 9, 12), hebrew: false),
        contains('5787'),
      );
      expect(
        service.formatDate(DateTime(2026, 9, 12), hebrew: false),
        startsWith('1 Tishrei'),
      );
    });

    test('formats in Hebrew letters', () {
      final s = service.formatDate(DateTime(2026, 9, 12), hebrew: true);
      expect(s, contains('תשרי'));
      expect(s, contains('תשפ'));
    });
  });

  group('calendarFor', () {
    test('Israel vs. diaspora: 22 Tishrei 5787 is Shmini Atzeret everywhere, '
        '23 Tishrei is Simchat Torah only in the diaspora', () {
      final day23 = DateTime(2026, 10, 4);
      final israel = service.calendarFor(day23, inIsrael: true);
      final diaspora = service.calendarFor(day23, inIsrael: false);
      expect(israel.getJewishDayOfMonth(), 23);
      expect(israel.isYomTov(), isFalse);
      expect(diaspora.isYomTov(), isTrue);
    });
  });
}
