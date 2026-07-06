// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'יומן עברי';

  @override
  String get commonCancel => 'ביטול';

  @override
  String get addEventTooltip => 'הוספת אירוע';

  @override
  String get eventEditorTitleNew => 'אירוע חדש';

  @override
  String get eventEditorTitleEdit => 'עריכת אירוע';

  @override
  String get eventSave => 'שמירה';

  @override
  String get eventFieldTitleLabel => 'כותרת';

  @override
  String get eventFieldDescriptionLabel => 'תיאור';

  @override
  String get eventFieldLocationLabel => 'מיקום';

  @override
  String get eventAllDayLabel => 'כל היום';

  @override
  String get eventHebrewDateLabel => 'תאריך עברי';

  @override
  String get eventStartTimeLabel => 'שעת התחלה';

  @override
  String get eventEndTimeLabel => 'שעת סיום';

  @override
  String get eventNoTimeSet => 'בחירת שעה';

  @override
  String get eventRemindersLabel => 'תזכורת';

  @override
  String get eventReminderNone => 'ללא תזכורת';

  @override
  String get eventReminderAtEventTime => 'בזמן האירוע';

  @override
  String eventReminderMinutesBefore(int minutes) {
    return '$minutes דקות לפני';
  }

  @override
  String get eventReminderOneDayBefore => 'יום לפני';

  @override
  String get eventValidationTitleRequired => 'יש להזין כותרת';

  @override
  String get eventValidationTitleTooLong => 'הכותרת ארוכה מדי';

  @override
  String get eventValidationDescriptionTooLong => 'התיאור ארוך מדי';

  @override
  String get eventValidationLocationTooLong => 'המיקום ארוך מדי';

  @override
  String get eventValidationEndBeforeStart =>
      'שעת הסיום חייבת להיות אחרי שעת ההתחלה';

  @override
  String get eventEditAction => 'עריכה';

  @override
  String get eventDeleteAction => 'מחיקה';

  @override
  String get eventDeleteConfirmTitle => 'מחיקת אירוע';

  @override
  String get eventDeleteConfirmMessage =>
      'האם למחוק אירוע זה? לא ניתן לבטל פעולה זו.';

  @override
  String get eventDeleteRecurringChoiceMessage =>
      'אירוע זה הוא חלק מסדרה חוזרת. איך למחוק?';

  @override
  String get eventDeleteThisOccurrenceOnly => 'מופע זה בלבד';

  @override
  String get eventDeleteWholeSeries => 'כל הסדרה';

  @override
  String get eventRecurrenceLabel => 'חזרתיות';

  @override
  String get recurrenceTypeNone => 'ללא חזרה';

  @override
  String get recurrenceTypeYearly => 'כל שנה (עברי)';

  @override
  String get recurrenceTypeMonthly => 'כל חודש (עברי)';

  @override
  String get recurrenceTypeWeekly => 'כל שבוע';

  @override
  String get recurrenceTypeDaily => 'כל יום';

  @override
  String get recurrenceUntilLabel => 'עד תאריך';

  @override
  String get recurrenceUntilNone => 'ללא תאריך סיום';

  @override
  String get recurrenceUntilClearTooltip => 'הסרת תאריך סיום';

  @override
  String get hebrewDatePickerYearLabel => 'שנה';

  @override
  String get hebrewDatePickerMonthLabel => 'חודש';

  @override
  String get hebrewDatePickerDayLabel => 'יום';

  @override
  String get hebrewDatePickerConfirm => 'אישור';

  @override
  String get signInWithGoogleButton => 'כניסה עם Google';

  @override
  String get signInErrorMessage => 'אירעה שגיאה בכניסה. נסה שוב.';

  @override
  String get signOutAction => 'התנתקות';

  @override
  String get signOutConfirmTitle => 'התנתקות';

  @override
  String get signOutConfirmMessage => 'האם להתנתק מהחשבון?';

  @override
  String get calendarViewMonth => 'חודש';

  @override
  String get calendarViewWeek => 'שבוע';

  @override
  String get calendarViewDay => 'יום';

  @override
  String get calendarViewAgenda => 'אג\'נדה';

  @override
  String get calendarViewSwitcherTooltip => 'בחירת תצוגה';

  @override
  String get calendarTodayTooltip => 'היום';

  @override
  String get agendaEmptyState => 'אין אירועים קרובים';

  @override
  String get notificationsChannelName => 'תזכורות';

  @override
  String get notificationsPermissionDeniedMessage =>
      'בלי הרשאת התראות, תזכורות לאירועים לא יוצגו. ניתן להפעיל בהגדרות המכשיר.';

  @override
  String get settingsTooltip => 'הגדרות';

  @override
  String get settingsScreenTitle => 'הגדרות';

  @override
  String get settingsGoogleSyncSectionTitle => 'סנכרון עם יומן Google';

  @override
  String get settingsGoogleSyncEnableLabel => 'סנכרון עם Google Calendar';

  @override
  String settingsGoogleSyncLastSyncedAt(String time) {
    return 'סונכרן לאחרונה: $time';
  }

  @override
  String get settingsGoogleSyncNeverSynced => 'טרם בוצע סנכרון';

  @override
  String get settingsGoogleSyncNowButton => 'סנכרן עכשיו';

  @override
  String get settingsGoogleSyncSyncingLabel => 'מסנכרן...';

  @override
  String settingsGoogleSyncErrorPrefix(String message) {
    return 'שגיאת סנכרון: $message';
  }

  @override
  String get settingsGoogleSyncAccessDeniedMessage =>
      'לא ניתנה הרשאה ליומן Google. אי אפשר להפעיל סנכרון.';
}
