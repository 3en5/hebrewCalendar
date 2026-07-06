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

- **2026-07-06 · M2b, `google_sign_in` 7.x הוא API שנכתב מחדש:** גרסה 7
  (הראשונה שהותקנה כברירת מחדל ע"י `flutter pub add`) שונה מהותית ממדריכי
  Firebase+Google-Sign-In הנפוצים שמניחים גרסה 6: אין `GoogleSignIn()` +
  `signIn()`. במקום זה: `GoogleSignIn.instance` (סינגלטון) חייב
  `await initialize(...)` פעם אחת לפני כל שימוש אחר, ואז
  `authenticate()` (זורק `GoogleSignInException` עם `code: canceled`
  בביטול משתמש — לא מחזיר null כמו ב-v6). ל-`accessToken` יש עכשיו API
  נפרד (`account.authorizationClient.authorizeScopes(...)`); `idToken`
  בלבד (מ-`account.authentication.idToken`) מספיק ל-
  `GoogleAuthProvider.credential` של `firebase_auth`
  (`firebase_auth_platform_interface`: "At least one of ID token and
  access token is required"). ב-Android, כל עוד ל-`google-services.json`
  יש `oauth_client` עם `client_type: 3` (web client), `initialize()` לא
  צריך `clientId`/`serverClientId` מפורשים — הפלאגין הנטיבי קורא את
  `default_web_client_id` שנוצר אוטומטית.

- **2026-07-06 · M2b, `Timestamp.toDate()` תמיד מחזיר `DateTime` מקומי
  (local), לא UTC:** ב-`cloud_firestore` (v6.6.0), `Timestamp.fromDate`/
  `.toDate()` משמרים את הרגע בזמן (`microsecondsSinceEpoch`) אבל **לא**
  את הדגל `isUtc` — `toDate()` תמיד מחזיר `DateTime` מקומי. שוויון
  `DateTime ==` בדארט **כן** מתחשב בדגל הזה (בניגוד ל-`isAtSameMomentAs`,
  שמתעלם ממנו) — כך ש-`DateTime.utc(...) != DateTime` מקומי המייצג בדיוק
  אותו רגע. בקוד האמיתי זה לא בעיה כי `DateTime.now()` (המקור היחיד
  ל-`createdAt`/`updatedAt` באפליקציה) הוא כבר מקומי, כך שה-round-trip
  דרך Firestore נשאר עקבי; אבל טסט round-trip ל-`event_firestore_mapper`
  שהשתמש ב-fixture עם `DateTime.utc(...)` נכשל בשקט עם "נראה זהה" ב-
  `toString()` (ש-`Event` לא כולל בו createdAt/updatedAt) — התיקון: לבנות
  את ה-fixture עם `DateTime(...)` מקומי, לא `.utc(...)`, כדי לשקף איך
  התאריכים נוצרים בפועל.

- **2026-07-06 · M2b, `dl.google.com`/`maven.google.com` חסומים בסביבת
  הסוכן:** ה-proxy של סביבת הפיתוח (`$HTTPS_PROXY`) חוסם את
  `dl.google.com` (403, "policy denial") — וה-`google()` repository של
  Gradle (`maven.google.com`) עושה redirect לשם, כך שגם הוא חסום בפועל.
  המשמעות: אי אפשר להתקין Android SDK דרך `sdkmanager` בסביבה הזו (אין גם
  SDK מותקן מראש), וגם Gradle לא מצליח למשוך את Android Gradle Plugin/
  פלאגין `google-services`/AAR-ים של Firebase אפילו אם ה-SDK היה קיים.
  `flutter build apk --debug` (ודומיו) לא ניתנים להרצה במלואם בסביבת
  סוכן-המשנה — יש להסתמך על ה-job `build-apk` ב-CI (רץ על GitHub-hosted
  runner עם Android SDK מותקן מראש ורשת פתוחה) לאימות בפועל של שינויי
  Gradle/Firebase. אימות מקומי חלופי: `flutter analyze`+`flutter test`
  (שני אלה לא תלויים ב-Android SDK) בלבד.

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

- **2026-07-06 · M3a, אריתמטיקת ימים ל-`weekly`/`daily` חייבת להיות ב-UTC:**
  `RecurrenceType.weekly`/`daily` ב-`recurrence_expander.dart` מחשבים "כמה
  צעדים של 7/1 ימים מהבסיס" ע"י חיסור בין שני `DateTime` שמוחזרים מ-
  `HebrewDateEngine.toGregorian` (שהם local, לא UTC — ראה הלקח למעלה על
  `Timestamp.toDate()`). חיסור/חיבור `Duration` בין `DateTime` מקומיים
  חשוף לחריגות שעון-קיץ: יום עם 23 או 25 שעות (מעבר DST) יכול להזיז
  `.difference(...).inDays` בטעות של יום שלם. הפתרון: `_toUtcDate` בונה
  `DateTime.utc(y, m, d)` מהשדות של ה-`DateTime` המקומי (לא ממיר `.toUtc()`
  — זה היה משנה את הרגע בפועל; אנחנו רק רוצים "לנעול" את שדות התאריך
  בלי אזור זמן) ומבצע את כל האריתמטיקה על עותקי UTC, לפני שממירים בחזרה
  ל-Hebrew דרך `engine.fromGregorian` (שקורא רק year/month/day מה-`DateTime`
  שהוא מקבל, לא איכפת לו אם הוא UTC או local). לקח כללי: כל חישוב "הפרש
  בימים" בין שני `DateTime`ים ב-Dart שמקורם מ-API מקומי (לא רק
  kosher_dart) צריך לנרמל ל-UTC לפני החיסור, אחרת יש סיכון לטעות-יום נדירה
  סביב מעברי שעון.

- **2026-07-06 · M3a, `ListView` (לא-builder) בטסטי widget לא בונה ילדים
  הרחק מהאזור הנראה:** בדיקת widget שגוללת רשימת `ListView(children: [...])`
  ארוכה (מסך עורך האירועים אחרי הוספת בורר החזרתיות) גילתה ש-`find.text`
  לא מוצא widget שקיים ברשימת ה-children שהועברה בקוד, אם הוא רחוק מספיק
  מתחת לאזור הנראה (מעבר ל-cache extent של ה-sliver). התיקון: לגלול עם
  `tester.dragUntilVisible(finder, scrollableFinder, step)` — אבל גם הוא
  עוצר ברגע שהאלמנט *נבנה* (בתוך cache extent), לא בהכרח ברגע שהוא
  hit-testable בפועל בתוך viewport; נדרש drag קטן נוסף אחרי
  `dragUntilVisible` לפני `tester.tap(...)` כדי למנוע "derived an Offset
  that would not hit test". לקח כללי: אל תניחו של-`find.*` יש גישה לכל
  widget שקיים בקוד המקור של רשימה גוללת — רק למה שה-sliver בפועל בנה.

- **2026-07-06 · CI עם קונפיג Firebase מוסתר:** `google-services.json` ב-gitignore
  ולכן ג'וב בניית ה-APK ב-CI נכשל על "File google-services.json is missing".
  הפתרון: ה-workflow יוצר קובץ placeholder עם ערכים מזויפים (רק ה-package_name
  חייב להיות אמיתי) — מספיק לבניית debug, והקונפיג האמיתי לא נחשף. בנוסף,
  פלאגיני Firebase דורשים NDK 27 — נקבע `ndkVersion = "27.0.12077973"` מפורש
  ב-`android/app/build.gradle.kts`.
