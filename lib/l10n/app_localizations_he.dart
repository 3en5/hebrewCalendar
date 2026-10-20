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
  String get editorSheetDone => 'סיום';

  @override
  String get eventRemindersSheetTitle => 'תזכורות';

  @override
  String get eventReminderCustom => 'מותאם אישית';

  @override
  String eventReminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours שעות לפני',
      two: 'שעתיים לפני',
      one: 'שעה לפני',
    );
    return '$_temp0';
  }

  @override
  String eventReminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ימים לפני',
      two: 'יומיים לפני',
      one: 'יום לפני',
    );
    return '$_temp0';
  }

  @override
  String eventReminderWeeksBefore(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks שבועות לפני',
      two: 'שבועיים לפני',
      one: 'שבוע לפני',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderUnitMinutes => 'דקות לפני';

  @override
  String get eventReminderUnitHours => 'שעות לפני';

  @override
  String get eventReminderUnitDays => 'ימים לפני';

  @override
  String get eventReminderUnitWeeks => 'שבועות לפני';

  @override
  String get eventTitleHint => 'הוספת כותרת';

  @override
  String eventColorRow(String name) {
    return 'צבע: $name';
  }

  @override
  String get locationOpenInMaps => 'פתח ב-Google Maps';

  @override
  String get locationNavigateWaze => 'נווט עם Waze';

  @override
  String get locationOpenFailed => 'לא הצלחתי לפתוח את המפה';

  @override
  String get zmanAlos => 'עלות השחר';

  @override
  String get zmanSunrise => 'זריחה';

  @override
  String get zmanShmaMga => 'סוף זמן ק״ש (מג״א)';

  @override
  String get zmanShmaGra => 'סוף זמן ק״ש (גר״א)';

  @override
  String get zmanTfilaGra => 'סוף זמן תפילה (גר״א)';

  @override
  String get zmanChatzos => 'חצות';

  @override
  String get zmanMinchaGedola => 'מנחה גדולה';

  @override
  String get zmanMinchaKetana => 'מנחה קטנה';

  @override
  String get zmanPlag => 'פלג המנחה';

  @override
  String get zmanSunset => 'שקיעה';

  @override
  String get zmanTzais => 'צאת הכוכבים';

  @override
  String get zmanCandleLighting => 'הדלקת נרות';

  @override
  String get zmanHavdalah => 'צאת שבת';

  @override
  String zmanimPanelTitle(String place) {
    return 'זמני היום · $place';
  }

  @override
  String get zmanimDevicePosition => 'המיקום שלי';

  @override
  String get zmanimSettingsTitle => 'זמני היום';

  @override
  String get zmanimCity => 'עיר';

  @override
  String get zmanimUseDevice => 'מיקום מהטלפון';

  @override
  String get zmanimUseDeviceSubtitle => 'במקום עיר קבועה';

  @override
  String get zmanimUseDeviceFailed =>
      'לא הצלחתי לקבל את המיקום. אפשר לאשר הרשאת מיקום או לבחור עיר.';

  @override
  String get zmanimCandleSetting => 'הדלקת נרות';

  @override
  String zmanimCandleMinutes(int minutes) {
    return '$minutes דקות לפני השקיעה';
  }

  @override
  String zmanimCandleCityCustom(int minutes) {
    return 'לפי מנהג העיר ($minutes דקות)';
  }

  @override
  String get zmanimHavdalahSetting => 'צאת שבת';

  @override
  String get zmanimHavdalahDegrees => 'צאת הכוכבים (8.5° מתחת לאופק)';

  @override
  String get zmanimHavdalah72 => '72 דקות אחרי השקיעה (ר״ת)';

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
  String get recurrenceTypeGregorianYearly => 'כל שנה (לועזי)';

  @override
  String get recurrenceTypeGregorianMonthly => 'כל חודש (לועזי)';

  @override
  String get calendarDisplayHebrew => 'תצוגה עברית';

  @override
  String get calendarDisplayGregorian => 'תצוגה לועזית';

  @override
  String get calendarDisplayTooltip => 'החלפה בין תצוגה עברית ללועזית';

  @override
  String get settingsGregorianDisplaySubtitle =>
      'חודשים לועזיים, התאריך העברי בקטן';

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
  String get settingsBackupExportButton => 'ייצוא';

  @override
  String get settingsBackupShareTooltip => 'שיתוף קובץ הגיבוי';

  @override
  String get settingsBackupImportButton => 'שחזור';

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
  String get monthAgendaNextEvent => 'האירוע הבא';

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
  String eventAttendeesSummaryOne(int accepted) {
    String _temp0 = intl.Intl.pluralLogic(
      accepted,
      locale: localeName,
      other: 'משתתף אחד, אישר/ה',
      zero: 'משתתף אחד, טרם השיב/ה',
    );
    return '$_temp0';
  }

  @override
  String eventAttendeesSummary(int count, int accepted) {
    String _temp0 = intl.Intl.pluralLogic(
      accepted,
      locale: localeName,
      other: '$count משתתפים, $accepted אישרו',
      one: '$count משתתפים, אחד אישר/ה',
      zero: '$count משתתפים, טרם אישרו',
    );
    return '$_temp0';
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

  @override
  String get addMenuNewEvent => 'אירוע עברי חדש';

  @override
  String get addMenuNewEventHint => 'פגישה, תזכורת או אירוע חוזר';

  @override
  String get addMenuSignificantDate => 'מתאריך לועזי לעברי';

  @override
  String get addMenuSignificantDateHint =>
      'יום הולדת, יארצייט, יום נישואין: אירוע שנתי עברי מתאריך לועזי';

  @override
  String get significantTitle => 'מתאריך לועזי לעברי';

  @override
  String get significantKindBirthday => 'יום הולדת';

  @override
  String get significantKindYahrzeit => 'יארצייט';

  @override
  String get significantKindAnniversary => 'יום נישואין';

  @override
  String get significantKindOther => 'אחר';

  @override
  String get significantNameLabel => 'שם';

  @override
  String get significantNameHintOther => 'למשל: עלייה לארץ';

  @override
  String get significantDateLabel => 'התאריך הלועזי המקורי';

  @override
  String get significantDatePick => 'בחירת תאריך';

  @override
  String get significantSunsetLabel => 'מתי ביום?';

  @override
  String get significantSunsetBefore => 'לפני השקיעה';

  @override
  String get significantSunsetAfter => 'אחרי השקיעה';

  @override
  String get significantSunsetUnknown => 'לא יודע';

  @override
  String significantPreviewWas(String gregorian, String hebrew) {
    return '$gregorian היה $hebrew.';
  }

  @override
  String significantPreviewNext(String hebrew, String gregorian) {
    return 'השנה יחול ב-$hebrew, $gregorian.';
  }

  @override
  String get significantAdarNote => 'בשנה מעוברת: באדר א׳.';

  @override
  String get significantAlsoGregorian => 'להוסיף גם את התאריך הלועזי';

  @override
  String get significantSave => 'יצירת אירוע';

  @override
  String significantSaved(String title) {
    return 'נוצר: $title';
  }

  @override
  String significantTitleBirthdayHebrew(String name) {
    return 'יום הולדת עברי – $name';
  }

  @override
  String significantTitleBirthdayGregorian(String name) {
    return 'יום הולדת – $name';
  }

  @override
  String significantTitleYahrzeitHebrew(String name) {
    return 'יארצייט – $name';
  }

  @override
  String significantTitleYahrzeitGregorian(String name) {
    return 'יום פטירה (לועזי) – $name';
  }

  @override
  String significantTitleAnniversaryHebrew(String name) {
    return 'יום נישואין עברי – $name';
  }

  @override
  String significantTitleAnniversaryGregorian(String name) {
    return 'יום נישואין – $name';
  }

  @override
  String significantTitleOtherHebrew(String name) {
    return '$name (עברי)';
  }

  @override
  String significantTitleOtherGregorian(String name) {
    return '$name (לועזי)';
  }

  @override
  String get significantDayLabel => 'יום';

  @override
  String get significantMonthLabel => 'חודש';

  @override
  String get significantYearLabel => 'שנה';

  @override
  String get settingsBackupShareButton => 'שיתוף';

  @override
  String get linkCall => 'חיוג';

  @override
  String get linkWhatsApp => 'וואטסאפ';

  @override
  String get linkSendEmail => 'שליחת מייל';

  @override
  String get linkCopy => 'העתקה';

  @override
  String get linkCopied => 'הועתק';

  @override
  String get linkOpenFailed => 'לא ניתן לפתוח';

  @override
  String get settingsTextSizeTitle => 'גודל טקסט';

  @override
  String get settingsTextSizeSubtitle => 'בנוסף לגודל הגופן שבהגדרות הטלפון';

  @override
  String settingsTextSizePercent(int percent) {
    return '$percent%';
  }

  @override
  String get aboutPrivacyPolicy => 'מדיניות פרטיות';

  @override
  String get aboutTermsOfUse => 'תנאי שימוש';

  @override
  String get settingsUserGuide => 'מדריך למשתמש';

  @override
  String get settingsUserGuideSubtitle =>
      'כל מה שאפשר לעשות באפליקציה, צעד אחר צעד';

  @override
  String get settingsRateApp => 'דירוג האפליקציה';

  @override
  String get settingsRateAppSubtitle => 'אהבת? נשמח לדירוג ב-Google Play';

  @override
  String get dailyHalachaTitle => 'הלכה יומית';

  @override
  String get dailyHalachaBook => 'קיצור שולחן ערוך';

  @override
  String dailyHalachaSiman(String n) {
    return 'סימן $n';
  }

  @override
  String dailyHalachaSeif(String n) {
    return 'סעיף $n';
  }

  @override
  String get dailyHalachaSource =>
      'מקור: קיצור שולחן ערוך, מהדורת תורת אמת (נחלת הכלל). לוח הלימוד: קיצור שולחן ערוך יומי, מחזור שנתי.';

  @override
  String get dailyHalachaLearned => 'שיננתי';

  @override
  String get dailyHalachaLearnedKeep => 'שיננתי, תמשיך להציג לי';

  @override
  String get dailyHalachaStop => 'אל תציג לי יותר';

  @override
  String get dailyHalachaSettingTitle => 'הצגה בכניסה הראשונה ביום';

  @override
  String dailyHalachaSettingShare(String percent) {
    return '$percent% לומדים כל יום';
  }

  @override
  String get dailyHalachaSettingSubtitle => 'קיצור שולחן ערוך, מסיימים בכל שנה';

  @override
  String get dailyHalachaOpenToday => 'ההלכה של היום';

  @override
  String get dailyHalachaUnavailable =>
      'ההלכה של היום עדיין לא ירדה. נסו שוב כשיש חיבור לאינטרנט.';

  @override
  String get dailyLearningTitle => 'לימוד יומי';

  @override
  String get dailyLearningIntro =>
      'מה יופיע בחלון הלימוד כשפותחים את האפליקציה בבוקר.';

  @override
  String get dailyLearningOff => 'כבוי';

  @override
  String get dailyLearningTabHalacha => 'הלכה';

  @override
  String get dailyLearningTabParsha => 'פרשה';

  @override
  String get parshaSection => 'פרשת השבוע';

  @override
  String get parshaSwitch => 'לימוד הפרשה';

  @override
  String get parshaSwitchHint => 'עלייה אחת ביום, ראשון עד שבת';

  @override
  String get parshaModeTargum => 'שניים מקרא ואחד תרגום';

  @override
  String get parshaModeTargumHint => 'כל פסוק פעמיים, ותרגום אונקלוס';

  @override
  String get parshaModeTargumRashi => 'שניים מקרא, תרגום ורש״י';

  @override
  String get parshaModeTargumRashiHint => 'כמו הקודם, ופירוש רש״י מתחת לפסוק';

  @override
  String get parshaModeChumashRashi => 'חומש עם רש״י';

  @override
  String get parshaModeChumashRashiHint => 'הפסוק פעם אחת, ופירוש רש״י מתחתיו';

  @override
  String get parshaCalendarIsrael =>
      'הפרשות לפי לוח ארץ ישראל (מתוך ההגדרות הכלליות).';

  @override
  String get parshaCalendarDiaspora =>
      'הפרשות לפי לוח חו״ל (מתוך ההגדרות הכלליות).';

  @override
  String get parshaOpenToday => 'הפרשה של היום';

  @override
  String get parshaUnavailable =>
      'הפרשה של היום עדיין לא ירדה. נסו שוב כשיש חיבור לאינטרנט.';

  @override
  String get parshaTwiceNote =>
      'כל פסוק קוראים פעמיים, ואחריו את התרגום פעם אחת.';

  @override
  String get parshaTwiceTag => 'פעמיים';

  @override
  String get parshaTargumTag => 'ת״א';

  @override
  String get parshaRashiTag => 'רש״י';

  @override
  String get parshaDone => 'סיימתי';

  @override
  String get parshaSourceTargum =>
      'מקרא על פי המסורה (CC-BY-SA) · תרגום אונקלוס, תורת אמת (נחלת הכלל)';

  @override
  String get parshaSourceTargumRashi =>
      'מקרא על פי המסורה (CC-BY-SA) · אונקלוס, תורת אמת · רש״י, מהדורת רוזנבאום-זילברמן (נחלת הכלל)';

  @override
  String get parshaSourceRashi =>
      'מקרא על פי המסורה (CC-BY-SA) · רש״י, מהדורת רוזנבאום-זילברמן (נחלת הכלל)';

  @override
  String parshaMeta(String parsha, String aliyah, String range, String date) {
    return 'פרשת $parsha · $aliyah · $range · $date';
  }

  @override
  String parshaAliyah(String n) {
    String _temp0 = intl.Intl.selectLogic(n, {
      '1': 'ראשון',
      '2': 'שני',
      '3': 'שלישי',
      '4': 'רביעי',
      '5': 'חמישי',
      '6': 'שישי',
      'other': 'שביעי',
    });
    return '$_temp0';
  }

  @override
  String dailyLearningSummaryParsha(String mode) {
    return 'פרשת השבוע ($mode)';
  }
}
