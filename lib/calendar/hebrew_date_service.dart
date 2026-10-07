import 'package:kosher_dart/kosher_dart.dart';

/// Thin wrapper over kosher_dart so the rest of the app does not depend on
/// its API directly.
class HebrewDateService {
  const HebrewDateService();

  JewishCalendar calendarFor(DateTime date, {required bool inIsrael}) {
    return JewishCalendar.fromDateTime(date)..inIsrael = inIsrael;
  }

  /// e.g. `ט״ו שבט תשפ״ז` in Hebrew, `15 Shevat 5787` otherwise.
  String formatDate(DateTime date, {required bool hebrew}) {
    final formatter = HebrewDateFormatter()..hebrewFormat = hebrew;
    return formatter.format(JewishDate.fromDateTime(date));
  }
}
