# יומן התקדמות — HebrewCalendar

**שלב נוכחי: M3 הושלם במלואו (M3a + M3b) — מנוע חזרתיות עבריים, שילוב
repositories, ותצוגות שבוע/יום/אג'נדה עם מסך בית משותף.** M4 (תזכורות) הבא
בתור. (ראה אבני דרך ב-ARCHITECTURE.md §9)

## 2026-07-06 — M3b הושלם (תצוגות שבוע/יום/אג'נדה + בורר תצוגה) — M3 הושלם במלואו

- מומש ע"י סוכן-משנה (Sonnet) בפיקוח: `flutter analyze` נקי (0 issues), 192
  טסטים עוברים (175 קיימים + 17 חדשים), `dart format --set-exit-if-changed`
  נקי, בדיקת 500 שורות עוברת.
- **Repository:** `EventRepository` קיבל `watchOccurrencesInRange(from, to)`
  — טווח תאריכים עברי שרירותי, לא בהכרח חודש שלם — לצד `watchEventsForHebrewMonth`
  הקיים, שעכשיו מאציל אליו (חודש = הטווח `[1, daysInMonth]`) בשני המימושים
  (`InMemoryEventRepository`, `FirestoreEventRepository`) במקום לשכפל לוגיקה.
  ב-`recurrence_expander.dart` חולצה `occurrencesForEventInRange` (הרחבת
  `RecurrenceRule` למופעים עבור טווח שרירותי, לא רק חודש) ו-`occurrencesInHebrewMonth`
  הפכה לעטיפה דקה סביבה — כך שדף ה-Firestore, ה-repository בזיכרון, וה-domain
  layer כולם משתפים בדיוק את אותה נקודת הרחבה יחידה. ב-Firestore, ה-merge של
  שתי השאילתות (לא-חוזרים לפי `gregorianStart`, וכל החוזרים מורחבים בצד לקוח)
  הוכלל מ"חודש" ל"טווח" בלי לשכפל את לוגיקת ה-`StreamController` הידני.
- **`HebrewDateEngine`** קיבל `addDays`/`startOfWeek` (אריתמטיקת ימים
  מנורמלת ל-UTC כמו ב-`recurrence_expander.dart`, כדי להימנע מבאג יום-קיץ —
  ראה LESSONS.md) לצורך דפדוף תצוגות שבוע/יום.
