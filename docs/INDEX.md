# אינדקס קבצי הפרויקט — HebrewCalendar

**חובה לעדכן קובץ זה בכל הוספה/מחיקה/שינוי תפקיד של קובץ** (RULES.md §3.1).

## תיעוד ומסגרת
| קובץ | תפקיד |
|---|---|
| `CLAUDE.md` | נקודת כניסה לסוכנים: תיאור הפרויקט, סטאק, תקציר כללים |
| `docs/RULES.md` | מערכת הכללים המחייבת (תוכנית, 500 שורות, אבטחה, זיכרון, סוכנים) |
| `docs/ARCHITECTURE.md` | התוכנית המחייבת: שכבות, מודל נתונים, סנכרון, אבני דרך |
| `docs/TESTING_AND_DEPLOY.md` | כללי טסטים, CI ודיפלוי |
| `docs/PROGRESS.md` | יומן התקדמות: מה נעשה, שלב נוכחי, מה הלאה |
| `docs/LESSONS.md` | לקחים ממשימות מוצלחות/מורכבות |
| `docs/WISHLIST.md` | פיצ'רים בהולד — לא לממש בלי אישור |

## קוד (יתמלא עם הפיתוח)
| קובץ | תפקיד |
|---|---|
| `pubspec.yaml` | תלויות הפרויקט (`flutter_localizations`, `intl`, `flutter_riverpod`, `kosher_dart`, `firebase_core`/`firebase_auth`/`cloud_firestore`/`google_sign_in` מ-M2b) והפעלת `generate: true` ל-l10n |
| `l10n.yaml` | קונפיגורציית generation של מחרוזות ה-ARB לקוד Dart |
| `analysis_options.yaml` | קונפיגורציית linter/analyzer מחמירה (strict-casts/inference/raw-types, כללי lint נוספים) |
| `android/settings.gradle.kts` | הצהרת פלאגינים ברמת הפרויקט, כולל `com.google.gms.google-services` (M2b — קורא את `google-services.json`) |
| `android/app/build.gradle.kts` | קונפיגורציית מודול האפליקציה: החלת פלאגין `google-services`, `minSdk=23` (נדרש ע"י `firebase_auth`) |
| `lib/main.dart` | נקודת הכניסה: `Firebase.initializeApp` + הפעלת persistence ל-Firestore (רק כאן — אף טסט לא קורא ל-`main`), `ProviderScope`, `MaterialApp` עם theme, לוקאליזציה ושער האימות (`AuthGate`) |
| `lib/core/theme/dimens.dart` | גודל בסיס יחיד (`kBaseFontSize`) וכל גדלי הטקסט/המרווחים/נקודות השבירה כמכפלות יחסיות ממנו |
| `lib/core/theme/app_theme.dart` | `ThemeData` בהיר/כהה ל-Material 3, seed כחול בהשראת Google Calendar, `TextTheme` הבנוי כולו מ-`dimens.dart` |
| `lib/core/widgets/.gitkeep` | תיקייה שמורה ל-widgets משותפים (טרם קיים תוכן) |
| `lib/domain/hebrew_date/hebrew_date.dart` | ישות טהורה `HebrewDate` (+`HebrewMonth`): שוויון, סדר כרונולוגי, אדר/אדר א׳/אדר ב׳ מפורשים — ללא תלות ב-Flutter/kosher_dart |
| `lib/domain/hebrew_date/hebrew_date_engine.dart` | `HebrewDateEngine`: העטיפה היחידה סביב `kosher_dart` — המרות עברי/לועזי, שנה מעוברת, ימים בחודש, ניווט חודשים (`addMonths`/`nextMonth`/`previousMonth`), שם חודש בעברית |
| `lib/domain/hebrew_date/hebrew_numerals.dart` | פירמוט גימטריה טהור (ללא תלות ב-kosher_dart): יום/שנה לאותיות עבריות עם גרש/גרשיים, כולל ט״ו/ט״ז |
| `lib/domain/event/event.dart` | ישות טהורה `Event`: כל שדות מודל האירוע (ARCHITECTURE.md §4), שוויון וסדר, `copyWith` עם דגלי `clearStartTime`/`clearEndTime` |
| `lib/domain/event/event_time_of_day.dart` | ערך טהור `EventTimeOfDay` (שעה/דקה) — תחליף ל-`TimeOfDay` של Flutter כדי ש-domain לא יתלה ב-Flutter |
| `lib/domain/event/recurrence_rule.dart` | ערך טהור `RecurrenceRule` + `RecurrenceType`: מבנה הנתונים לחזרתיות (הלוגיקה/הרחבה ל-מופעים היא M3) |
| `lib/domain/event/event_validation.dart` | ולידטורים טהורים ל-`Event`: כותרת חובה/אורך מקסימלי, תיאור/מיקום אורך מקסימלי, סיום אחרי התחלה — שגיאות מסוג טיפוסי (`EventValidationErrorType`) |
| `lib/domain/event/event_repository.dart` | ממשק מופשט `EventRepository`: `watchEventsForHebrewMonth` (מחזיר `Stream<List<EventOccurrence>>` מ-M3a), `getById`, `create`, `update`, `delete` — מוגדר על טיפוסי domain בלבד |
| `lib/domain/event/event_occurrence.dart` | `EventOccurrence` (זוג `Event`+תאריך מופע קונקרטי) ו-`compareEventOccurrences` (סדר כרונולוגי משותף ל-repositories) — M3a |
| `lib/domain/event/recurrence_expander.dart` | `occurrencesInRange`/`occurrencesInHebrewMonth`: הרחבת `RecurrenceRule` למופעים קונקרטיים — מדיניות מיפוי אדר ומדיניות יום 30 מתועדות כאן וב-ARCHITECTURE.md §4 (M3a) |
| `lib/data/in_memory_event_repository.dart` | מימוש זיכרון ל-`EventRepository`: ברירת המחדל לפני התחברות ולצמיתות בטסטים; `id`/`now` ניתנים להזרקה, שידור שינויים עמיד מול race של broadcast stream, מרחיב אירועים חוזרים דרך `recurrence_expander.dart` (M3a) |
| `lib/data/event_firestore_mapper.dart` | פונקציות טהורות להמרת `Event` <-> מבנה מסמך Firestore (`events/{eventId}`) וחישוב טווח לועזי לחודש עברי (`hebrewMonthGregorianRange`) — נבדק ביחידה בלי Firestore אמיתי (M2b); כולל שדה `isRecurring` נגזר, write-only (M3a) |
| `lib/data/firestore_event_repository.dart` | מימוש `EventRepository` מול Firestore, מסונן ל-`ownerUid` של המשתמש המחובר; `createdAt`/`updatedAt` נכתבים כ-`serverTimestamp` (M2b); `watchEventsForHebrewMonth` ממזג שאילתת אירועים לא-חוזרים (טווח `gregorianStart`) עם שאילתת כל האירועים החוזרים, ומרחיב את האחרונים ללקוח (M3a) |
| `lib/domain/auth/app_user.dart` | ישות טהורה `AppUser` (uid/displayName/email/photoUrl) — תחליף ל-`User` של Firebase כדי ש-domain יישאר Flutter/Firebase-free (M2b) |
| `lib/domain/auth/auth_repository.dart` | ממשק מופשט `AuthRepository`: `authStateChanges`/`signInWithGoogle`/`signOut`, מוגדר על טיפוסי domain בלבד (M2b) |
| `lib/features/auth/data/auth_repository.dart` | `FirebaseAuthRepository`: עוטף `firebase_auth`+`google_sign_in` (API v7 — `GoogleSignIn.instance.initialize`+`authenticate`), ויוצר/ממזג את מסמך `users/{uid}` בכניסה ראשונה (M2b) |
| `lib/features/auth/application/auth_providers.dart` | Riverpod: `authRepositoryProvider`, `authStateProvider` (`StreamProvider<AppUser?>`), `currentUserProvider` (M2b) |
| `lib/features/auth/presentation/sign_in_screen.dart` | מסך כניסה RTL: שם האפליקציה, כפתור כניסה עם Google, מצב טעינה, שגיאה כ-snackbar (M2b) |
| `lib/features/auth/presentation/auth_gate.dart` | שער האפליקציה: לא מחובר -> `SignInScreen`, מחובר -> `MonthViewScreen`, לפי `authStateProvider` (M2b) |
| `lib/features/calendar/presentation/month_view_screen.dart` | מסך הבית: תצוגת חודש עברי עם `PageView` לדפדוף בין חודשים (+כפתורי חץ RTL-safe), כותרת App Bar בעברית, FAB ליצירת אירוע ביום הנוכחי/1 בחודש המוצג, תפריט overflow עם התנתקות + דיאלוג אישור (M2b) |
| `lib/features/calendar/presentation/widgets/month_grid.dart` | גריד החודש: שורת ימי שבוע (א׳..ש׳), 6 שבועות קבועים, ימי חודשים סמוכים מטושטשים, אינדיקציית מופעים (כולל חוזרים, M3a) לכל יום ופתיחת `DayEventsSheet` בהקשה |
| `lib/features/calendar/presentation/widgets/day_cell.dart` | תא יום בודד: יום עברי בגימטריה (ראשי) + יום לועזי (משני), עיגול מלא ל"היום", נקודת אינדיקציה לאירועים, `onTap` |
| `lib/features/calendar/presentation/widgets/day_events_sheet.dart` | Bottom sheet לרשימת מופעי יום עברי בודד: כותרת+שעה, עריכה (פותחת את עורך האירועים על עוגן הסדרה), מחיקה — אירוע לא-חוזר: דיאלוג אישור בודד; אירוע חוזר: דיאלוג עם "מופע זה בלבד" (חריג) / "כל הסדרה" (מחיקה) (M3a) |
| `lib/features/calendar/application/hebrew_date_engine_provider.dart` | Riverpod `Provider<HebrewDateEngine>` משותף לפיצ'ר היומן |
| `lib/features/calendar/application/displayed_month_provider.dart` | Riverpod `NotifierProvider.autoDispose` המחזיק את החודש העברי המוצג כרגע |
| `lib/features/calendar/application/month_events_provider.dart` | Riverpod `StreamProvider.autoDispose.family<List<EventOccurrence>, HebrewDate>` שמזרים את מופעי החודש העברי המוצג (כולל הרחבת אירועים חוזרים, M3a) |
| `lib/features/event_editor/application/event_repository_provider.dart` | Riverpod `Provider<EventRepository>` — `FirestoreEventRepository` כשמחוברים (לפי `currentUserProvider`), אחרת `InMemoryEventRepository`; ניתן לדריסה בטסטים (M2b) |
| `lib/features/event_editor/application/event_editor_state.dart` | State טהור למסך עורך האירועים: שדות הטופס, `recurrenceType`/`recurrenceUntil`/`recurrenceExceptions` (M3a), שגיאות ולידציה, `isSaving` |
| `lib/features/event_editor/application/event_editor_controller.dart` | Riverpod `NotifierProvider.autoDispose.family` (`EventEditorArgs` — יצירה/עריכה): מוטציות שדות (כולל `setRecurrenceType`/`setRecurrenceUntil`, M3a), ולידציה ושמירה מול ה-repository |
| `lib/features/event_editor/presentation/event_editor_screen.dart` | מסך יצירה/עריכה של אירוע (RTL, בהשראת Google Calendar): כותרת, כל היום, תאריך עברי, שעות, תיאור, מיקום, תזכורת, בורר חזרתיות + "עד תאריך" (M3a), שמירה עם שגיאות inline |
| `lib/features/event_editor/presentation/widgets/hebrew_date_picker_field.dart` | שדה לחיץ המציג את התאריך העברי הנבחר ופותח את `HebrewDatePickerSheet` |
| `lib/features/event_editor/presentation/widgets/hebrew_date_picker_sheet.dart` | Bottom sheet לבחירת תאריך עברי: שלוש רשימות נפתחות (שנה/חודש/יום) בגימטריה, כולל אדר א׳/אדר ב׳ בשנה מעוברת |
| `lib/features/event_editor/presentation/widgets/event_time_section.dart` | שדות שעת התחלה/סיום (מנוטרלים כשהאירוע "כל היום"), עוטף את `showTimePicker` של Flutter וממיר ל-`EventTimeOfDay` |
| `lib/features/event_editor/presentation/widgets/reminder_selector.dart` | בורר צ'יפים לבחירת תזכורת יחידה: ללא/10/30/60 דקות לפני |
| `lib/features/event_editor/presentation/widgets/recurrence_type_selector.dart` | בורר צ'יפים ל-`RecurrenceType`: ללא חזרה/כל שנה (עברי)/כל חודש (עברי)/כל שבוע/כל יום (M3a) |
| `lib/features/event_editor/presentation/widgets/recurrence_until_field.dart` | שדה "עד תאריך" אופציונלי לאירוע חוזר: מציג "ללא תאריך סיום" כברירת מחדל, פותח מחדש את `HebrewDatePickerSheet` הקיים, וכפתור ניקוי (M3a) |
| `lib/features/settings/.gitkeep` | תיקייה שמורה למסך ההגדרות (טרם קיים תוכן) |
| `lib/l10n/app_he.arb` | קובץ המקור (template) של מחרוזות העברית: כותרות, טולטיפים, שדות עורך האירועים, שגיאות ולידציה, בורר תאריך עברי, מסך כניסה/התנתקות (M2b); בורר חזרתיות, שדה "עד תאריך", ודיאלוג מחיקת מופע/סדרה (M3a) |
| `lib/l10n/app_localizations.dart` | קוד מחולל אוטומטית (מ-`app_he.arb`) — אין לערוך ידנית |
| `lib/l10n/app_localizations_he.dart` | קוד מחולל אוטומטית למחרוזות העבריות — אין לערוך ידנית |
| `tool/check_file_length.sh` | סקריפט CI שנכשל אם קובץ `.dart` תחת `lib/`/`test/` עובר 500 שורות |
| `.github/workflows/ci.yml` | Workflow של GitHub Actions: format, analyze, test+coverage, בדיקת אורך קבצים, ובנייה נפרדת של APK debug |
| `firebase.json` | מצביע Firebase CLI אל `firebase/firestore.rules`+`firebase/firestore.indexes.json` (M2b) |
| `.firebaserc` | פרויקט ה-Firebase המקושר כברירת מחדל: `hebrewcalendar-68363` (לא סוד — RULES.md §5.4) (M2b) |
| `firebase/firestore.rules` | Security Rules: `users/{uid}`/`events/{eventId}` נגישים רק לבעלים, ולידציית טיפוסים/אורכים תואמת ל-`event_validation.dart`, חסימת כל השאר (M2b); ולידציית מבנה `recurrence`+`isRecurring` (M3a) |
| `firebase/firestore.indexes.json` | האינדקסים המורכבים הנדרשים לשאילתת `watchEventsForHebrewMonth`: (`ownerUid`,`gregorianStart`) (M2b), (`ownerUid`,`isRecurring`,`gregorianStart`) ו-(`ownerUid`,`isRecurring`) (M3a) |
| `firebase/README.md` | הסבר בעברית איך לפרוס את ה-Rules/אינדקסים (Firebase CLI או הדבקה ידנית בקונסולה) (M2b); הערה על עדכון M3a שטרם פורסם |
| `test/core/theme/dimens_test.dart` | טסט יחידה למתמטיקת ה-rem/spacing ולסיווג נקודות השבירה ב-`dimens.dart` |
| `test/domain/hebrew_date/hebrew_date_test.dart` | טסטים ל-`HebrewDate`: שוויון, סדר כרונולוגי (כולל אדר א׳/אדר ב׳), `copyWith` |
| `test/domain/hebrew_date/hebrew_date_engine_test.dart` | טסטים ל-`HebrewDateEngine`: round-trip, שנים מעוברות, אדר א׳/ב׳, אורך חשוון/כסלו, מעבר שנה, ניווט חודשים |
| `test/domain/hebrew_date/hebrew_numerals_test.dart` | טסטים לפירמוט הגימטריה: 1/15/16/20/30 ופירמוט שנה (5786 -> תשפ״ו) |
| `test/domain/event/event_test.dart` | טסטים ל-`Event`: שוויון (כולל רשימת תזכורות), `copyWith` ודגלי `clearStartTime`/`clearEndTime` |
| `test/domain/event/recurrence_rule_test.dart` | טסטים ל-`RecurrenceRule`: שוויון (כולל רשימת חריגים), `copyWith` ודגל `clearUntil` |
| `test/domain/event/event_validation_test.dart` | טסטים ל-`validateEvent`: כותרת חובה/אורך מקסימלי, תיאור/מיקום אורך מקסימלי, סיום אחרי התחלה, צבירת מספר שגיאות |
| `test/domain/event/event_occurrence_test.dart` | טסטים ל-`EventOccurrence`: שוויון/hashCode, `isRecurring`, וסדר `compareEventOccurrences` (M3a) |
| `test/domain/event/recurrence_expander_yearly_test.dart` | טסטים ל-`RecurrenceType.none`/`hebrewYearly`: מיפוי אדר, מדיניות יום 30, ואין מופע לפני הבסיס (M3a) |
| `test/domain/event/recurrence_expander_monthly_test.dart` | טסטים ל-`RecurrenceType.hebrewMonthly`: מדיניות יום 30 בין כסלו/טבת (בלי כפילות), מופע אחד לכל חודש (M3a) |
| `test/domain/event/recurrence_expander_step_test.dart` | טסטים ל-`RecurrenceType.weekly`/`daily`: מעבר חודש/שנה/אדר מעוברת, קפיצות ימים קבועות (M3a) |
| `test/domain/event/recurrence_expander_shared_test.dart` | טסטים לחוקים המשותפים לכל סוגי החזרתיות: גבול `until` כולל, דילוג `exceptions`, עטיפת `EventOccurrence` (M3a) |
| `test/data/in_memory_event_repository_test.dart` | טסטים ל-`InMemoryEventRepository`: יצירה/עדכון/מחיקה, פליטות של `watchEventsForHebrewMonth` בכל מוטציה, הרחבת אירוע חוזר לחודשים מאוחרים יותר וחריג שמסיר מופע בודד (M3a) |
| `test/data/event_firestore_mapper_test.dart` | טסטים ל-`event_firestore_mapper`: round-trip `Event`<->map לכל חודשי השנה (כולל אדר א׳/ב׳), שעות, תזכורות, חזרתיות, ערכי null, `hebrewMonthGregorianRange` (M2b), ושדה `isRecurring` הנגזר לכל סוגי החזרתיות (M3a) |
| `test/features/calendar/presentation/month_view_screen_test.dart` | טסט widget: RTL, כותרת חודש נכונה לתאריך קבוע, הדגשת "היום", שינוי כותרת בניווט (מחובר דרך `FakeAuthRepository`) |
| `test/features/calendar/presentation/month_view_events_test.dart` | טסט widget: אינדיקציית אירוע ביום אחרי יצירתו, זרימת מחיקה מלאה מה-bottom sheet (מחובר דרך `FakeAuthRepository`) |
| `test/features/calendar/presentation/month_view_recurring_test.dart` | טסט widget: מופע אירוע חוזר חודשי בחודש מאוחר יותר, ומחיקת "מופע זה בלבד" משאירה מופעים אחרים של הסדרה (M3a) |
| `test/features/event_editor/presentation/event_editor_screen_test.dart` | טסט widget: שמירת אירוע תקין ל-repository מוחלף, הצגת שגיאת ולידציה על כותרת ריקה, שמירת אירוע חוזר שבועי עם "עד תאריך" (M3a) |
| `test/features/auth/presentation/auth_gate_test.dart` | טסט widget לשער האימות: לא מחובר -> `SignInScreen`, מחובר -> `MonthViewScreen`, מעבר בין השניים בהתנתקות (M2b) |
| `test/test_support/fake_auth_repository.dart` | `FakeAuthRepository`+`testUser`: test double ל-`AuthRepository` המשותף לכל טסטי ה-widget שצריכים שער אימות מחובר, בלי לגעת ב-Firebase אמיתי (M2b) |
| `test/test_support/recurrence_expander_test_helpers.dart` | עוזרי טסט משותפים ל-`recurrence_expander_*_test.dart`: בניית `Event` חוזר מינימלי וקריאת תאריכי מופע לחודש נתון (M3a) |
