// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'לוח עברי';

  @override
  String get navToday => 'היום';

  @override
  String get navCalendar => 'לוח';

  @override
  String get navEvents => 'אירועים';

  @override
  String get navSettings => 'הגדרות';

  @override
  String get todayHebrewDate => 'תאריך עברי';

  @override
  String get todayGregorianDate => 'תאריך לועזי';

  @override
  String get comingSoon => 'בקרוב';

  @override
  String get settingsLanguage => 'שפה';

  @override
  String get settingsLanguageSystem => 'לפי המכשיר';

  @override
  String get settingsLanguageHebrew => 'עברית';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsTheme => 'ערכת נושא';

  @override
  String get settingsThemeSystem => 'לפי המכשיר';

  @override
  String get settingsThemeLight => 'בהירה';

  @override
  String get settingsThemeDark => 'כהה';

  @override
  String get settingsLocation => 'מיקום לחישוב הלוח';

  @override
  String get settingsLocationIsrael => 'ארץ ישראל';

  @override
  String get settingsLocationDiaspora => 'חוץ לארץ';

  @override
  String get settingsLocationHint => 'משפיע על יום טוב שני ועל פרשת השבוע';

  @override
  String get settingsZmanimOpinion => 'שיטת זמנים';

  @override
  String get settingsZmanimGra => 'גר\"א';

  @override
  String get settingsZmanimMga => 'מגן אברהם';

  @override
  String get settingsCandleLighting => 'הדלקת נרות';

  @override
  String settingsCandleLightingMinutes(int minutes) {
    return '$minutes דקות לפני השקיעה';
  }
}