- **Application:** `calendar_view_provider.dart` (מחליף את
  `displayed_month_provider.dart` שהוסר) מחזיק `CalendarViewType`
  (חודש/שבוע/יום/אג'נדה) + `focusedDate` משותף לכל התצוגות ולבורר התצוגה;
  `range_events_provider.dart` (`StreamProvider.autoDispose.family` על טווח
  תאריכים) משמש תצוגות שבוע/יום/אג'נדה במקום `month_events_provider.dart`
  (שנשאר לתצוגת החודש בלבד).
- **Presentation:** `MonthViewScreen` פוצל ל-`CalendarShellScreen` (App Bar
  + FAB משותפים, גוף מתחלף) ו-`MonthViewBody` (הגריד עצמו, ללא Scaffold
  משלו). נוספו `WeekViewScreen`/`DayViewScreen`/`AgendaViewScreen` וקבוצת
  widgets משותפים: `HourGrid` (גריד 24 שעות גולל, אלגוריתם חלוקה שווה
  לאשכולות אירועים חופפים), `EventBlock`, `CalendarDayHeader` (מצב
  `compact`/`full`), `AllDayEventsRow`, `DayOccurrences` (צורת קלט משותפת).
  דפדוף בין עמודים (חודש/שבוע/יום) עובר דרך `PagedFocusSync` משותף — עיגון
  קבוע + `PageController`, שמתעדכן רק כשהמיקוד משתנה *מחוץ* לתצוגה עצמה
  (כפתור "היום", מעבר בין תצוגות), כדי למנוע לולאת עדכונים.
- **החלטת סטייה:** הוסרו כפתורי החץ הקודם/הבא הישנים של תצוגת החודש ולא
  נוספו חלופה לתצוגות האחרות — הניווט הוא בהחלקה בלבד (+ כפתור "היום"),
  התואם בדיוק את אפליקציית Google Calendar לאנדרואיד עצמה (שגם היא ללא
  כפתורי חץ), ומייתר את הצורך שהמסך המשותף "יגיע" לתוך ה-`PageController`
  הפנימי של איזו תצוגה שמוצגת כרגע.
- **FAB:** במקום הלוגיקה הישנה ("היום אם בחודש המוצג, אחרת ה-1 בחודש"), ה-FAB
  יוצר תמיד אירוע על `focusedDate` הנוכחי — עמוד תצוגת החודש שומר את יום
  החודש המדויק דרך ניווח חודשים (`addMonths` כבר שומר על יום-בחודש, מהודק
  לפי אורך החודש), כך שההתנהגות בפועל דומה מאוד לישנה בלי טיפול מיוחד.
- **טסטים:** `test/domain/hebrew_date/hebrew_date_engine_test.dart` קיבל
  קבוצות ל-`addDays`/`startOfWeek`; `recurrence_expander_shared_test.dart`
  קיבל טסטים ל-`occurrencesForEventInRange` (טווח שחוצה גבול חודש, וזהות
  עם `occurrencesInHebrewMonth`); `in_memory_event_repository_test.dart`
  קיבל קבוצת `watchOccurrencesInRange` (טווח חוצה חודשים, הרחבת חזרתיות עם
  חריגים, האצלה מ-`watchEventsForHebrewMonth`). טסטי widget חדשים:
  `calendar_shell_screen_test.dart` (בורר תצוגה, כפתור "היום"),
  `week_view_screen_test.dart` (בלוק אירוע תחת יום השבוע הנכון — נבדק
  גיאומטרית, לא רק טקסט), `day_view_screen_test.dart` (רק אירועי היום
  הממוקד), `agenda_view_screen_test.dart` (קיבוץ לפי תאריך + מצב ריק).
  `month_view_screen_test.dart` שונה שם ל-`month_view_body_test.dart`
  ותוכנו הותאם ל-`calendar_view_provider`; `month_view_events_test.dart`/
  `month_view_recurring_test.dart`/`auth_gate_test.dart` הותאמו לאותו שינוי
  ול-`CalendarShellScreen`.

## 2026-07-06 — M3a הושלם (מנוע חזרתיות עבריים)

- מומש ע"י סוכן-משנה (Sonnet) בפיקוח: `flutter analyze` נקי (0 issues), 175
  טסטים עוברים (132 קיימים + 43 חדשים), `dart format --set-exit-if-changed`
  נקי, בדיקת 500 שורות עוברת, כיסוי `lib/domain` בפועל 96.0% (מעל סף ה-90%).
- נוצר `lib/domain/event/recurrence_expander.dart`: פונקציות טהורות
  `occurrencesInRange`/`occurrencesInHebrewMonth` שמרחיבות `RecurrenceRule`
  למופעים קונקרטיים, ללא תלות ב-Flutter/Firebase (רק ב-`HebrewDateEngine`
  הפנימי לדומיין). שתי מדיניות תועדו הן בקוד והן ב-`ARCHITECTURE.md` §4:
  מיפוי אדר (`hebrewYearly` — בסיס אדר/אדר א׳ חוזר באדר א׳ בשנה מעוברת,
  בסיס אדר ב׳ חוזר באדר ב׳ בשנה מעוברת, שניהם חוזרים לאדר רגיל בשנה לא
  מעוברת) ומדיניות יום 30 (`hebrewYearly`/`hebrewMonthly` — יום 30 נופל על
  29 בחודש קצר, בלי כפילות). `weekly`/`daily` מחושבים באריתמטיקת ימים
  לועזיים דרך `HebrewDateEngine`, מנורמלת ל-UTC כדי להימנע מבאג "יום קיץ"
  ב-`DateTime` מקומי (ראה LESSONS.md).
- נוצר `lib/domain/event/event_occurrence.dart`: `EventOccurrence` (זוג
  `Event`+תאריך מופע קונקרטי) ו-`compareEventOccurrences` (סדר כרונולוגי
  משותף ל-repositories). `EventRepository.watchEventsForHebrewMonth` שונה
  מ-`Stream<List<Event>>` ל-`Stream<List<EventOccurrence>>` בכל המימושים
  וקריאות ה-UI (providers, `MonthGrid`, `DayEventsSheet`).
- `InMemoryEventRepository`/`FirestoreEventRepository` משתמשות באותה לוגיקת
  הרחבה (`occurrencesInHebrewMonth`). ב-Firestore: שתי שאילתות ממוזגות
  ידנית (event לא-חוזר לפי טווח `gregorianStart`+`isRecurring==false`, וכל
  האירועים החוזרים של המשתמש `isRecurring==true` ללא סינון תאריך, מורחבים
  בצד הלקוח לחודש המבוקש) — שילוב ידני עם `StreamController.broadcast`
  שממתין לפליטה ראשונה משני המקורות לפני שהוא פולט תוצאה ממוזגת.
- `lib/data/event_firestore_mapper.dart`: נוסף שדה `isRecurring` (bool,
  נגזר מ-`recurrence.type`, write-only — לא נקרא בחזרה, ה-`recurrence`
  המלא הוא מקור האמת). `firebase/firestore.rules` עודכן לוולידציית מבנה
  `recurrence` (type/until/exceptions) ו-`isRecurring`; `firestore.indexes.json`
  קיבל שני אינדקסים מורכבים חדשים (`ownerUid`+`isRecurring`,
  `ownerUid`+`isRecurring`+`gregorianStart`). **הרולז/אינדקסים המעודכנים
  טרם פורסמו** — ראה `firebase/README.md`.
- עורך האירועים (`event_editor_screen.dart`) קיבל בורר חזרתיות
  (`RecurrenceTypeSelector` — צ'יפים ללא חזרה/כל שנה/כל חודש/כל שבוע/כל
  יום) ושדה "עד תאריך" אופציונלי (`RecurrenceUntilField`, שמשתמש מחדש
  ב-`HebrewDatePickerSheet` הקיים). עריכת אירוע חוזר קיימת עורכת את הסדרה
  כולה (משנה את מסמך הבסיס; המופעים מחושבים מחדש אוטומטית).
- `DayEventsSheet`: מחיקת מופע חוזר פותחת דיאלוג עם שלוש אפשרויות —
  ביטול / "מופע זה בלבד" (מוסיף את תאריך המופע ל-`recurrence.exceptions`
  ומעדכן את האירוע) / "כל הסדרה" (מוחק את האירוע). אירוע לא-חוזר ממשיך
  להשתמש בדיאלוג אישור בודד כמו קודם.
- טסטים: `test/domain/event/recurrence_expander_{yearly,monthly,step,shared}_test.dart`
  (פוצל מקובץ אחד שחרג מ-500 שורות) מכסים את כל סוגי החזרתיות, שתי
  המדיניות, גבול `until` כולל, דילוג `exceptions`, ואין מופע לפני הבסיס.
  `test/domain/event/event_occurrence_test.dart` מכסה שוויון/סדר. טסטי
  repository/mapper/widget עודכנו לטיפוס `EventOccurrence` החדש ולשדה
  `isRecurring`; נוסף `test/features/calendar/presentation/month_view_recurring_test.dart`
  (מופע בחודש מאוחר יותר, מחיקת "מופע זה בלבד" משאירה מופעים אחרים).
- **דורש פעולת משתמש:** פריסת ה-Security Rules/אינדקסים המעודכנים
  (`firebase deploy --only firestore:rules,firestore:indexes`) — עד אז
  Firestore האמיתי לא מכיר את `isRecurring`/מבנה ה-`recurrence` המורחב.

## 2026-07-06 — M2b הושלם (חצי שני של M2, חיווט Firebase)

- מומש ע"י סוכן-משנה (Sonnet) בפיקוח: `flutter analyze` נקי (0 issues), 132
  טסטים עוברים (105 קיימים + 27 חדשים), `dart format --set-exit-if-changed`
  נקי, בדיקת 500 שורות עוברת.
- תלויות חדשות (נבחרו ע"י `flutter pub add` — גרסאות עדכניות עקביות זו עם
  זו): `firebase_core: ^4.11.0`, `firebase_auth: ^6.5.4`,
  `cloud_firestore: ^6.6.0`, `google_sign_in: ^7.2.0`. **`google_sign_in`
  7.x הוא API שנכתב מחדש** (ראה LESSONS.md) לעומת המדריכים המוכרים מגרסה 6.
- Gradle: `com.google.gms.google-services` (4.4.2) נוסף ב-
  `android/settings.gradle.kts` (apply false) ומוחל ב-
  `android/app/build.gradle.kts`; `minSdk` הועלה ל-23 (`firebase_auth`
  מצהיר על כך במפורש). אין `firebase_options.dart` — Android קורא
  `google-services.json` באופן טבעי דרך הפלאגין.
- נוצר `lib/domain/auth/` (`AppUser`, `AuthRepository` מופשט — טהורים,
  ללא Firebase/Flutter) ו-`lib/features/auth/` (`FirebaseAuthRepository`,
  `authProviders`, `SignInScreen`, `AuthGate`). שער האימות ב-`main.dart`
  מחליף בין `SignInScreen`/`MonthViewScreen`; פעולת התנתקות עם דיאלוג אישור
  נוספה לתפריט ה-overflow של `MonthViewScreen`. מסמך `users/{uid}`
  נוצר/ממוזג מתוך ה-repository (לא מ-widget) בכניסה ראשונה.
- נוצר `lib/data/firestore_event_repository.dart` (+`event_firestore_mapper.dart`
  הטהור, הנבדק ביחידה בלי Firestore אמיתי): שאילתה לפי `ownerUid`+טווח
  `gregorianStart` הנגזר מ-`HebrewDateEngine`; `createdAt`/`updatedAt`
  נכתבים כ-`FieldValue.serverTimestamp()` בשרת, והאובייקט המוחזר משתמש
  בקירוב מקומי (`DateTime.now()`) עד שהערך האמיתי מסונכרן חזרה — ראה
  LESSONS.md לגבי ה-gotcha של השוואת `DateTime` אחרי round-trip דרך
  `Timestamp`. persistence לא-מקוון הופעל במפורש ב-`main.dart`.
- `eventRepositoryProvider` עבר ל-`FirestoreEventRepository` כשמחוברים
  (לפי `currentUserProvider`), אחרת `InMemoryEventRepository` (הנשאר קבוע
  לטסטים). כל 105 הטסטים הקיימים תוקנו עם `FakeAuthRepository`/override
  ל-`eventRepositoryProvider` כדי לעבור את שער האימות החדש בלי לגעת ב-
  Firebase אמיתי; נוספו טסטים לשער האימות עצמו ולממפה ה-Firestore.
- נוצר `firebase/firestore.rules`+`firebase/firestore.indexes.json`+
  `firebase.json`+`.firebaserc` (פרויקט `hebrewcalendar-68363`) +
  `firebase/README.md` (עברית, הוראות פריסה). **הרולז טרם פורסמו בפועל** —
  ראה "נותר" למטה.

### נותר / דורש פעולת משתמש
- [ ] פריסת ה-Security Rules בפועל (`firebase deploy --only
      firestore:rules,firestore:indexes` או הדבקה ידנית בקונסולה —
      ראה `firebase/README.md`). עד אז Firestore חוסם הכול כברירת מחדל.
- [ ] **לא ניתן היה להריץ `flutter build apk --debug` בסביבת הפיתוח
      הנוכחית**: אין Android SDK מותקן, ולא ניתן להתקינו/למשוך ממנו
      תלויות Gradle (AGP, פלאגין `google-services`, ה-AAR-ים של Firebase)
      כי `dl.google.com`/`maven.google.com` חסומים ע"י ה-proxy של הסביבה
      (אושר: `CONNECT` מוחזר 403 policy denial). אומת כל השאר (format,
      analyze, 132 טסטים, אורך קבצים); ה-job `build-apk` הקיים ב-CI
      (`.github/workflows/ci.yml`, שרץ על ubuntu-latest עם Android SDK
      מותקן מראש) אמור לתפוס כל בעיית Gradle אמיתית בפעם הראשונה שהוא ירוץ
      עם השינויים האלה — יש לעקוב אחריו.
- [ ] אימות Rules מול Firebase Emulator Suite (TESTING_AND_DEPLOY.md §"פירמידה")
      לא בוצע כאן מאותה סיבת רשת; מומלץ להריץ לפני production.

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
