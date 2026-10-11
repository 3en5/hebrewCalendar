import 'package:kosher_dart/kosher_dart.dart' as kosher;

import 'hebrew_date.dart';
import 'hebrew_date_engine.dart';
import 'hebrew_numerals.dart';

/// What kind of special day a [JewishDayLabel] describes (M8). The UI may
/// style kinds differently; [parsha] is always shown last.
enum JewishDayKind {
  /// Yom Tov and the major festive days (Rosh Hashana, Pesach, Chanukah...).
  holiday,

  /// Erev chag, chol hamoed and minor days (Tu BiShvat, Lag BaOmer...).
  minor,

  /// Public fasts (Tzom Gedalya, 10 Tevet, Ta'anit Esther, 17 Tammuz, 9 Av).
  fast,

  /// Rosh Chodesh.
  roshChodesh,

  /// Israeli national days and memorial days.
  national,

  /// The weekly Torah portion (Shabbat only).
  parsha,
}

/// One thing that makes a day special, e.g. "חנוכה – נר ג׳" or "פרשת נח".
class JewishDayLabel {
  const JewishDayLabel({
    required this.kind,
    required this.name,
    String? shortName,
  }) : shortName = shortName ?? name;

  final JewishDayKind kind;

  /// Full display name in Hebrew. For [JewishDayKind.parsha] this is the
  /// bare portion name ("נח"), without the "פרשת" prefix.
  final String name;

  /// A shorter form for the narrow month-grid cell ("חנוכה ג׳" for
  /// "חנוכה – נר ג׳"); equal to [name] when that is already short.
  final String shortName;

  @override
  bool operator ==(Object other) =>
      other is JewishDayLabel &&
      other.kind == kind &&
      other.name == name &&
      other.shortName == shortName;

  @override
  int get hashCode => Object.hash(kind, name, shortName);

  @override
  String toString() => 'JewishDayLabel($kind, $name)';
}

/// Computes holidays, fasts, Rosh Chodesh, Israeli national days and the
/// weekly parsha for a [HebrewDate] (M8, ARCHITECTURE.md §10).
///
/// Together with `hebrew_date_engine.dart` this is the only file allowed to
/// import `kosher_dart`; it exposes only our own types. Pure and
/// synchronous — nothing here touches the network or user data.
class JewishDayInfo {
  const JewishDayInfo(this._engine);

  final HebrewDateEngine _engine;

  static final kosher.HebrewDateFormatter _formatter =
      kosher.HebrewDateFormatter()..hebrewFormat = true;

  /// All labels for [date], most important first, parsha last. [inIsrael]
  /// selects the Israel or diaspora calendar (second Yom Tov days, parsha
  /// schedule).
  List<JewishDayLabel> labelsFor(HebrewDate date, {required bool inIsrael}) {
    final kosher.JewishCalendar calendar = kosher.JewishCalendar.fromDateTime(
      _engine.toGregorian(date),
    );
    calendar.inIsrael = inIsrael;
    calendar.setUseModernHolidays(true);

    final List<JewishDayLabel> labels = <JewishDayLabel>[];
    final JewishDayLabel? yomTov = _yomTovLabel(calendar, inIsrael: inIsrael);
    if (yomTov != null) {
      labels.add(yomTov);
    }
    if (calendar.isRoshChodesh()) {
      labels.add(
        JewishDayLabel(
          kind: JewishDayKind.roshChodesh,
          name: 'ראש חודש ${_roshChodeshMonthName(date)}',
          shortName: 'ראש חודש',
        ),
      );
    }
    final String parsha =
        _formatter.hebrewParshaMap[calendar.getParshah()] ?? '';
    if (parsha.isNotEmpty) {
      labels.add(JewishDayLabel(kind: JewishDayKind.parsha, name: parsha));
    }
    return labels;
  }

  /// Rosh Chodesh on day 30 belongs to the *next* month (ל׳ חשוון is the
  /// first day of Rosh Chodesh Kislev).
  String _roshChodeshMonthName(HebrewDate date) {
    final HebrewMonth month = date.day == 30
        ? _engine.nextMonth(date).month
        : date.month;
    return _engine.monthName(month);
  }

