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
  String get eventPickByGregorianDate => 'בחירה לפי תאריך לועזי';

  @override
  String get eventSunsetQuestion =>
      'היום העברי מתחיל בשקיעה. אם זה היה בערב או בלילה, התאריך העברי הוא של היום הבא.';

  @override
  String eventBeforeSunset(String date) {
    return 'לפני השקיעה: $date';
  }

  @override
  String eventAfterSunset(String date) {
    return 'אחרי השקיעה: $date';
  }

  @override
  String get eventLeapAdarLabel => 'בשנה מעוברת';

  @override
  String get eventLeapAdarI => 'אדר א׳';

  @override
  String get eventLeapAdarII => 'אדר ב׳';

  @override
  String get eventLeapAdarBoth => 'שניהם';

  @override
  String get eventShortMonthLabel => 'כשאין ל׳ בחודש';

  @override
  String get eventShortMonthNext => 'א׳ בחודש הבא';

  @override
  String get eventShortMonthLast => 'כ״ט בחודש';

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
  String get signInDemoModeButton => 'כניסה במצב הדגמה';

  @override
  String get signInReturnToSignInAction => 'התחבר';

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
  String get settingsGoogleSyncCancelledMessage =>
      'החיבור ל-Google בוטל. אם הופיע מסך \"Google לא אימתה את האפליקציה\", לוחצים \"מתקדם\" ואז \"המשך ל-לוח עברי\", ומאשרים גישה ליומן.';

  @override
  String get settingsGoogleSyncAccessDeniedMessage =>
      'לא ניתנה הרשאה ליומן Google. אי אפשר להפעיל סנכרון.';

  @override
  String settingsGoogleSyncActionFailedMessage(String details) {
    return 'אירעה שגיאה: $details';
  }

  @override
  String settingsBackgroundSyncStatus(String status) {
    return 'סנכרון ברקע: $status';
  }

  @override
  String get settingsBackgroundSyncStatusActive => 'פעיל (כל 6 שעות)';

  @override
  String get settingsBackgroundSyncStatusOff => 'כבוי';

  @override
  String get settingsGoogleSyncLoadFailedMessage =>
      'לא ניתן היה לטעון את הגדרות הסנכרון. בדוק את החיבור לאינטרנט ונסה שוב.';

  @override
  String get settingsGoogleSyncRetryButton => 'נסה שוב';

  @override
  String get settingsGoogleSyncWatchdogMessage => 'תקלה בטעינה';

  @override
  String get settingsGoogleSyncDisabledDemoMessage => 'דורש התחברות עם Google';

  @override
  String get settingsBackupSectionTitle => 'גיבוי ושחזור';

  @override
  String get settingsBackupDescription =>
      'ייצוא כל האירועים לקובץ, ושחזור מקובץ קיים. הנתונים חיים גם ב-Google, אך זהו גיבוי ידני נוסף שנשמר אצלך.';

  @override
  String get settingsBackupExportButton => 'ייצוא גיבוי';

  @override
  String get settingsBackupShareTooltip => 'שיתוף קובץ הגיבוי';

  @override
  String get settingsBackupImportButton => 'שחזור מגיבוי';

  @override
  String get settingsBackupImportConfirmTitle => 'שחזור מגיבוי';

  @override
  String get settingsBackupImportConfirmMessage =>
      'אירועים מהקובץ ישולבו עם האירועים הקיימים: אירוע עם מזהה זהה יוחלף, ואירועים חדשים יתווספו. שום אירוע קיים לא יימחק. להמשיך?';

  @override
  String get settingsBackupImportConfirmButton => 'שחזור';

  @override
  String get settingsBackupExportSuccessMessage => 'הגיבוי נשמר בהצלחה';

  @override
  String get settingsBackupExportErrorMessage => 'אירעה שגיאה בייצוא הגיבוי';

  @override
  String settingsBackupImportSuccessMessage(int created, int updated) {
    return 'השחזור הושלם: $created אירועים חדשים, $updated עודכנו';
  }

  @override
  String get settingsBackupImportErrorMessage => 'אירעה שגיאה בשחזור הגיבוי';

  @override
  String get settingsBackupImportUnsupportedVersionMessage =>
      'קובץ הגיבוי נוצר בגרסה חדשה יותר של האפליקציה ואינו נתמך כאן';

  @override
  String settingsVersionLabel(String version) {
    return 'גרסה $version';
  }

  @override
  String get settingsAboutTooltip => 'אודות';

  @override
  String get aboutScreenTitle => 'אודות';

  @override
  String get aboutTagline => 'היומן שבו התאריך העברי במרכז';

  @override
  String get aboutDeveloperCredit => 'מבית KALFAPP';

  @override
  String get aboutLicensesButton => 'רישיונות קוד פתוח';

  @override
  String get aboutHeading => 'אודות האפליקציה';

  @override
  String get aboutBody =>
      'לוח עברי נועד למי שחי לפי התאריך העברי, כמו ימי הולדת, אזכרות, ימי נישואין וחגים, ורוצה יומן אחד שבו הכל מסודר.\n\nהאפליקציה פשוטה. יוצרים אירוע, בוחרים שהוא חוזר לפי התאריך העברי, והוא יופיע במקום הנכון בכל שנה, גם בשנה מעוברת. החגים והפרשה מופיעים בלוח מעצמם, והכל מסתנכרן עם Google Calendar בשני הכיוונים.\n\nהשימוש באפליקציה הוא על אחריות המשתמש. למרות שאנחנו עושים את המקסימום כדי לשמור על המידע ועל הפרטיות שלכם, זהו פרויקט התנדבותי לחלוטין ולכן אין שום אחריות מכל סוג שהוא לא על תקינות האפליקציה ולא על שמירת הנתונים.\n\nעם זאת, אם יש לך רעיון לשיפור, נשמח לקבל פידבקים ורעיונות לאפליקציות נוספות.';

  @override
  String get aboutSignature => 'בהצלחה!\nנתן-אור.';

  @override
  String get aboutLogoSemantics => 'KALFAPP';

  @override
  String get monthAgendaEmpty => 'אין אירועים ביום זה';

  @override
  String monthAgendaDayHeader(String weekday, String day, String month) {
    return 'יום $weekday, $day $month';
  }

  @override
  String monthAgendaParshaTag(String name) {
    return 'פרשת $name';
  }

  @override
  String get syncProgressStarting => 'מתחיל סנכרון';

  @override
  String get syncProgressDownloading => 'מוריד שינויים מ-Google';

  @override
  String syncProgressApplying(String done, String total) {
    return 'מעדכן ביומן: $done מתוך $total';
  }

  @override
  String syncProgressUploading(String done, String total) {
    return 'שולח ל-Google: $done מתוך $total';
  }

  @override
  String get settingsDarkModeTitle => 'מצב כהה';

  @override
  String get settingsInIsraelTitle => 'לוח ארץ ישראל';

  @override
  String get settingsInIsraelSubtitle =>
      'כבוי: לוח חו״ל (יום טוב שני של גלויות וסדר הפרשות בחו״ל)';

  @override
  String get calendarPullSyncDoneMessage => 'הסנכרון עם Google הושלם';

  @override
  String get calendarPullSyncDisabledMessage =>
      'הסנכרון עם Google כבוי. אפשר להפעיל אותו בהגדרות.';

  @override
  String get calendarPullSyncAlreadyRunningMessage =>
      'סנכרון כבר מתבצע ברגע זה. נסה שוב בעוד רגע.';

  @override
  String get eventEditRecurringChoiceMessage =>
      'אירוע זה הוא חלק מסדרה חוזרת. על מה להחיל את השינוי?';

  @override
  String get eventScopeThisAndFollowing => 'מופע זה והבאים אחריו';

  @override
  String get eventEditorScopeThisOccurrenceNote =>
      'עורך רק את המופע הזה. שאר הסדרה לא תשתנה.';

  @override
  String get eventEditorScopeThisAndFollowingNote =>
      'עורך את המופע הזה ואת כל הבאים אחריו. מופעים קודמים לא ישתנו.';

  @override
  String get eventColorLabel => 'צבע';

  @override
  String get eventColorDefault => 'ברירת מחדל';

  @override
  String eventColorOption(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      '1': 'לבנדר',
      '2': 'מרווה',
      '3': 'ענבים',
      '4': 'פלמינגו',
      '5': 'בננה',
      '6': 'מנדרינה',
      '7': 'טווס',
      '8': 'גרפיט',
      '9': 'אוכמניות',
      '10': 'בזיליקום',
      '11': 'עגבנייה',
      'other': 'צבע',
    });
    return '$_temp0';
  }

  @override
  String get eventAttendeesLabel => 'משתתפים';

  @override
  String get eventAttendeesFieldLabel => 'הוספת משתתף לפי מייל';

  @override
  String get eventAttendeesHelper =>
      'Google Calendar ישלח להם זימון במייל אחרי הסנכרון';

  @override
  String get eventAttendeesInvalid => 'כתובת מייל לא תקינה, או שהיא כבר ברשימה';

  @override
  String get eventAttendeesAdd => 'הוספה';

  @override
  String get attendeeAccepted => 'אישר/ה הגעה';

  @override
  String get attendeeDeclined => 'לא מגיע/ה';

  @override
  String get attendeeTentative => 'אולי';

  @override
  String get attendeeNoReply => 'טרם השיב/ה';

  @override
  String eventAttendeesSummary(int count, int accepted) {
    return '$count משתתפים, $accepted אישרו';
  }

  @override
  String get goToDateTooltip => 'מעבר לתאריך';

  @override
  String get goToHebrewDate => 'דילוג לתאריך עברי';

  @override
  String get goToGregorianDate => 'דילוג לתאריך לועזי';

  @override
  String get searchTooltip => 'חיפוש';

  @override
  String get searchHint => 'חיפוש בכותרת, תיאור או מיקום';

  @override
  String get searchNoResults => 'לא נמצאו אירועים';

  @override
  String get searchRecurringNote => 'חוזר';
}
