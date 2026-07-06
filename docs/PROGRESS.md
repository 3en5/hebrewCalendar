# יומן התקדמות — HebrewCalendar

**שלב נוכחי: M1 הושלם ✅ → הבא: M2 — אימות + CRUD** (ראה אבני דרך ב-ARCHITECTURE.md §9)

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
