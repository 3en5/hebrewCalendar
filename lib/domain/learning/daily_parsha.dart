import '../hebrew_date/hebrew_date.dart';
import '../hebrew_date/hebrew_date_engine.dart';
import '../hebrew_date/jewish_day_info.dart';

/// M26 (owner decision 2026-10-19): one day of the weekly portion, an
/// aliyah a day from Sunday (first) to Shabbat (seventh), built by
/// `tool/learning/build_parsha.py` and served as one small file per parsha
/// and aliyah from Firebase Hosting. Usually one part; a combined week
/// without its own division (Nitzavim-Vayeilech) has two.
class DailyParsha {
  const DailyParsha({required this.parts});

  final List<ParshaPortion> parts;

  static DailyParsha? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? parts = json['parts'];
    if (parts is! List<Object?>) {
      return null;
    }
    final List<ParshaPortion> parsed = <ParshaPortion>[
      for (final Object? p in parts) ?ParshaPortion._fromJson(p),
    ];
    if (parsed.isEmpty || parsed.length != parts.length) {
      return null;
    }
    return DailyParsha(parts: parsed);
  }
}

/// A run of verses of one book.
class ParshaPortion {
  const ParshaPortion({required this.book, required this.verses});

  /// The book's Hebrew name, e.g. "בראשית".
  final String book;
  final List<ParshaVerse> verses;

  static ParshaPortion? _fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? book = json['book'];
    final Object? verses = json['verses'];
    if (book is! String || verses is! List<Object?>) {
      return null;
    }
    final List<ParshaVerse> parsed = <ParshaVerse>[
      for (final Object? v in verses) ?ParshaVerse._fromJson(v),
    ];
    if (parsed.isEmpty || parsed.length != verses.length) {
      return null;
    }
    return ParshaPortion(book: book, verses: parsed);
  }
}

class ParshaVerse {
  const ParshaVerse({
    required this.chapter,
    required this.verse,
    required this.mikra,
    required this.targum,
    this.rashi = const <RashiComment>[],
    this.sectionBreak = false,
  });

  final int chapter;
  final int verse;

  /// The verse with vowels and cantillation marks.
  final String mikra;

  /// Targum Onkelos.
  final String targum;
  final List<RashiComment> rashi;

  /// A פתוחה or סתומה follows the verse.
  final bool sectionBreak;

  static ParshaVerse? _fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? c = json['c'];
    final Object? v = json['v'];
    final Object? m = json['m'];
    final Object? t = json['t'];
    if (c is! int || v is! int || m is! String || t is! String) {
      return null;
    }
    final Object? r = json['r'];
    return ParshaVerse(
      chapter: c,
      verse: v,
      mikra: m,
      targum: t,
      rashi: <RashiComment>[
        if (r is List<Object?>)
          for (final Object? item in r)
            if (item is List<Object?> &&
                item.length == 2 &&
                item[0] is String &&
                item[1] is String)
              RashiComment(head: item[0]! as String, body: item[1]! as String),
      ],
      sectionBreak: json['b'] is String,
    );
  }
}

/// One Rashi comment: the quoted words ("דיבור המתחיל") and the comment.
class RashiComment {
  const RashiComment({required this.head, required this.body});

  /// May be empty, for a comment that continues the one before it.
  final String head;
  final String body;
}

/// Which day of the parsha [date] is, and its file key
/// (`site/learning/parsha/<parsha>-<aliyah>.json`), or null when no parsha
/// is found.
({String parshaName, int aliyah, String key})? dailyParshaFor(
  HebrewDateEngine engine,
  HebrewDate date, {
  required bool inIsrael,
}) {
  final ({String key, String name})? parsha = JewishDayInfo(
    engine,
  ).weeklyParsha(date, inIsrael: inIsrael);
  if (parsha == null) {
    return null;
  }
  final int aliyah = engine.weekdayIndex(date) + 1;
  return (
    parshaName: parsha.name,
    aliyah: aliyah,
    key: '${parsha.key}-$aliyah',
  );
}
