// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hebrew Calendar';

  @override
  String get navToday => 'Today';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navEvents => 'Events';

  @override
  String get navSettings => 'Settings';

  @override
  String get todayHebrewDate => 'Hebrew date';

  @override
  String get todayGregorianDate => 'Gregorian date';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Device default';

  @override
  String get settingsLanguageHebrew => 'עברית';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'Device default';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLocation => 'Calendar location';

  @override
  String get settingsLocationIsrael => 'Land of Israel';

  @override
  String get settingsLocationDiaspora => 'Diaspora';

  @override
  String get settingsLocationHint =>
      'Affects Yom Tov Sheni and the weekly Torah portion';

  @override
  String get settingsZmanimOpinion => 'Zmanim opinion';

  @override
  String get settingsZmanimGra => 'GRA';

  @override
  String get settingsZmanimMga => 'Magen Avraham';

  @override
  String get settingsCandleLighting => 'Candle lighting';

  @override
  String settingsCandleLightingMinutes(int minutes) {
    return '$minutes minutes before sunset';
  }
}
