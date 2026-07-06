# יומן התקדמות — HebrewCalendar

**שלב נוכחי: M2 מפוצל לשני חצאים — M2a (מודל אירועים + CRUD בזיכרון) הושלם ✅;
M2b (חיווט Firebase: Auth, Firestore, Rules) ממתין לקונפיגורציית Firebase
מהמשתמש.** (ראה אבני דרך ב-ARCHITECTURE.md §9)

## 2026-07-06 — M2a הושלם (חצי ראשון של M2, ללא תלות ב-Firebase)
- מומש ע"י סוכן-משנה (Sonnet) בפיקוח: `flutter analyze` נקי (0 issues),
  98 טסטים עוברים, `dart format --set-exit-if-changed` נקי, בדיקת 500 שורות עוברת.
- החלטת פיצול: M2 המקורי (אימות + CRUD) פוצל ל-M2a (מודל הדומיין + CRUD מול
  repository בזיכרון, ללא Firebase) ו-M2b (Google Sign-In, Firestore, Security
  Rules) — M2b ימומש לאחר שהמשתמש יספק קונפיגורציית Firebase. שום תלות ב-
  Firebase לא נוספה בשלב זה.
- נוצר `lib/domain/event/`: ישות טהורה `Event` (כולל `EventTimeOfDay` —
  תחליף Flutter-free ל-`TimeOfDay`), `RecurrenceRule`/`RecurrenceType` (מבנה
  נתונים בלבד; הרחבת חזרתיות היא M3), `event_validation.dart` (ולידטורים
  טהורים עם שגיאות טיפוסיות שישוכפלו ב-Security Rules ב-M2b), וממשק מופשט
  `EventRepository`.
- נוצר `lib/data/in_memory_event_repository.dart`: המימוש היחיד עד M2b
  ולצמיתות בטסטים; `id`/`now` ניתנים להזרקה לדטרמיניזם בטסטים. ראה
  `docs/LESSONS.md` לגבי מלכודת timing עם broadcast stream שהתגלתה תוך כדי
  כתיבת הטסטים ותוקנה במימוש.
- נוצר `lib/features/event_editor/`: מסך יצירה/עריכת אירוע RTL בהשראת
  Google Calendar — כותרת, מתג "כל היום", בורר תאריך עברי (שלוש רשימות
  נפתחות בגימטריה, כולל אדר א׳/אדר ב׳ בשנה מעוברת), שעות התחלה/סיום דרך
  `showTimePicker` הרגיל של Flutter (מומר מיד ל-`EventTimeOfDay` כדי
  שה-domain יישאר Flutter-free), תיאור, מיקום, תזכורת יחידה (ללא/10/30/60
  דקות — M2a; ריבוי תזכורות אפשרי בעתיד בלי שינוי סכימה). Riverpod:
  `eventRepositoryProvider` (לא autoDispose — זהו מאגר נתונים, לא state של
  מסך) ו-`eventEditorControllerProvider` (autoDispose.family לפי
  `EventEditorArgs`). כל ה-`TextEditingController`ים מנוקים ב-`dispose`.
- שולבה תצוגת החודש עם אירועים: FAB ליצירת אירוע (ליום הנוכחי אם הוא
  בחודש המוצג, אחרת ל-1 בחודש), נקודת אינדיקציה בתא יום עם אירועים (לא
  צ'יפים — תא הגריד קטן מדי עבורם), הקשה על יום עם אירועים פותחת
  `DayEventsSheet` עם עריכה/מחיקה (כולל דיאלוג אישור).
- הוכרעה סטייה קטנה מהניסוח המקורי: אינדיקציית האירועים בגריד היא נקודה
  אחת ולא עד שני צ'יפים — תא היום קיים מ-M1 קטן מדי לצ'יפים קריאים; המשימה
  אפשרה זאת במפורש ("whichever fits cell size").

## 2026-07-06 — M1 הושלם
- מומש ע"י סוכן-משנה (Sonnet) בפיקוח: `flutter analyze` נקי (0 issues),
  52 טסטים עוברים, `dart format --set-exit-if-changed` נקי, בדיקת 500 שורות עוברת,
  כיסוי `lib/domain` בפועל 99-100% (מעל סף ה-90% הנדרש).
- נוספה תלות `kosher_dart` (2.0.18) — ראה `docs/LESSONS.md` לגבי כמה
  אי-דיוקים ב-API שלה (מספור חודשים, `getGregorianMonth()` שהתנהגותו
  בפועל שונה מהתיעוד, וכו').
- נוצר `lib/domain/hebrew_date/`: `HebrewDate`/`HebrewMonth` (ישות טהורה
  עם אדר/אדר א׳/אדר ב׳ מפורשים), `HebrewDateEngine` (העטיפה היחידה סביב
  kosher_dart: המרות, שנה מעוברת, ימים בחודש, ניווט חודשים), ו-
  `hebrew_numerals.dart` (גימטריה טהורה, כולל ט״ו/ט״ז).
- נוצר `lib/features/calendar/`: `MonthViewScreen` (מסך בית חדש, `PageView`
  RTL-safe לדפדוף בין חודשים), `MonthGrid`/`DayCell` (גריד חודש בסגנון
  Google Calendar, שבוע מתחיל ביום ראשון, "היום" מודגש), ו-state דרך
  Riverpod (`hebrewDateEngineProvider`, `displayedMonthProvider` עם
  `autoDispose`).
- הוסר `placeholder_home_screen.dart` (M0) ומחרוזות ה-ARB הזמניות שלו;
  נוספו טולטיפים לניווט חודשים.

## 2026-07-06 — M0 הושלם
- מומש ע"י סוכן-משנה (Sonnet) בפיקוח, אומת ע"י המפקח: `flutter analyze` נקי,
  10 טסטים עוברים, `dart format` נקי, בדיקת 500 שורות עוברת.
- נוצרו: מבנה תיקיות מלא, `dimens.dart` (rem + spacing + breakpoints),
  `app_theme.dart` (Material 3 בהיר/כהה), l10n עברית (ARB), מסך בית זמני RTL,
  `analysis_options.yaml` מחמיר, `tool/check_file_length.sh`, CI ב-GitHub Actions.
- הערה: יש לאמת שה-CI ירוק בריצה הראשונה ב-GitHub.

## 2026-07-06 — הקמת הפרויקט
- הריפו נוקה מהפרויקט הקודם (כולל היסטוריית git) ואותחל מחדש; הריפו נקרא כעת `hebrewcalendar`.
- התקבלו החלטות יסוד מהמשתמש: Flutter, Firebase, סנכרון גוגל דו-כיווני מלא,
  תוכן דתי (חגים/זמנים/פרשה) נדחה ל-WISHLIST — הליבה היא יומן על בסיס תאריך עברי
  כולל אירועים חוזרים עבריים.
- נוצרה מסגרת העבודה: CLAUDE.md, RULES, ARCHITECTURE, TESTING_AND_DEPLOY, INDEX, LESSONS, WISHLIST.
- Flutter 3.32.5 הותקן בסביבת הפיתוח (`/opt/flutter`).

### נותר ב-M0
- [ ] `flutter create` + מבנה תיקיות לפי ARCHITECTURE §3
- [ ] theme + dimens (גודל בסיס יחיד, הכל יחסי)
- [ ] analysis_options מחמיר, סקריפט בדיקת 500 שורות
- [ ] CI ב-GitHub Actions
- [ ] טסט ראשון עובר
