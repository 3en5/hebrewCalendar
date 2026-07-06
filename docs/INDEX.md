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
| `pubspec.yaml` | תלויות הפרויקט (`flutter_localizations`, `intl`, `flutter_riverpod`, `kosher_dart`) והפעלת `generate: true` ל-l10n |
| `l10n.yaml` | קונפיגורציית generation של מחרוזות ה-ARB לקוד Dart |
| `analysis_options.yaml` | קונפיגורציית linter/analyzer מחמירה (strict-casts/inference/raw-types, כללי lint נוספים) |
| `lib/main.dart` | נקודת הכניסה: `ProviderScope`, `MaterialApp` עם theme, לוקאליזציה ומסך הבית (`MonthViewScreen`) |
| `lib/core/theme/dimens.dart` | גודל בסיס יחיד (`kBaseFontSize`) וכל גדלי הטקסט/המרווחים/נקודות השבירה כמכפלות יחסיות ממנו |
| `lib/core/theme/app_theme.dart` | `ThemeData` בהיר/כהה ל-Material 3, seed כחול בהשראת Google Calendar, `TextTheme` הבנוי כולו מ-`dimens.dart` |
| `lib/core/widgets/.gitkeep` | תיקייה שמורה ל-widgets משותפים (טרם קיים תוכן) |
| `lib/domain/hebrew_date/hebrew_date.dart` | ישות טהורה `HebrewDate` (+`HebrewMonth`): שוויון, סדר כרונולוגי, אדר/אדר א׳/אדר ב׳ מפורשים — ללא תלות ב-Flutter/kosher_dart |
| `lib/domain/hebrew_date/hebrew_date_engine.dart` | `HebrewDateEngine`: העטיפה היחידה סביב `kosher_dart` — המרות עברי/לועזי, שנה מעוברת, ימים בחודש, ניווט חודשים (`addMonths`/`nextMonth`/`previousMonth`), שם חודש בעברית |
| `lib/domain/hebrew_date/hebrew_numerals.dart` | פירמוט גימטריה טהור (ללא תלות ב-kosher_dart): יום/שנה לאותיות עבריות עם גרש/גרשיים, כולל ט״ו/ט״ז |
| `lib/data/.gitkeep` | תיקייה שמורה לשכבת הנתונים (טרם קיים תוכן) |
| `lib/features/auth/.gitkeep` | תיקייה שמורה לפיצ'ר האימות (טרם קיים תוכן) |
| `lib/features/calendar/presentation/month_view_screen.dart` | מסך הבית: תצוגת חודש עברי עם `PageView` לדפדוף בין חודשים (+כפתורי חץ RTL-safe), כותרת App Bar בעברית |
| `lib/features/calendar/presentation/widgets/month_grid.dart` | גריד החודש: שורת ימי שבוע (א׳..ש׳), 6 שבועות קבועים, ימי חודשים סמוכים מטושטשים |
| `lib/features/calendar/presentation/widgets/day_cell.dart` | תא יום בודד: יום עברי בגימטריה (ראשי) + יום לועזי (משני), עיגול מלא ל"היום" |
| `lib/features/calendar/application/hebrew_date_engine_provider.dart` | Riverpod `Provider<HebrewDateEngine>` משותף לפיצ'ר היומן |
| `lib/features/calendar/application/displayed_month_provider.dart` | Riverpod `NotifierProvider.autoDispose` המחזיק את החודש העברי המוצג כרגע |
| `lib/features/event_editor/.gitkeep` | תיקייה שמורה לעורך האירועים (טרם קיים תוכן) |
| `lib/features/settings/.gitkeep` | תיקייה שמורה למסך ההגדרות (טרם קיים תוכן) |
| `lib/l10n/app_he.arb` | קובץ המקור (template) של מחרוזות העברית: `appTitle` וטולטיפים לניווט חודשים |
| `lib/l10n/app_localizations.dart` | קוד מחולל אוטומטית (מ-`app_he.arb`) — אין לערוך ידנית |
| `lib/l10n/app_localizations_he.dart` | קוד מחולל אוטומטית למחרוזות העבריות — אין לערוך ידנית |
| `tool/check_file_length.sh` | סקריפט CI שנכשל אם קובץ `.dart` תחת `lib/`/`test/` עובר 500 שורות |
| `.github/workflows/ci.yml` | Workflow של GitHub Actions: format, analyze, test+coverage, בדיקת אורך קבצים, ובנייה נפרדת של APK debug |
| `test/core/theme/dimens_test.dart` | טסט יחידה למתמטיקת ה-rem/spacing ולסיווג נקודות השבירה ב-`dimens.dart` |
| `test/domain/hebrew_date/hebrew_date_test.dart` | טסטים ל-`HebrewDate`: שוויון, סדר כרונולוגי (כולל אדר א׳/אדר ב׳), `copyWith` |
| `test/domain/hebrew_date/hebrew_date_engine_test.dart` | טסטים ל-`HebrewDateEngine`: round-trip, שנים מעוברות, אדר א׳/ב׳, אורך חשוון/כסלו, מעבר שנה, ניווט חודשים |
| `test/domain/hebrew_date/hebrew_numerals_test.dart` | טסטים לפירמוט הגימטריה: 1/15/16/20/30 ופירמוט שנה (5786 -> תשפ״ו) |
| `test/features/calendar/presentation/month_view_screen_test.dart` | טסט widget: RTL, כותרת חודש נכונה לתאריך קבוע, הדגשת "היום", שינוי כותרת בניווט |
