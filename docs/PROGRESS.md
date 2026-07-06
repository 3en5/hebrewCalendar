# יומן התקדמות — HebrewCalendar

**שלב נוכחי: M0 הושלם ✅ → הבא: M1 — מנוע עברי + תצוגת חודש** (ראה אבני דרך ב-ARCHITECTURE.md §9)

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