  JewishDayLabel? _yomTovLabel(
    kosher.JewishCalendar calendar, {
    required bool inIsrael,
  }) {
    final int index = calendar.getYomTovIndex();
    final int day = calendar.getJewishDayOfMonth();
    switch (index) {
      case kosher.JewishCalendar.EREV_PESACH:
        return _minor('ערב פסח');
      case kosher.JewishCalendar.PESACH:
        return day >= 21
            ? _holiday('שביעי של פסח', 'שביעי פסח')
            : _holiday('פסח');
      case kosher.JewishCalendar.CHOL_HAMOED_PESACH:
        return _minor('חול המועד פסח', 'חול המועד');
      case kosher.JewishCalendar.PESACH_SHENI:
        return _minor('פסח שני');
      case kosher.JewishCalendar.EREV_SHAVUOS:
        return _minor('ערב שבועות');
      case kosher.JewishCalendar.SHAVUOS:
        return _holiday('שבועות');
      case kosher.JewishCalendar.SEVENTEEN_OF_TAMMUZ:
        return _fast('צום י״ז בתמוז', 'י״ז בתמוז');
      case kosher.JewishCalendar.TISHA_BEAV:
        return _fast('תשעה באב');
      case kosher.JewishCalendar.TU_BEAV:
        return _minor('ט״ו באב');
      case kosher.JewishCalendar.EREV_ROSH_HASHANA:
        return _minor('ערב ראש השנה', 'ערב ר״ה');
      case kosher.JewishCalendar.ROSH_HASHANA:
        return _holiday('ראש השנה');
      case kosher.JewishCalendar.FAST_OF_GEDALYAH:
        return _fast('צום גדליה');
      case kosher.JewishCalendar.EREV_YOM_KIPPUR:
        return _minor('ערב יום כיפור', 'ערב יוה״כ');
      case kosher.JewishCalendar.YOM_KIPPUR:
        return _holiday('יום כיפור');
      case kosher.JewishCalendar.EREV_SUCCOS:
        return _minor('ערב סוכות');
      case kosher.JewishCalendar.SUCCOS:
        return _holiday('סוכות');
      case kosher.JewishCalendar.CHOL_HAMOED_SUCCOS:
        return _minor('חול המועד סוכות', 'חול המועד');
      case kosher.JewishCalendar.HOSHANA_RABBA:
        return _minor('הושענא רבה');
      case kosher.JewishCalendar.SHEMINI_ATZERES:
        // In Israel Shemini Atzeret and Simchat Torah are the same day.
        return inIsrael
            ? _holiday('שמיני עצרת ושמחת תורה', 'שמחת תורה')
            : _holiday('שמיני עצרת');
      case kosher.JewishCalendar.SIMCHAS_TORAH:
        return _holiday('שמחת תורה');
      case kosher.JewishCalendar.CHANUKAH:
        final String candle = hebrewDayNumeral(calendar.getDayOfChanukah());
        return _holiday('חנוכה – נר $candle', 'חנוכה $candle');
      case kosher.JewishCalendar.TENTH_OF_TEVES:
        return _fast('צום עשרה בטבת', 'עשרה בטבת');
      case kosher.JewishCalendar.TU_BESHVAT:
        return _minor('ט״ו בשבט');
      case kosher.JewishCalendar.FAST_OF_ESTHER:
        return _fast('תענית אסתר');
      case kosher.JewishCalendar.PURIM:
        return _holiday('פורים');
      case kosher.JewishCalendar.SHUSHAN_PURIM:
        return _holiday('שושן פורים');
      case kosher.JewishCalendar.PURIM_KATAN:
        return _minor('פורים קטן');
      case kosher.JewishCalendar.SHUSHAN_PURIM_KATAN:
        return _minor('שושן פורים קטן');
      case kosher.JewishCalendar.YOM_HASHOAH:
        return _national('יום השואה');
      case kosher.JewishCalendar.YOM_HAZIKARON:
        return _national('יום הזיכרון');
      case kosher.JewishCalendar.YOM_HAATZMAUT:
        return _national('יום העצמאות');
      case kosher.JewishCalendar.YOM_YERUSHALAYIM:
        return _national('יום ירושלים');
      case kosher.JewishCalendar.LAG_BAOMER:
        return _minor('ל״ג בעומר');
      default:
        // -1 (no holiday), Erev Rosh Chodesh, and Rosh Chodesh itself
        // (labelled separately via isRoshChodesh, which also covers a Rosh
        // Chodesh that coincides with Chanukah).
        return null;
    }
  }

  static JewishDayLabel _holiday(String name, [String? shortName]) =>
      JewishDayLabel(
        kind: JewishDayKind.holiday,
        name: name,
        shortName: shortName,
      );
  static JewishDayLabel _minor(String name, [String? shortName]) =>
      JewishDayLabel(
        kind: JewishDayKind.minor,
        name: name,
        shortName: shortName,
      );
  static JewishDayLabel _fast(String name, [String? shortName]) =>
      JewishDayLabel(
        kind: JewishDayKind.fast,
        name: name,
        shortName: shortName,
      );
  static JewishDayLabel _national(String name) =>
      JewishDayLabel(kind: JewishDayKind.national, name: name);
}
