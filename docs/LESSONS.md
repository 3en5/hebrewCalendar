# לקחים — HebrewCalendar

נרשם לאחר משימות מורכבות או תקלות. **בדוק כאן לפני משימה דומה** (RULES.md §3.3).

פורמט: תאריך · הקשר · הלקח.

---

- **2026-07-06 · סביבת פיתוח:** Flutter הותקן ב-`/opt/flutter` כ-root — נדרש
  `git config --global --add safe.directory /opt/flutter` לפני שהכלי עובד.
  ה-PATH: להשתמש ב-`/opt/flutter/bin/flutter`.

- **2026-07-06 · M1, `kosher_dart` (2.0.18) API quirks:**
  1. `JewishDate.getGregorianMonth()` מתועד כ-0-based ("like java.util.Calendar,
     January == 0") אבל בפועל **מחזיר ערך 1-based** (ינואר=1) — אומת מול
     טסטי המקור של החבילה עצמה (`test/ut_gregorian_date_navigation.dart`,
     `test/ut_jewish_date_navigation.dart`). `HebrewDateEngine.toGregorian`
     בונה `DateTime` ישירות מ-`getGregorianYear/Month/DayOfMonth()` בלי
     המרה — מסתמכים על ההתנהגות בפועל, לא על ה-doc.
  2. הקונסטרוקטור `JewishDate.initDate(...)` מכיל את הבאג
     `_minute = _minute;` (self-assignment) במקום `_minute = minute;`, כך
     שהפרמטר `minute` מתעלם תמיד בשקט. לא משפיע עלינו כי `HebrewDateEngine`
     לא משתמש בזמן-יום (רק בתאריך), אבל אם ייעשה בו שימוש עתידי — לזכור
     שהפרמטר לא עובד.
  3. מספור החודשים של `kosher_dart` מתחיל מניסן (`NISSAN=1`, `TISHREI=7`,
     `ADAR=12`, `ADAR_II=13`), לא מתשרי. שכבת ה-`HebrewMonth` שלנו מסודרת
     כרונולוגית מתשרי (לוח שנה) והממיר בין השניים (`_monthToKosher`/
     `_monthFromKosher`) חייב את שני הכיוונים + בדיקת שנה מעוברת כדי
     להבחין בין אדר/אדר א׳/אדר ב׳ (שכולם ADAR=12 חוץ מאדר ב׳ שהוא
     ADAR_II=13, ורק בשנה מעוברת).
  4. אין ל-`kosher_dart` פונקציית "חודש אחורה" (`JewishDate.back()` זז יום
     אחד בלבד; `forward(Calendar.MONTH, n)` תומך רק בקדימה). `addMonths`
     שלנו מומש מחדש בדארט טהור (לא דרך kosher_dart) על בסיס רשימת החודשים
     הכרונולוגית של השנה + `isLeapYear`, כדי לתמוך גם בניווח אחורה.

- **2026-07-06 · פיקוח על סוכנים:** קובץ ה-output של סוכן-משנה לא מתעדכן
  בזמן אמת — סוכן יכול להיראות "מת" (קובץ קטן וישן) בזמן שהוא עובד.
  הסימן האמין לפעילות: שינויים בעץ העבודה של git ותהליכי dart/flutter
  רצים. מעקב סיום נכון: יציבות `git status --porcelain` + ps לאורך כמה דקות.

- **2026-07-06 · M2a, `flutter_riverpod` 3.3.2 API:** `StreamProviderFamily`,
  `NotifierProviderFamily` ו-`Override` (וכל שם הנחוץ להצהרת טיפוס מפורשת
  ל-provider מסוג `.family`/`overrides:`) **אינם** מיוצאים מ-
  `package:flutter_riverpod/flutter_riverpod.dart` הראשי — יש לייבא אותם
  במפורש מ-`package:flutter_riverpod/misc.dart`. שימוש ב-`var`/`final`
  ללא טיפוס מפורש (או ב-Dart, הרבה widget code) לא נתקל בזה כי הטיפוס
  מוסק; הבעיה עולה רק כשרוצים להצהיר את הטיפוס של המשתנה/שדה במפורש
  (כפי שדורש RULES.md `always_declare_return_types`/קונבנציית הפרויקט).

- **2026-07-06 · M2a, מלכודת timing ב-broadcast `Stream` בזיכרון:** מימוש
  `InMemoryEventRepository.watchEventsForHebrewMonth` הראשוני היה `async*`
  ש-`yield`ת snapshot נוכחי ואז `yield*`ת `_changes.stream` ממופה. זה נשבר:
  broadcast `StreamController` **זורק** אירועי `add()` שאין להם מאזין באותו
  רגע, וה-generator נרשם כמאזין ל-`_changes` רק *אחרי* שמסר את הערך
  הראשון שלו — כך שמוטציה סינכרונית מיד אחרי ה-subscribe (בדיוק המצב
  בטסט: `stream.take(2).toList()` ואז `create()` בלי המתנה בין השניים)
  מוחמצת בשקט: הראשונה שנתפסת בתמונת המצב הראשונה (race, לא ריק כמצופה),
  והשנייה לעולם לא מגיעה (timeout). התיקון: לבנות את ה-`Stream` ידנית עם
  `StreamController.broadcast(onListen: ...)` שבו ההרשמה ל-`_changes`
  והפליטה הראשונית קורות יחד, סינכרונית, באותו callback — כך שאין חלון
  זמן שבו מוטציה יכולה "ליפול בין הכיסאות". לקח כללי: כל `Stream` בזיכרון
  שמשלב "ערך התחלתי + עדכונים עתידיים" על בסיס broadcast controller חייב
  להירשם לעדכונים *לפני* (או באותו טיק סינכרוני של) חישוב הערך ההתחלתי,
  אחרת יש חלון race — גם אם בשימוש אמיתי מה-UI (בניגוד לטסט סינכרוני) החלון
  נדיר שיתממש בפועל.
