import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('he')];

  /// The application title, shown in the app bar and OS task switcher.
  ///
  /// In he, this message translates to:
  /// **'לוח עברי'**
  String get appTitle;

  /// Generic cancel button label, used in confirmation dialogs.
  ///
  /// In he, this message translates to:
  /// **'ביטול'**
  String get commonCancel;

  /// Tooltip for the floating action button that opens the event editor to create a new event.
  ///
  /// In he, this message translates to:
  /// **'הוספת אירוע'**
  String get addEventTooltip;

  /// App bar title for the event editor screen in create mode.
  ///
  /// In he, this message translates to:
  /// **'אירוע חדש'**
  String get eventEditorTitleNew;

  /// App bar title for the event editor screen in edit mode.
  ///
  /// In he, this message translates to:
  /// **'עריכת אירוע'**
  String get eventEditorTitleEdit;

  /// Tooltip/label for the save action in the event editor.
  ///
  /// In he, this message translates to:
  /// **'שמירה'**
  String get eventSave;

  /// Label for the event title text field.
  ///
  /// In he, this message translates to:
  /// **'כותרת'**
  String get eventFieldTitleLabel;

  /// Label for the event description text field.
  ///
  /// In he, this message translates to:
  /// **'תיאור'**
  String get eventFieldDescriptionLabel;

  /// Label for the event location text field.
  ///
  /// In he, this message translates to:
  /// **'מיקום'**
  String get eventFieldLocationLabel;

  /// Label for the all-day switch in the event editor, and the time label shown for an all-day event.
  ///
  /// In he, this message translates to:
  /// **'כל היום'**
  String get eventAllDayLabel;

  /// Label for the Hebrew date field/picker in the event editor.
  ///
  /// In he, this message translates to:
  /// **'תאריך עברי'**
  String get eventHebrewDateLabel;

  /// Tooltip of the button that sets the event's Hebrew date from a Gregorian date (M16).
  ///
  /// In he, this message translates to:
  /// **'בחירה לפי תאריך לועזי'**
  String get eventPickByGregorianDate;

  /// Explains the before/after sunset choice after picking a Gregorian date (M16).
  ///
  /// In he, this message translates to:
  /// **'היום העברי מתחיל בשקיעה. אם זה היה בערב או בלילה, התאריך העברי הוא של היום הבא.'**
  String get eventSunsetQuestion;

  /// Button: the Gregorian day was before sunset, so this Hebrew date (M16).
  ///
  /// In he, this message translates to:
  /// **'לפני השקיעה: {date}'**
  String eventBeforeSunset(String date);

  /// Button: the Gregorian day was after sunset, so the next Hebrew date (M16).
  ///
  /// In he, this message translates to:
  /// **'אחרי השקיעה: {date}'**
  String eventAfterSunset(String date);

  /// Label of the leap-year Adar choice for a yearly event in Adar (M15).
  ///
  /// In he, this message translates to:
  /// **'בשנה מעוברת'**
  String get eventLeapAdarLabel;

  /// Leap-year Adar choice: Adar I (M15).
  ///
  /// In he, this message translates to:
  /// **'אדר א׳'**
  String get eventLeapAdarI;

  /// Leap-year Adar choice: Adar II (M15).
  ///
  /// In he, this message translates to:
  /// **'אדר ב׳'**
  String get eventLeapAdarII;

  /// Leap-year Adar choice: both Adars (M15).
  ///
  /// In he, this message translates to:
  /// **'שניהם'**
  String get eventLeapAdarBoth;

  /// Label of the choice for a yearly event on day 30 in a 29-day month (M15).
  ///
  /// In he, this message translates to:
  /// **'כשאין ל׳ בחודש'**
  String get eventShortMonthLabel;

  /// Day-30 choice: the 1st of the next month (M15, default).
  ///
  /// In he, this message translates to:
  /// **'א׳ בחודש הבא'**
  String get eventShortMonthNext;

  /// Day-30 choice: the 29th of the same month (M15).
  ///
  /// In he, this message translates to:
  /// **'כ״ט בחודש'**
  String get eventShortMonthLast;

  /// Closes a choice sheet in the event editor.
  ///
  /// In he, this message translates to:
  /// **'סיום'**
  String get editorSheetDone;

  /// Title of the reminders sheet (several can be chosen).
  ///
  /// In he, this message translates to:
  /// **'תזכורות'**
  String get eventRemindersSheetTitle;

  /// Adds a custom reminder (number + unit).
  ///
  /// In he, this message translates to:
  /// **'מותאם אישית'**
  String get eventReminderCustom;

  /// Reminder N hours before.
  ///
  /// In he, this message translates to:
  /// **'{hours, plural, =1{שעה לפני} =2{שעתיים לפני} other{{hours} שעות לפני}}'**
  String eventReminderHoursBefore(int hours);

  /// Reminder N days before.
  ///
  /// In he, this message translates to:
  /// **'{days, plural, =1{יום לפני} =2{יומיים לפני} other{{days} ימים לפני}}'**
  String eventReminderDaysBefore(int days);

  /// Reminder N weeks before.
  ///
  /// In he, this message translates to:
  /// **'{weeks, plural, =1{שבוע לפני} =2{שבועיים לפני} other{{weeks} שבועות לפני}}'**
  String eventReminderWeeksBefore(int weeks);

  /// Custom reminder unit.
  ///
  /// In he, this message translates to:
  /// **'דקות לפני'**
  String get eventReminderUnitMinutes;

  /// Custom reminder unit.
  ///
  /// In he, this message translates to:
  /// **'שעות לפני'**
  String get eventReminderUnitHours;

  /// Custom reminder unit.
  ///
  /// In he, this message translates to:
  /// **'ימים לפני'**
  String get eventReminderUnitDays;

  /// Custom reminder unit.
  ///
  /// In he, this message translates to:
  /// **'שבועות לפני'**
  String get eventReminderUnitWeeks;

  /// Hint of the large title field in the compact editor.
  ///
  /// In he, this message translates to:
  /// **'הוספת כותרת'**
  String get eventTitleHint;

  /// The color row of the compact editor.
  ///
  /// In he, this message translates to:
  /// **'צבע: {name}'**
  String eventColorRow(String name);

  /// Opens the event's location in Google Maps (M20).
  ///
  /// In he, this message translates to:
  /// **'פתח ב-Google Maps'**
  String get locationOpenInMaps;

  /// Navigates to the event's location with Waze (M20).
  ///
  /// In he, this message translates to:
  /// **'נווט עם Waze'**
  String get locationNavigateWaze;

  /// Shown when no app could open the location link.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחתי לפתוח את המפה'**
  String get locationOpenFailed;

  /// Zman: dawn (16.1 degrees).
  ///
  /// In he, this message translates to:
  /// **'עלות השחר'**
  String get zmanAlos;

  /// Zman: sunrise.
  ///
  /// In he, this message translates to:
  /// **'זריחה'**
  String get zmanSunrise;

  /// Zman: latest Shema, Magen Avraham.
  ///
  /// In he, this message translates to:
  /// **'סוף זמן ק״ש (מג״א)'**
  String get zmanShmaMga;

  /// Zman: latest Shema, GRA.
  ///
  /// In he, this message translates to:
  /// **'סוף זמן ק״ש (גר״א)'**
  String get zmanShmaGra;

  /// Zman: latest Shacharit, GRA.
  ///
  /// In he, this message translates to:
  /// **'סוף זמן תפילה (גר״א)'**
  String get zmanTfilaGra;

  /// Zman: midday.
  ///
  /// In he, this message translates to:
  /// **'חצות'**
  String get zmanChatzos;

  /// Zman: earliest Mincha.
  ///
  /// In he, this message translates to:
  /// **'מנחה גדולה'**
  String get zmanMinchaGedola;

  /// Zman: Mincha Ketana.
  ///
  /// In he, this message translates to:
  /// **'מנחה קטנה'**
  String get zmanMinchaKetana;

  /// Zman: Plag HaMincha.
  ///
  /// In he, this message translates to:
  /// **'פלג המנחה'**
  String get zmanPlag;

  /// Zman: sunset.
  ///
  /// In he, this message translates to:
  /// **'שקיעה'**
  String get zmanSunset;

  /// Zman: nightfall.
  ///
  /// In he, this message translates to:
  /// **'צאת הכוכבים'**
  String get zmanTzais;

  /// Friday candle lighting time.
  ///
  /// In he, this message translates to:
  /// **'הדלקת נרות'**
  String get zmanCandleLighting;

  /// Saturday end of Shabbat time.
  ///
  /// In he, this message translates to:
  /// **'צאת שבת'**
  String get zmanHavdalah;

  /// Day view zmanim panel title.
  ///
  /// In he, this message translates to:
  /// **'זמני היום · {place}'**
  String zmanimPanelTitle(String place);

  /// Place label when the phone's position is used.
  ///
  /// In he, this message translates to:
  /// **'המיקום שלי'**
  String get zmanimDevicePosition;

  /// Settings section title for the times of day (M21).
  ///
  /// In he, this message translates to:
  /// **'זמני היום'**
  String get zmanimSettingsTitle;

  /// Settings: city for the times of day.
  ///
  /// In he, this message translates to:
  /// **'עיר'**
  String get zmanimCity;

  /// Settings: use the phone's position.
  ///
  /// In he, this message translates to:
  /// **'מיקום מהטלפון'**
  String get zmanimUseDevice;

  /// Settings: subtitle of the phone-position switch.
  ///
  /// In he, this message translates to:
  /// **'במקום עיר קבועה'**
  String get zmanimUseDeviceSubtitle;

  /// Shown when the position could not be read.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחתי לקבל את המיקום. אפשר לאשר הרשאת מיקום או לבחור עיר.'**
  String get zmanimUseDeviceFailed;

  /// Settings: candle lighting minutes.
  ///
  /// In he, this message translates to:
  /// **'הדלקת נרות'**
  String get zmanimCandleSetting;

  /// Candle lighting offset.
  ///
  /// In he, this message translates to:
  /// **'{minutes} דקות לפני השקיעה'**
  String zmanimCandleMinutes(int minutes);

  /// Candle lighting: the city's custom.
  ///
  /// In he, this message translates to:
  /// **'לפי מנהג העיר ({minutes} דקות)'**
  String zmanimCandleCityCustom(int minutes);

  /// Settings: end-of-Shabbat method.
  ///
  /// In he, this message translates to:
  /// **'צאת שבת'**
  String get zmanimHavdalahSetting;

  /// End of Shabbat: 8.5 degrees.
  ///
  /// In he, this message translates to:
  /// **'צאת הכוכבים (8.5° מתחת לאופק)'**
  String get zmanimHavdalahDegrees;

  /// End of Shabbat: 72 minutes (Rabbeinu Tam).
  ///
  /// In he, this message translates to:
  /// **'72 דקות אחרי השקיעה (ר״ת)'**
  String get zmanimHavdalah72;

  /// Label for the event start time field.
  ///
  /// In he, this message translates to:
  /// **'שעת התחלה'**
  String get eventStartTimeLabel;

  /// Label for the event end time field.
  ///
  /// In he, this message translates to:
  /// **'שעת סיום'**
  String get eventEndTimeLabel;

  /// Placeholder shown for a start/end time field before a time has been picked.
  ///
  /// In he, this message translates to:
  /// **'בחירת שעה'**
  String get eventNoTimeSet;

  /// Section heading above the reminder selector in the event editor.
  ///
  /// In he, this message translates to:
  /// **'תזכורת'**
  String get eventRemindersLabel;

  /// Reminder chip label meaning no reminder is set.
  ///
  /// In he, this message translates to:
  /// **'ללא תזכורת'**
  String get eventReminderNone;

  /// Reminder chip label meaning the reminder fires exactly at the event's start time (0 minutes before, M4).
  ///
  /// In he, this message translates to:
  /// **'בזמן האירוע'**
  String get eventReminderAtEventTime;

  /// Reminder chip label for a fixed number of minutes before the event, e.g. '10 דקות לפני'.
  ///
  /// In he, this message translates to:
  /// **'{minutes} דקות לפני'**
  String eventReminderMinutesBefore(int minutes);

  /// Reminder chip label meaning the reminder fires one day before the event (M4).
  ///
  /// In he, this message translates to:
  /// **'יום לפני'**
  String get eventReminderOneDayBefore;

  /// Inline validation error when the event title is empty.
  ///
  /// In he, this message translates to:
  /// **'יש להזין כותרת'**
  String get eventValidationTitleRequired;

  /// Inline validation error when the event title exceeds the maximum length.
  ///
  /// In he, this message translates to:
  /// **'הכותרת ארוכה מדי'**
  String get eventValidationTitleTooLong;

  /// Inline validation error when the event description exceeds the maximum length.
  ///
  /// In he, this message translates to:
  /// **'התיאור ארוך מדי'**
  String get eventValidationDescriptionTooLong;

  /// Inline validation error when the event location exceeds the maximum length.
  ///
  /// In he, this message translates to:
  /// **'המיקום ארוך מדי'**
  String get eventValidationLocationTooLong;

  /// Inline validation error when the event end time is not after the start time.
  ///
  /// In he, this message translates to:
  /// **'שעת הסיום חייבת להיות אחרי שעת ההתחלה'**
  String get eventValidationEndBeforeStart;

  /// Tooltip/label for the edit action on an event in the day events sheet.
  ///
  /// In he, this message translates to:
  /// **'עריכה'**
  String get eventEditAction;

  /// Tooltip/label for the delete action on an event, and the confirm button in the delete confirmation dialog.
  ///
  /// In he, this message translates to:
  /// **'מחיקה'**
  String get eventDeleteAction;

  /// Title of the confirmation dialog shown before deleting an event.
  ///
  /// In he, this message translates to:
  /// **'מחיקת אירוע'**
  String get eventDeleteConfirmTitle;

  /// Body text of the confirmation dialog shown before deleting an event.
  ///
  /// In he, this message translates to:
  /// **'האם למחוק אירוע זה? לא ניתן לבטל פעולה זו.'**
  String get eventDeleteConfirmMessage;

  /// Body text of the choice dialog shown before deleting an occurrence of a recurring event, offering 'this occurrence only' or 'the whole series'.
  ///
  /// In he, this message translates to:
  /// **'אירוע זה הוא חלק מסדרה חוזרת. איך למחוק?'**
  String get eventDeleteRecurringChoiceMessage;

  /// Button label to delete only the single occurrence being viewed from a recurring event's series (adds it to the recurrence exceptions).
  ///
  /// In he, this message translates to:
  /// **'מופע זה בלבד'**
  String get eventDeleteThisOccurrenceOnly;

  /// Button label to delete an entire recurring event series.
  ///
  /// In he, this message translates to:
  /// **'כל הסדרה'**
  String get eventDeleteWholeSeries;

  /// Section heading above the recurrence type selector in the event editor.
  ///
  /// In he, this message translates to:
  /// **'חזרתיות'**
  String get eventRecurrenceLabel;

  /// Recurrence type chip label: the event does not repeat.
  ///
  /// In he, this message translates to:
  /// **'ללא חזרה'**
  String get recurrenceTypeNone;

  /// Recurrence type chip label: repeats every Hebrew year on the same Hebrew month/day.
  ///
  /// In he, this message translates to:
  /// **'כל שנה (עברי)'**
  String get recurrenceTypeYearly;

  /// Recurrence type chip label: repeats every Hebrew month on the same day.
  ///
  /// In he, this message translates to:
  /// **'כל חודש (עברי)'**
  String get recurrenceTypeMonthly;

  /// Recurrence: every Gregorian year on the same date (M22).
  ///
  /// In he, this message translates to:
  /// **'כל שנה (לועזי)'**
  String get recurrenceTypeGregorianYearly;

  /// Recurrence: every Gregorian month on the same day (M22).
  ///
  /// In he, this message translates to:
  /// **'כל חודש (לועזי)'**
  String get recurrenceTypeGregorianMonthly;

  /// Display switch: Hebrew months (M23).
  ///
  /// In he, this message translates to:
  /// **'תצוגה עברית'**
  String get calendarDisplayHebrew;

  /// Display switch: Gregorian months (M23).
  ///
  /// In he, this message translates to:
  /// **'תצוגה לועזית'**
  String get calendarDisplayGregorian;

  /// Tooltip of the tappable month title (M23).
  ///
  /// In he, this message translates to:
  /// **'החלפה בין תצוגה עברית ללועזית'**
  String get calendarDisplayTooltip;

  /// Settings: subtitle of the Gregorian display switch (M23).
  ///
  /// In he, this message translates to:
  /// **'חודשים לועזיים, התאריך העברי בקטן'**
  String get settingsGregorianDisplaySubtitle;

  /// Recurrence type chip label: repeats every week.
  ///
  /// In he, this message translates to:
  /// **'כל שבוע'**
  String get recurrenceTypeWeekly;

  /// Recurrence type chip label: repeats every day.
  ///
  /// In he, this message translates to:
  /// **'כל יום'**
  String get recurrenceTypeDaily;

  /// Label for the optional 'repeat until' Hebrew date field shown for a recurring event.
  ///
  /// In he, this message translates to:
  /// **'עד תאריך'**
  String get recurrenceUntilLabel;

  /// Placeholder shown for the 'repeat until' field when no end date is set (the series repeats indefinitely).
  ///
  /// In he, this message translates to:
  /// **'ללא תאריך סיום'**
  String get recurrenceUntilNone;

  /// Tooltip for the button that clears the 'repeat until' date, making the series repeat indefinitely again.
  ///
  /// In he, this message translates to:
  /// **'הסרת תאריך סיום'**
  String get recurrenceUntilClearTooltip;

  /// Label for the year dropdown in the Hebrew date picker sheet.
  ///
  /// In he, this message translates to:
  /// **'שנה'**
  String get hebrewDatePickerYearLabel;

  /// Label for the month dropdown in the Hebrew date picker sheet.
  ///
  /// In he, this message translates to:
  /// **'חודש'**
  String get hebrewDatePickerMonthLabel;

  /// Label for the day dropdown in the Hebrew date picker sheet.
  ///
  /// In he, this message translates to:
  /// **'יום'**
  String get hebrewDatePickerDayLabel;

  /// Confirm button label in the Hebrew date picker sheet.
  ///
  /// In he, this message translates to:
  /// **'אישור'**
  String get hebrewDatePickerConfirm;

  /// Label for the Google sign-in button on the sign-in screen.
  ///
  /// In he, this message translates to:
  /// **'כניסה עם Google'**
  String get signInWithGoogleButton;

  /// Snackbar message shown when Google sign-in fails for a reason other than user cancellation.
  ///
  /// In he, this message translates to:
  /// **'אירעה שגיאה בכניסה. נסה שוב.'**
  String get signInErrorMessage;

  /// Secondary button on the sign-in screen (M5c, Google Play review requirement) that enters the full calendar UI with sample data and no authentication at all.
  ///
  /// In he, this message translates to:
  /// **'כניסה במצב הדגמה'**
  String get signInDemoModeButton;

  /// Overflow menu label shown instead of signOutAction while in demo mode — returns to the sign-in screen and clears demo state (M5c).
  ///
  /// In he, this message translates to:
  /// **'התחבר'**
  String get signInReturnToSignInAction;

  /// Label for the sign-out overflow menu item, and the confirm button in the sign-out confirmation dialog.
  ///
  /// In he, this message translates to:
  /// **'התנתקות'**
  String get signOutAction;

  /// Title of the confirmation dialog shown before signing out.
  ///
  /// In he, this message translates to:
  /// **'התנתקות'**
  String get signOutConfirmTitle;

  /// Body text of the confirmation dialog shown before signing out.
  ///
  /// In he, this message translates to:
  /// **'האם להתנתק מהחשבון?'**
  String get signOutConfirmMessage;

  /// Calendar view switcher option/current-view label: month view.
  ///
  /// In he, this message translates to:
  /// **'חודש'**
  String get calendarViewMonth;

  /// Calendar view switcher option/current-view label: week view.
  ///
  /// In he, this message translates to:
  /// **'שבוע'**
  String get calendarViewWeek;

  /// Calendar view switcher option/current-view label: day view.
  ///
  /// In he, this message translates to:
  /// **'יום'**
  String get calendarViewDay;

  /// Calendar view switcher option/current-view label: agenda view. Also shown as the app bar title while the agenda view is active.
  ///
  /// In he, this message translates to:
  /// **'אג\'נדה'**
  String get calendarViewAgenda;

  /// Tooltip for the app bar's view switcher (month/week/day/agenda) button.
  ///
  /// In he, this message translates to:
  /// **'בחירת תצוגה'**
  String get calendarViewSwitcherTooltip;

  /// Tooltip for the app bar's 'today' button, which refocuses the calendar on today without changing the selected view.
  ///
  /// In he, this message translates to:
  /// **'היום'**
  String get calendarTodayTooltip;

  /// Empty-state message shown in the agenda view when there are no upcoming occurrences in the loaded window.
  ///
  /// In he, this message translates to:
  /// **'אין אירועים קרובים'**
  String get agendaEmptyState;

  /// Android notification channel name (M4) for event reminders, shown to the user in the system notification settings.
  ///
  /// In he, this message translates to:
  /// **'תזכורות'**
  String get notificationsChannelName;

  /// Snackbar rationale shown once (M4) when the user denies the OS notification permission, explaining reminders won't show without it.
  ///
  /// In he, this message translates to:
  /// **'בלי הרשאת התראות, תזכורות לאירועים לא יוצגו. ניתן להפעיל בהגדרות המכשיר.'**
  String get notificationsPermissionDeniedMessage;

  /// Tooltip for the app bar's gear icon that opens the settings screen (M5a).
  ///
  /// In he, this message translates to:
  /// **'הגדרות'**
  String get settingsTooltip;

  /// App bar title for the settings screen (M5a).
  ///
  /// In he, this message translates to:
  /// **'הגדרות'**
  String get settingsScreenTitle;

  /// Section heading for the Google Calendar sync settings (M5a).
  ///
  /// In he, this message translates to:
  /// **'סנכרון עם יומן Google'**
  String get settingsGoogleSyncSectionTitle;

  /// Label for the switch that enables/disables Google Calendar sync (M5a).
  ///
  /// In he, this message translates to:
  /// **'סנכרון עם Google Calendar'**
  String get settingsGoogleSyncEnableLabel;

  /// Shows when Google Calendar sync last completed successfully (M5a).
  ///
  /// In he, this message translates to:
  /// **'סונכרן לאחרונה: {time}'**
  String settingsGoogleSyncLastSyncedAt(String time);

  /// Shown instead of a last-sync time before Google Calendar sync has ever completed (M5a).
  ///
  /// In he, this message translates to:
  /// **'טרם בוצע סנכרון'**
  String get settingsGoogleSyncNeverSynced;

  /// Manual sync-now button label on the settings screen (M5a).
  ///
  /// In he, this message translates to:
  /// **'סנכרן עכשיו'**
  String get settingsGoogleSyncNowButton;

  /// Shown while a Google Calendar sync pass is in progress (M5a).
  ///
  /// In he, this message translates to:
  /// **'מסנכרן...'**
  String get settingsGoogleSyncSyncingLabel;

  /// Prefix shown before the error detail when the last Google Calendar sync pass failed (M5a).
  ///
  /// In he, this message translates to:
  /// **'שגיאת סנכרון: {message}'**
  String settingsGoogleSyncErrorPrefix(String message);

  /// Shown when connecting Google Calendar was cancelled, e.g. by leaving Google's unverified-app warning; explains how to continue.
  ///
  /// In he, this message translates to:
  /// **'החיבור ל-Google בוטל. אם הופיע מסך \"Google לא אימתה את האפליקציה\", לוחצים \"מתקדם\" ואז \"המשך ל-לוח עברי\", ומאשרים גישה ליומן.'**
  String get settingsGoogleSyncCancelledMessage;

  /// Snackbar shown when the user denies the Google Calendar access request while enabling sync (M5a).
  ///
  /// In he, this message translates to:
  /// **'לא ניתנה הרשאה ליומן Google. אי אפשר להפעיל סנכרון.'**
  String get settingsGoogleSyncAccessDeniedMessage;

  /// Snackbar shown when enabling or disabling Google Calendar sync fails for a real reason (not a plain user cancel/decline) — e.g. the Google account session could not be restored (device-feedback round #3). {details} is the underlying error text, always shown, never swallowed.
  ///
  /// In he, this message translates to:
  /// **'אירעה שגיאה: {details}'**
  String settingsGoogleSyncActionFailedMessage(String details);

  /// Read-only line on the settings screen showing whether periodic background sync (M5b, via WorkManager) is currently active — the status itself comes from settingsBackgroundSyncStatusActive/settingsBackgroundSyncStatusOff. There is no separate toggle: background sync follows the main Google Calendar sync switch automatically.
  ///
  /// In he, this message translates to:
  /// **'סנכרון ברקע: {status}'**
  String settingsBackgroundSyncStatus(String status);

  /// Background sync status value (M5b) when Google Calendar sync is enabled: the periodic WorkManager task runs roughly every 6 hours.
  ///
  /// In he, this message translates to:
  /// **'פעיל (כל 6 שעות)'**
  String get settingsBackgroundSyncStatusActive;

  /// Background sync status value (M5b) when Google Calendar sync is disabled, so no periodic background task is registered.
  ///
  /// In he, this message translates to:
  /// **'כבוי'**
  String get settingsBackgroundSyncStatusOff;

  /// Error message shown instead of the Google Calendar sync section when its initial settings failed to load or timed out (real-device report: previously an endless spinner instead of this message).
  ///
  /// In he, this message translates to:
  /// **'לא ניתן היה לטעון את הגדרות הסנכרון. בדוק את החיבור לאינטרנט ונסה שוב.'**
  String get settingsGoogleSyncLoadFailedMessage;

  /// Retry button label shown alongside settingsGoogleSyncLoadFailedMessage.
  ///
  /// In he, this message translates to:
  /// **'נסה שוב'**
  String get settingsGoogleSyncRetryButton;

  /// Shown instead of settingsGoogleSyncLoadFailedMessage when the settings screen's own local loading watchdog (not GoogleSyncTriggerService.start()'s timeout) is what ended the spinner — a last-resort fallback in case every provider layer misbehaves (real-device report #2, round 2).
  ///
  /// In he, this message translates to:
  /// **'תקלה בטעינה'**
  String get settingsGoogleSyncWatchdogMessage;

  /// Shown instead of the Google Calendar sync switch/controls while in demo mode (no signed-in account to sync with).
  ///
  /// In he, this message translates to:
  /// **'דורש התחברות עם Google'**
  String get settingsGoogleSyncDisabledDemoMessage;

  /// Section heading for the local-file backup/restore settings (M7).
  ///
  /// In he, this message translates to:
  /// **'גיבוי ושחזור'**
  String get settingsBackupSectionTitle;

  /// Explanatory text under the backup section heading (M7).
  ///
  /// In he, this message translates to:
  /// **'ייצוא כל האירועים לקובץ, ושחזור מקובץ קיים. הנתונים חיים גם ב-Google, אך זהו גיבוי ידני נוסף שנשמר אצלך.'**
  String get settingsBackupDescription;

  /// Button label that exports every event to a JSON file the user saves directly (M7).
  ///
  /// In he, this message translates to:
  /// **'ייצוא'**
  String get settingsBackupExportButton;

  /// Tooltip for the icon button that shares the backup file via the OS share sheet instead of saving it directly (M7).
  ///
  /// In he, this message translates to:
  /// **'שיתוף קובץ הגיבוי'**
  String get settingsBackupShareTooltip;

  /// Button label that starts the restore-from-backup-file flow (M7).
  ///
  /// In he, this message translates to:
  /// **'שחזור'**
  String get settingsBackupImportButton;

  /// Title of the confirmation dialog shown before restoring from a backup file (M7).
  ///
  /// In he, this message translates to:
  /// **'שחזור מגיבוי'**
  String get settingsBackupImportConfirmTitle;

  /// Body text of the confirmation dialog before restoring from a backup file, explaining the merge-by-id semantics (M7).
  ///
  /// In he, this message translates to:
  /// **'אירועים מהקובץ ישולבו עם האירועים הקיימים: אירוע עם מזהה זהה יוחלף, ואירועים חדשים יתווספו. שום אירוע קיים לא יימחק. להמשיך?'**
  String get settingsBackupImportConfirmMessage;

  /// Confirm button label in the restore-from-backup confirmation dialog (M7).
  ///
  /// In he, this message translates to:
  /// **'שחזור'**
  String get settingsBackupImportConfirmButton;

  /// Snackbar shown after a backup file was saved/shared successfully (M7).
  ///
  /// In he, this message translates to:
  /// **'הגיבוי נשמר בהצלחה'**
  String get settingsBackupExportSuccessMessage;

  /// Snackbar shown when exporting/sharing the backup file fails (M7).
  ///
  /// In he, this message translates to:
  /// **'אירעה שגיאה בייצוא הגיבוי'**
  String get settingsBackupExportErrorMessage;

  /// Snackbar shown after a successful restore, summarizing how many events were created vs. overwritten (M7).
  ///
  /// In he, this message translates to:
  /// **'השחזור הושלם: {created} אירועים חדשים, {updated} עודכנו'**
  String settingsBackupImportSuccessMessage(int created, int updated);

  /// Snackbar shown when restoring from a backup file fails (M7).
  ///
  /// In he, this message translates to:
  /// **'אירעה שגיאה בשחזור הגיבוי'**
  String get settingsBackupImportErrorMessage;

  /// Snackbar shown when the backup file's format version is newer than this build of the app understands (M7).
  ///
  /// In he, this message translates to:
  /// **'קובץ הגיבוי נוצר בגרסה חדשה יותר של האפליקציה ואינו נתמך כאן'**
  String get settingsBackupImportUnsupportedVersionMessage;

  /// Footer text on the settings screen showing the installed app version (M7).
  ///
  /// In he, this message translates to:
  /// **'גרסה {version}'**
  String settingsVersionLabel(String version);

  /// Label for the settings screen list item that opens the About screen (M5c).
  ///
  /// In he, this message translates to:
  /// **'אודות'**
  String get settingsAboutTooltip;

  /// App bar title for the About screen (M5c).
  ///
  /// In he, this message translates to:
  /// **'אודות'**
  String get aboutScreenTitle;

  /// Short tagline shown under the app name on the About screen (M5c).
  ///
  /// In he, this message translates to:
  /// **'היומן שבו התאריך העברי במרכז'**
  String get aboutTagline;

  /// Maker credit on the About screen: the KALFAPP app family (owner-approved rebrand, ARCHITECTURE.md §13).
  ///
  /// In he, this message translates to:
  /// **'מבית KALFAPP'**
  String get aboutDeveloperCredit;

  /// Button on the About screen that opens Flutter's built-in open-source licenses page (M5c).
  ///
  /// In he, this message translates to:
  /// **'רישיונות קוד פתוח'**
  String get aboutLicensesButton;

  /// Heading under the KALFAPP logo on the About screen, as in PowerWatch.
  ///
  /// In he, this message translates to:
  /// **'אודות האפליקציה'**
  String get aboutHeading;

  /// The About screen's explanation, in the owner's personal voice shared with PowerWatch.
  ///
  /// In he, this message translates to:
  /// **'לוח עברי נועד למי שחי לפי התאריך העברי, כמו ימי הולדת, אזכרות, ימי נישואין וחגים, ורוצה יומן אחד שבו הכל מסודר.\n\nהאפליקציה פשוטה. יוצרים אירוע, בוחרים שהוא חוזר לפי התאריך העברי, והוא יופיע במקום הנכון בכל שנה, גם בשנה מעוברת. החגים והפרשה מופיעים בלוח מעצמם, והכל מסתנכרן עם Google Calendar בשני הכיוונים.\n\nהשימוש באפליקציה הוא על אחריות המשתמש. למרות שאנחנו עושים את המקסימום כדי לשמור על המידע ועל הפרטיות שלכם, זהו פרויקט התנדבותי לחלוטין ולכן אין שום אחריות מכל סוג שהוא לא על תקינות האפליקציה ולא על שמירת הנתונים.\n\nעם זאת, אם יש לך רעיון לשיפור, נשמח לקבל פידבקים ורעיונות לאפליקציות נוספות.'**
  String get aboutBody;

  /// The owner's sign-off at the end of the About text.
  ///
  /// In he, this message translates to:
  /// **'בהצלחה!\nנתן-אור.'**
  String get aboutSignature;

  /// Screen-reader label for the KALFAPP logo on the About screen.
  ///
  /// In he, this message translates to:
  /// **'KALFAPP'**
  String get aboutLogoSemantics;

  /// Shown in the month view's day agenda (below the grid) when the selected day has no events.
  ///
  /// In he, this message translates to:
  /// **'אין אירועים ביום זה'**
  String get monthAgendaEmpty;

  /// Header of the month view's day agenda, e.g. 'יום שני, א׳ חשוון'.
  ///
  /// In he, this message translates to:
  /// **'יום {weekday}, {day} {month}'**
  String monthAgendaDayHeader(String weekday, String day, String month);

  /// Tag in the month view's day agenda naming the weekly Torah portion read on that Shabbat (M8).
  ///
  /// In he, this message translates to:
  /// **'פרשת {name}'**
  String monthAgendaParshaTag(String name);

  /// Sync progress: the pass is starting.
  ///
  /// In he, this message translates to:
  /// **'מתחיל סנכרון'**
  String get syncProgressStarting;

  /// Sync progress: fetching changes from Google (count not known yet).
  ///
  /// In he, this message translates to:
  /// **'מוריד שינויים מ-Google'**
  String get syncProgressDownloading;

  /// Sync progress: writing Google's changes into the app.
  ///
  /// In he, this message translates to:
  /// **'מעדכן ביומן: {done} מתוך {total}'**
  String syncProgressApplying(String done, String total);

  /// Sync progress: sending the app's changes to Google.
  ///
  /// In he, this message translates to:
  /// **'שולח ל-Google: {done} מתוך {total}'**
  String syncProgressUploading(String done, String total);

  /// Settings switch for dark mode, as in PowerWatch (follows the system until changed).
  ///
  /// In he, this message translates to:
  /// **'מצב כהה'**
  String get settingsDarkModeTitle;

  /// Settings switch (M8): whether holidays and the parsha follow the Israel calendar.
  ///
  /// In he, this message translates to:
  /// **'לוח ארץ ישראל'**
  String get settingsInIsraelTitle;

  /// Explains the Israel/diaspora calendar switch in Settings (M8).
  ///
  /// In he, this message translates to:
  /// **'כבוי: לוח חו״ל (יום טוב שני של גלויות וסדר הפרשות בחו״ל)'**
  String get settingsInIsraelSubtitle;

  /// Snackbar after pulling the calendar down ran a Google Calendar sync successfully.
  ///
  /// In he, this message translates to:
  /// **'הסנכרון עם Google הושלם'**
  String get calendarPullSyncDoneMessage;

  /// Snackbar when the user pulls the calendar down to sync but Google Calendar sync is turned off.
  ///
  /// In he, this message translates to:
  /// **'הסנכרון עם Google כבוי. אפשר להפעיל אותו בהגדרות.'**
  String get calendarPullSyncDisabledMessage;

  /// Snackbar when the user pulls down to sync while another Google sync pass is already in progress.
  ///
  /// In he, this message translates to:
  /// **'סנכרון כבר מתבצע ברגע זה. נסה שוב בעוד רגע.'**
  String get calendarPullSyncAlreadyRunningMessage;

  /// Title of the choice dialog shown before editing an occurrence of a recurring event (M9).
  ///
  /// In he, this message translates to:
  /// **'אירוע זה הוא חלק מסדרה חוזרת. על מה להחיל את השינוי?'**
  String get eventEditRecurringChoiceMessage;

  /// Option in the recurring edit/delete dialog: apply to this occurrence and all later ones (M9).
  ///
  /// In he, this message translates to:
  /// **'מופע זה והבאים אחריו'**
  String get eventScopeThisAndFollowing;

  /// Note at the top of the event editor when editing a single occurrence of a recurring series (M9).
  ///
  /// In he, this message translates to:
  /// **'עורך רק את המופע הזה. שאר הסדרה לא תשתנה.'**
  String get eventEditorScopeThisOccurrenceNote;

  /// Note at the top of the event editor when editing an occurrence and all following ones of a recurring series (M9).
  ///
  /// In he, this message translates to:
  /// **'עורך את המופע הזה ואת כל הבאים אחריו. מופעים קודמים לא ישתנו.'**
  String get eventEditorScopeThisAndFollowingNote;

  /// Section label for the event color picker in the event editor (M10).
  ///
  /// In he, this message translates to:
  /// **'צבע'**
  String get eventColorLabel;

  /// Tooltip of the default-color swatch in the event color picker (M10).
  ///
  /// In he, this message translates to:
  /// **'ברירת מחדל'**
  String get eventColorDefault;

  /// Hebrew name of one of Google Calendar's 11 event colors, by its Google colorId (M10).
  ///
  /// In he, this message translates to:
  /// **'{id, select, 1{לבנדר} 2{מרווה} 3{ענבים} 4{פלמינגו} 5{בננה} 6{מנדרינה} 7{טווס} 8{גרפיט} 9{אוכמניות} 10{בזיליקום} 11{עגבנייה} other{צבע}}'**
  String eventColorOption(String id);

  /// Section label for participants in the event editor (M11).
  ///
  /// In he, this message translates to:
  /// **'משתתפים'**
  String get eventAttendeesLabel;

  /// Label of the email field used to invite a participant (M11).
  ///
  /// In he, this message translates to:
  /// **'הוספת משתתף לפי מייל'**
  String get eventAttendeesFieldLabel;

  /// Helper text under the participant email field explaining that Google sends the invitation (M11).
  ///
  /// In he, this message translates to:
  /// **'Google Calendar ישלח להם זימון במייל אחרי הסנכרון'**
  String get eventAttendeesHelper;

  /// Error when the typed participant email is invalid or already invited (M11).
  ///
  /// In he, this message translates to:
  /// **'כתובת מייל לא תקינה, או שהיא כבר ברשימה'**
  String get eventAttendeesInvalid;

  /// Tooltip of the button that adds the typed participant email (M11).
  ///
  /// In he, this message translates to:
  /// **'הוספה'**
  String get eventAttendeesAdd;

  /// Participant reply: accepted (M11).
  ///
  /// In he, this message translates to:
  /// **'אישר/ה הגעה'**
  String get attendeeAccepted;

  /// Participant reply: declined (M11).
  ///
  /// In he, this message translates to:
  /// **'לא מגיע/ה'**
  String get attendeeDeclined;

  /// Participant reply: tentative (M11).
  ///
  /// In he, this message translates to:
  /// **'אולי'**
  String get attendeeTentative;

  /// Participant has not replied yet (M11).
  ///
  /// In he, this message translates to:
  /// **'טרם השיב/ה'**
  String get attendeeNoReply;

  /// Short participants summary under an event in the day events sheet (M11).
  ///
  /// In he, this message translates to:
  /// **'{count} משתתפים, {accepted} אישרו'**
  String eventAttendeesSummary(int count, int accepted);

  /// App bar button opening the go-to-date sheet (M12).
  ///
  /// In he, this message translates to:
  /// **'מעבר לתאריך'**
  String get goToDateTooltip;

  /// Go-to-date option: pick a Hebrew date (M12).
  ///
  /// In he, this message translates to:
  /// **'דילוג לתאריך עברי'**
  String get goToHebrewDate;

  /// Go-to-date option: pick a Gregorian date (M12).
  ///
  /// In he, this message translates to:
  /// **'דילוג לתאריך לועזי'**
  String get goToGregorianDate;

  /// App bar button opening event search (M13).
  ///
  /// In he, this message translates to:
  /// **'חיפוש'**
  String get searchTooltip;

  /// Hint text of the event search field (M13).
  ///
  /// In he, this message translates to:
  /// **'חיפוש בכותרת, תיאור או מיקום'**
  String get searchHint;

  /// Shown when an event search has no matches (M13).
  ///
  /// In he, this message translates to:
  /// **'לא נמצאו אירועים'**
  String get searchNoResults;

  /// Marks a recurring event in search results (M13).
  ///
  /// In he, this message translates to:
  /// **'חוזר'**
  String get searchRecurringNote;

  /// Add menu: open the regular event editor (M24).
  ///
  /// In he, this message translates to:
  /// **'אירוע חדש'**
  String get addMenuNewEvent;

  /// Add menu: open the significant-date tool (M24).
  ///
  /// In he, this message translates to:
  /// **'תאריך משמעותי'**
  String get addMenuSignificantDate;

  /// Subtitle of the significant-date entry in the add menu (M24).
  ///
  /// In he, this message translates to:
  /// **'יום הולדת, יארצייט, יום נישואין, לפי תאריך לועזי'**
  String get addMenuSignificantDateHint;

  /// App bar title of the significant-date tool (M24).
  ///
  /// In he, this message translates to:
  /// **'תאריך משמעותי'**
  String get significantTitle;

  /// Significant date kind (M24).
  ///
  /// In he, this message translates to:
  /// **'יום הולדת'**
  String get significantKindBirthday;

  /// Significant date kind (M24).
  ///
  /// In he, this message translates to:
  /// **'יארצייט'**
  String get significantKindYahrzeit;

  /// Significant date kind (M24).
  ///
  /// In he, this message translates to:
  /// **'יום נישואין'**
  String get significantKindAnniversary;

  /// Significant date kind (M24).
  ///
  /// In he, this message translates to:
  /// **'אחר'**
  String get significantKindOther;

  /// Name field of the significant-date tool (M24).
  ///
  /// In he, this message translates to:
  /// **'שם'**
  String get significantNameLabel;

  /// Name field hint for the 'other' kind (M24).
  ///
  /// In he, this message translates to:
  /// **'למשל: עלייה לארץ'**
  String get significantNameHintOther;

  /// Label of the original Gregorian date button (M24).
  ///
  /// In he, this message translates to:
  /// **'התאריך הלועזי המקורי'**
  String get significantDateLabel;

  /// Shown on the date button before a date is picked (M24).
  ///
  /// In he, this message translates to:
  /// **'בחירת תאריך'**
  String get significantDatePick;

  /// Label of the before/after sunset choice (M24).
  ///
  /// In he, this message translates to:
  /// **'מתי ביום?'**
  String get significantSunsetLabel;

  /// Sunset choice (M24).
  ///
  /// In he, this message translates to:
  /// **'לפני השקיעה'**
  String get significantSunsetBefore;

  /// Sunset choice (M24).
  ///
  /// In he, this message translates to:
  /// **'אחרי השקיעה'**
  String get significantSunsetAfter;

  /// Sunset choice: unknown, treated as before sunset (M24).
  ///
  /// In he, this message translates to:
  /// **'לא יודע'**
  String get significantSunsetUnknown;

  /// Preview: the Gregorian date was this Hebrew date (M24).
  ///
  /// In he, this message translates to:
  /// **'{gregorian} היה {hebrew}.'**
  String significantPreviewWas(String gregorian, String hebrew);

  /// Preview: the next occurrence (M24).
  ///
  /// In he, this message translates to:
  /// **'השנה יחול ב-{hebrew}, {gregorian}.'**
  String significantPreviewNext(String hebrew, String gregorian);

  /// Preview note for a yahrzeit in Adar (M24).
  ///
  /// In he, this message translates to:
  /// **'בשנה מעוברת: באדר א׳.'**
  String get significantAdarNote;

  /// Checkbox: also create a yearly Gregorian event (M24).
  ///
  /// In he, this message translates to:
  /// **'להוסיף גם את התאריך הלועזי'**
  String get significantAlsoGregorian;

  /// Save button of the significant-date tool (M24).
  ///
  /// In he, this message translates to:
  /// **'יצירת אירוע'**
  String get significantSave;

  /// Snackbar after saving (M24).
  ///
  /// In he, this message translates to:
  /// **'נוצר: {title}'**
  String significantSaved(String title);

  /// Event title (M24).
  ///
  /// In he, this message translates to:
  /// **'יום הולדת עברי – {name}'**
  String significantTitleBirthdayHebrew(String name);

  /// Event title (M24).
  ///
  /// In he, this message translates to:
  /// **'יום הולדת – {name}'**
  String significantTitleBirthdayGregorian(String name);

  /// Event title (M24).
  ///
  /// In he, this message translates to:
  /// **'יארצייט – {name}'**
  String significantTitleYahrzeitHebrew(String name);

  /// Event title (M24).
  ///
  /// In he, this message translates to:
  /// **'יום פטירה (לועזי) – {name}'**
  String significantTitleYahrzeitGregorian(String name);

  /// Event title (M24).
  ///
  /// In he, this message translates to:
  /// **'יום נישואין עברי – {name}'**
  String significantTitleAnniversaryHebrew(String name);

  /// Event title (M24).
  ///
  /// In he, this message translates to:
  /// **'יום נישואין – {name}'**
  String significantTitleAnniversaryGregorian(String name);

  /// Event title (M24).
  ///
  /// In he, this message translates to:
  /// **'{name} (עברי)'**
  String significantTitleOtherHebrew(String name);

  /// Event title (M24).
  ///
  /// In he, this message translates to:
  /// **'{name} (לועזי)'**
  String significantTitleOtherGregorian(String name);

  /// Day dropdown of the original Gregorian date (M24).
  ///
  /// In he, this message translates to:
  /// **'יום'**
  String get significantDayLabel;

  /// Month dropdown of the original Gregorian date (M24).
  ///
  /// In he, this message translates to:
  /// **'חודש'**
  String get significantMonthLabel;

  /// Year dropdown of the original Gregorian date (M24).
  ///
  /// In he, this message translates to:
  /// **'שנה'**
  String get significantYearLabel;

  /// Backup card: share the backup file (WhatsApp, mail, Drive...).
  ///
  /// In he, this message translates to:
  /// **'שיתוף'**
  String get settingsBackupShareButton;

  /// Phone number in an event: call it.
  ///
  /// In he, this message translates to:
  /// **'חיוג'**
  String get linkCall;

  /// Phone number in an event: open a WhatsApp chat.
  ///
  /// In he, this message translates to:
  /// **'וואטסאפ'**
  String get linkWhatsApp;

  /// Email in an event: compose a mail.
  ///
  /// In he, this message translates to:
  /// **'שליחת מייל'**
  String get linkSendEmail;

  /// Phone or email in an event: copy it.
  ///
  /// In he, this message translates to:
  /// **'העתקה'**
  String get linkCopy;

  /// Snackbar after copying a phone or email.
  ///
  /// In he, this message translates to:
  /// **'הועתק'**
  String get linkCopied;

  /// Snackbar when no app can open a link, number or email.
  ///
  /// In he, this message translates to:
  /// **'לא ניתן לפתוח'**
  String get linkOpenFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
