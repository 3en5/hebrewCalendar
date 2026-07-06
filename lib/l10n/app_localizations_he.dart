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
  String get calendarPreviousMonth => 'החודש הקודם';

  @override
  String get calendarNextMonth => 'החודש הבא';

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
  String eventReminderMinutesBefore(int minutes) {
    return '$minutes דקות לפני';
  }

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
  String get hebrewDatePickerYearLabel => 'שנה';

  @override
  String get hebrewDatePickerMonthLabel => 'חודש';

  @override
  String get hebrewDatePickerDayLabel => 'יום';

  @override
  String get hebrewDatePickerConfirm => 'אישור';
}
