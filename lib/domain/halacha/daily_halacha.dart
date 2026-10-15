import '../hebrew_date/hebrew_date.dart';

/// M25 (owner decision 2026-10-15): one day of Kitzur Shulchan Aruch Yomi,
/// the yearly cycle that finishes the whole Kitzur every Hebrew year
/// (starts 24 Tishrei). Built by `tool/halacha/build_ksa.py` and served as
/// one small file per day from Firebase Hosting.
class DailyHalacha {
  const DailyHalacha({required this.title, required this.sections});

  /// e.g. "סימן ח׳, סעיפים א׳–ה׳".
  final String title;
  final List<HalachaSection> sections;

  static DailyHalacha? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? title = json['title'];
    final Object? sections = json['sections'];
    if (title is! String || sections is! List<Object?>) {
      return null;
    }
    final List<HalachaSection> parsed = <HalachaSection>[];
    for (final Object? s in sections) {
      if (s is Map<String, Object?> &&
          s['siman'] is int &&
          s['seif'] is int &&
          s['text'] is String) {
        parsed.add(
          HalachaSection(
            siman: s['siman']! as int,
            seif: s['seif']! as int,
            text: s['text']! as String,
          ),
        );
      }
    }
    if (parsed.isEmpty) {
      return null;
    }
    return DailyHalacha(title: title, sections: parsed);
  }
}

class HalachaSection {
  const HalachaSection({
    required this.siman,
    required this.seif,
    required this.text,
  });

  final int siman;
  final int seif;
  final String text;
}

/// The file key of [date]'s reading (`site/halacha/ksa/<key>.json`), or
/// null on a day without one (30 Cheshvan, 30 Adar I, and 15 Elul, which
/// the cycle keeps for the Shulchan Aruch's principles). The schedule is
/// the same every year, so the key is only month and day; a plain Adar and
/// Adar I share "adar", and Adar II has its own track.
String? dailyHalachaKey(HebrewDate date) {
  if (date.day == 30 &&
      (date.month == HebrewMonth.cheshvan || date.month == HebrewMonth.adarI)) {
    return null;
  }
  if (date.month == HebrewMonth.elul && date.day == 15) {
    return null;
  }
  final String month = switch (date.month) {
    HebrewMonth.adarI => 'adar',
    final HebrewMonth m => m.name,
  };
  return '$month-${date.day}';
}

/// The document id of a civil day's dedication, "yyyy-MM-dd".
String dedicationDayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
