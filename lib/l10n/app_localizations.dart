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
  /// **'יומן עברי'**
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

  /// Snackbar shown when the user denies the Google Calendar access request while enabling sync (M5a).
  ///
  /// In he, this message translates to:
  /// **'לא ניתנה הרשאה ליומן Google. אי אפשר להפעיל סנכרון.'**
  String get settingsGoogleSyncAccessDeniedMessage;
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
