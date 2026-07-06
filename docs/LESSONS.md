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

- **2026-07-06 · M3b, סנכרון `PageView` משותף בין כמה תצוגות בלי לולאת
  עדכונים:** תצוגות חודש/שבוע/יום (M3b) כולן `PageView`ים עם עוגן קבוע
  שנקבע ב-`initState` (בהמשך לתבנית תצוגת החודש המקורית מ-M1), אבל כולן
  צריכות גם להגיב לשינוי מיקוד *חיצוני* (כפתור "היום", מעבר בין תצוגות עם
  אותו `focusedDate` משותף). הפתרון (`PagedFocusSync`) לא צריך flag
  מפורש להבחין בין "השינוי הגיע מהחלקה של המשתמש" ל"השינוי הגיע מבחוץ":
  מספיק להשוות את התאריך המבוקש (מעוגל לרזולוציה של התצוגה) מול התאריך
  שהעמוד הנוכחי כבר מציג (`dateForPage(currentPage)` עם העוגן *הישן*,
  לפני שמעדכנים אותו) — אם הם שווים, זו הדהוד מהעדכון העצמי של התצוגה
  עצמה (`onPageChanged` כבר עדכן את הספק המשותף לאותו ערך בדיוק) ואין
  צורך לעשות כלום; אם שונה, זה שינוי חיצוני אמיתי, מעדכנים עוגן וקופצים
  לעמוד המרכזי. לקח כללי: כששני צדדים (widget מקומי + state משותף)
  יכולים לעדכן זה את זה, "האם השינוי כבר משתקף במצב הנוכחי" הוא בדרך כלל
  בדיקה נקייה יותר מדגל "מי יזם את זה".
- **2026-07-06 · M3b, כיוון swipe ב-`PageView` תחת RTL אינו טריוויאלי
  לחיזוי בטסט:** איזה כיוון גרירה (`tester.drag` עם `dx` חיובי/שלילי)
  מתקדם ל"עמוד הבא" תלוי בשילוב של `Axis`, `reverse` ו-`Directionality`
  (`getAxisDirectionFromAxisReverseAndDirectionality`) — לא כיוון קבוע
  שאפשר לנחש. טסט widget שגורר `PageView` תחת RTL ובודק ניווט לא צריך
  להניח כיוון ספציפי (הבא מול הקודם); מספיק לאמת שהכותרת המקורית נעלמת
  והכותרת החדשה היא אחד משני החודשים הצמודים כרונולוגית — זה מאמת את
  חיווט ה-paging בלי להיות שביר לפרטי המימוש של איזה כיוון בדיוק "הבא".

- **2026-07-06 · CI עם קונפיג Firebase מוסתר:** `google-services.json` ב-gitignore
  ולכן ג'וב בניית ה-APK ב-CI נכשל על "File google-services.json is missing".
  הפתרון: ה-workflow יוצר קובץ placeholder עם ערכים מזויפים (רק ה-package_name
  חייב להיות אמיתי) — מספיק לבניית debug, והקונפיג האמיתי לא נחשף. בנוסף,
  פלאגיני Firebase דורשים NDK 27 — נקבע `ndkVersion = "27.0.12077973"` מפורש
  ב-`android/app/build.gradle.kts`.

- **2026-07-06 · M4, מזהי התראה יציבים חייבים hash דטרמיניסטי משלנו, לא
  `Object.hash`/`hashCode`:** `flutter_local_notifications` דורש `id: int`
  קבוע לכל תזכורת כדי לדעת "זו אותה תזכורת, לעדכן" מול "זו חדשה" בין
  replan אחד למשנהו (`reminder_planner.dart`'s `computeStableNotificationId`).
  `Object.hash`/ברירת המחדל של `hashCode` **אינם** מובטחים לתת אותו ערך בין
  שתי הרצות שונות של האפליקציה (יכולים להשתנות עם hash-seed randomization
  של ה-VM) — שימוש בהם היה גורם לכל replan אחרי restart של האפליקציה
  לבטל ולתזמן מחדש כל תזכורת קיימת בטעות (במקום לזהות שהיא לא השתנתה).
  הפתרון: hash טקסטואלי דטרמיניסטי משלנו (FNV-1a 32-bit) על מחרוזת מפתח
  שנבנית רק מהשדות היציבים (event id + תאריך מופע + minutesBefore) — אותו
  מפתח נותן תמיד את אותו digest, בהרצה הזו ובכל הרצה עתידית.

- **2026-07-06 · M4, `AppLocalizationsHe()` ניתן לבנייה ישירה בלי `BuildContext`:**
  קוד data/application (למשל `LocalNotificationScheduler`, שצריך שם ערוץ
  עברי מ-ARB "בקונסטרוקציה" לפי המשימה) לא תמיד רץ בתוך widget tree עם
  גישה ל-`BuildContext` (וב-Riverpod `Provider` regular אין אחד בכלל).
  הפתרון בפרויקט הזה (שתומך אך ורק בעברית — `main.dart` קובע
  `Locale('he')` קשיח): מחלקת השפה המחוללת (`AppLocalizationsHe`, ב-
  `lib/l10n/app_localizations_he.dart`) היא מחלקת Dart רגילה עם קונסטרוקטור
  ציבורי (`AppLocalizationsHe([String locale = 'he'])`) — ניתן לבנות אותה
  ישירות (`AppLocalizationsHe().notificationsChannelName`) בלי
  `AppLocalizations.of(context)` בכלל. שימושי לכל טקסט עברי הדרוש מחוץ
  לעץ ה-widgets, אך **רק** כשהאפליקציה תומכת בשפה יחידה קבועה כפי שקורה
  כאן — לא פתרון כללי לריבוי שפות.

- **2026-07-06 · M5a, `google_sign_in` v7 חושף bearer headers ישירות — מייתר
  את הצורך ב-`googleapis`/`googleapis_auth`:** לפי המשימה, המסלול המוצע
  ל-auth מול Calendar API היה `googleapis`+`googleapis_auth` או
  `extension_google_sign_in_as_googleapis_auth`. בבדיקת המקור המותקן בפועל
  (`google_sign_in-7.2.0/lib/google_sign_in.dart`) התברר ש-
  `GoogleSignInAccount.authorizationClient.authorizationHeaders(scopes,
  promptIfNecessary: true)` כבר מחזיר `Map<String,String>` מוכן
  (`{'Authorization': 'Bearer $token', 'X-Goog-AuthUser': '0'}`) — אין צורך
  ב-`googleapis_auth`'s `AuthClient`/`clientViaUserConsent` בכלל, ו-
  `extension_google_sign_in_as_googleapis_auth` (הבנוי סביב ה-API הישן של
  v6, `GoogleSignInAccount.authHeaders`) לא מתאים למבנה v7 ממילא (ראה הלקח
  הקודם על v7 being a rewrite). בנוסף, ה-client המחולל של `package:googleapis`
  (`CalendarApi.events.patch`/`.delete`) אינו חושף דרך נוחה להגדיר header
  מותאם אישית כמו `If-Match` — קריטי למנגנון זיהוי הקונפליקטים מבוסס-etag
  (ARCHITECTURE.md §5). ההחלטה: `google_calendar_api_impl.dart` קורא ל-
  Calendar v3 REST ישירות דרך `package:http` (JSON ידני, לא טיפוסי
  googleapis) — שליטה מלאה בכותרות/קודי סטטוס (410/412), ושתי תלויות פחות
  שאי אפשר לבדוק במלואן בסביבה בלי גישת רשת ל-Google APIs ממילא. לקח כללי:
  לפני שמוסיפים תלות SDK "מומלצת" לאינטגרציה חדשה, לבדוק את ה-API בפועל של
  התלות שכבר קיימת (כאן: `google_sign_in`) — לפעמים כבר יש בה את מה שצריך.

- **2026-07-06 · M5a, מודל סנכרון-לפי-מופע לאירוע חוזר דורש הרחבה מעבר
  ל-`googleSync` היחיד שב-ARCHITECTURE.md §4 המקורי:** השדה `googleSync
  {googleEventId, etag, lastSyncedAt, dirty}` שהוגדר מראש הוא מיפוי **יחיד**
  בין מסמך `Event` למופע גוגל יחיד — נכון לאירוע לא-חוזר, אבל אירוע חוזר
  מיוצא כמה מופעים ממומשים (ARCHITECTURE.md §5, "individual materialized
  instances"), ומסמך יחיד לא יכול להחזיק `googleEventId` יחיד לכמה אירועי
  גוגל. הפתרון: שדה נוסף `googleInstanceSync` (מפה: מפתח מופע דטרמיניסטי,
  `occurrence_key.dart`, -> `GoogleSyncState` לאותו מופע ספציפי) — `googleSync`
  עצמו נשאר ומשמש (א) את המיפוי היחיד לאירוע לא-חוזר, ו-(ב) את דגל
  `dirty`/`lastSyncedAt` **ברמת הסדרה כולה** גם לאירוע חוזר ("יש עריכה
  ממתינה לדחיפה של כל המופעים"), בלי `googleEventId`/`etag` (חסרי משמעות
  ברמת הסדרה). זו הרחבה תואמת-לאחור של המבנה שתוכנן ב-M2b, לא סטייה ממנו —
  תועד ב-ARCHITECTURE.md §4/§5 בהתאם. לקח כללי: כששדה יחיד "X -> מזהה מרוחק
  אחד" מתוכנן לפני שסוג-אחד-לרבים (yearly/monthly/וכו') ידוע להיות אפשרי,
  לרוב יידרש שדה-מפה נלווה ברמת "כל מופע בנפרד" לצד היחיד ברמת "כל הישות".

- **2026-07-06 · M5a, תור מחיקות ממתינות ל-Google Calendar חייב עמידות
  ב-Firestore, לא רק בזיכרון, כי M5a הוא foreground-only:** מחיקת אירוע
  מקומי (`EventRepository.delete`) שכבר יוצא לגוגל צריכה לגרום למחיקה
  מרוחקת גם היא (ARCHITECTURE.md §5, "deletions propagate both ways") — אבל
  ברגע המחיקה עצמה ייתכן שאין חיבור רשת/הסנכרון מנוטרל/האפליקציה עומדת
  להיסגר. ב-`InMemoryEventRepository` (המשמש טסטים בלבד) תור פשוט בזיכרון
  (`List<PendingGoogleDeletion>`) מספיק — הוא ממילא לא שורד בין הרצות
  אפליקציה. אבל ב-`FirestoreEventRepository` (`firestore_event_sync_support.dart`)
  אותו תור-בזיכרון היה אומר שמחיקה בין `delete()` להרצת `runSync()` הבאה,
  אם התהליך נהרג באמצע, אובדת בשקט לצמיתות — כי אין (עדיין, עד M5b)
  WorkManager תקופתי שינסה שוב במהרה. הפתרון: התור נשמר כמסמכים תחת
  `users/{uid}/pendingGoogleDeletions/{eventId}` (עמיד), מתרוקן (וכל מסמך
  נמחק) רק כשהמנוע בפועל מצליח לשלוח את בקשת המחיקה לגוגל. לקח כללי: תור
  "משימות ממתינות" שנוצר ע"י פעולת משתמש חד-פעמית (לא stream מתמשך) חייב
  אחסון עמיד ברגע שאין עדיין מנגנון רקע אמין שמנקה אותו במהרה — "בזיכרון
  זמנית, נשלים עמידות ב-M הבא" הוא סיכון איבוד שקט, לא רק חוסר-אופטימיזציה.

- **2026-07-06 · M5b, `workmanager` (0.9.0+3) — כמה פערים בין הציפייה
  הנאיבית לממשק בפועל:**
  1. `Workmanager().registerPeriodicTask(...)`'s `existingWorkPolicy` הוא
     `ExistingPeriodicWorkPolicy?`, **לא** `ExistingWorkPolicy` — זה האחרון
     של `registerOneOffTask` בלבד; שני ה-enum-ים דומים בשם (`keep` קיים
     בשניהם) אבל טיפוסיים שונים, אז אי אפשר להעביר בטעות את הלא-נכון בלי
     שגיאת קומפילציה — אבל קל לנחש שם שגוי מהתיעוד/מדריכים ישנים של
     גרסאות קודמות של הפאקג'.
  2. `Workmanager().initialize(callbackDispatcher, {isInDebugMode})`'s
     `isInDebugMode` **מיושן ולא עושה כלום** בגרסה הזו (יש להשתמש ב-
     `WorkmanagerDebug` handlers במקום) — מעביר אותו בכל זאת (כמו שהמשימה
     המקורית ביקשה `isInDebugMode: false`) מדליק אזהרת
     `deprecated_member_use` תחת ה-`analysis_options.yaml` המחמיר של
     הפרויקט (0 issues נדרש). הפתרון: פשוט משמיטים את הפרמטר — ברירת
     המחדל שלו כבר `false`, אז ההתנהגות בפועל זהה למה שהמשימה ביקשה, בלי
     להדליק את ה-lint.
  3. `package:workmanager`'s `executeTask` callback רץ ב-**isolate/מנוע
     Flutter נפרד**, לא זה של האפליקציה בפורגראונד — אין זיכרון משותף,
     `Provider`/`Riverpod` state, או singleton שכבר אותחל. כל תלות (Firebase,
     `GoogleSignIn.instance`) חייבת אתחול/שחזור-session מאפס בכל טיק. חשוב
     במיוחד: `FirebaseAuth.instance.currentUser` **כן** שורד (Firebase Auth
     שומר session ב-storage מקומי שהוא app-wide, לא isolate-wide) אחרי
     `Firebase.initializeApp()` טרי ב-isolate החדש — זו הדרך הזולה ביותר
     לבדוק "האם המשתמש בכלל מחובר" לפני שטורחים בכלל להתחיל שחזור session
     של Google Sign-In (`attemptLightweightAuthentication`, שדורש
     `GoogleSignIn.instance.initialize()` תחילה כי זה isolate טרי — בניגוד
     ל-`FirebaseAuthRepository`'s `_ensureGoogleSignInInitialized` הממוזג,
     `initialize()` נקרא כאן פעם אחת בלי memoization כי כל הפונקציה רצה
     לכל היותר פעם אחת per isolate ממילא).
  4. מנעול "in-flight" מבוסס-instance-flag (כמו זה שנוסף ל-`SyncEngine`
     כדי למנוע שתי ריצות בו-זמנית) **לא** מגן חוצה-isolate: ריצת רקע
     תקופתית של WorkManager מקבלת isolate/מופע `SyncEngine` חדש משלה, אז
     דגל `bool` רגיל על המחלקה לא "רואה" ריצה שרצה במופע/isolate אחר. זה
     בסדר כאן כי (א) `runSync()` כבר תועד כבטוח-לקריאה-חוזרת/מקבילית (כל
     קריאה טוענת settings/token טריים, אז חפיפה גוררת עבודה כפולה ולא
     שחיתות מצב), ו-(ב) `existingWorkPolicy: keep` כבר מונע חפיפה בין שתי
     ריצות *רקע* זו את זו ברמת WorkManager עצמו. לקח כללי: לפני שמוסיפים
     "מנעול concurrency" לקוד שעלול לרוץ גם ב-isolate נפרד (background
     task, isolate.spawn, וכו') — לתעד במפורש את גבול ההגנה בפועל
     (per-instance/per-isolate) ולא להניח שדגל `bool` הוא הגנה גלובלית.

- **2026-07-06 · M4, טסטי widget שמרנדרים מסך שמפעיל שירות רקע (subscription+
  Timer) חייבים fake לתלות החיצונית, לא רק try/catch בתוכה:** חיווט
  `reminderSyncServiceProvider` (autoDispose) מ-`CalendarShellScreen` גרם
  לכל טסט widget קיים שמרנדר את המסך הזה (auth_gate/month/week/day/agenda/
  calendar_shell — 8 קבצים) לבנות בפועל `LocalNotificationScheduler` אמיתי
  כברירת מחדל, שמנסה לקרוא לפלאגין `flutter_local_notifications` דרך
  `MethodChannel` — שאין לו handler רשום תחת `flutter test`
  (`debugDefaultTargetPlatformOverride` הוא `android` כברירת מחדל בטסטים,
  אז הקוד *כן* מנסה לפנות לערוץ אנדרואיד). עטיפת כל קריאת פלאגין ב-
  try/catch ב-`LocalNotificationScheduler` (כבר נדרש ממילא בשביל "graceful
  degradation" באנדרואיד עצמו) מטפלת בחריגה, אבל **לא** בסיכון הנפרד של
  Timer/`StreamSubscription` שנשארים תלויים בסוף הטסט (debounce Timer של
  `ReminderSyncService`) — `flutter_test` נכשל אם Timer עדיין ממתין כשה-
  widget tree נהרס. הפתרון הנקי: override מפורש של `notificationSchedulerProvider`
  עם `FakeNotificationScheduler` (test double פשוט, `test/test_support/
  fake_notification_scheduler.dart`) בכל טסט כזה — לא רק להישען על עטיפת
  try/catch בתוך מימוש הפלאגין. לקח כללי: כשמוסיפים שירות רקע (subscription
  ממושך + timer) שמופעל אוטומטית ממסך קיים, כל טסט widget שמרנדר את המסך
  הזה צריך override מפורש לתלות שלו (לא להסתמך על חוסן פנימי בלבד).

- **2026-07-06 · M7, `file_picker` 11.0.2: `FilePicker` הוא `abstract final
  class` עם שיטות static — אין `FilePicker.platform`:** מדריכים/דוגמאות
  ישנות (גרסאות קודמות של הפאקג') קוראות ל-`FilePicker.platform.saveFile(...)`/
  `.pickFiles(...)`, אבל ב-11.0.2 `FilePicker` עצמו מכריז את `saveFile`/
  `pickFiles`/`getDirectoryPath` כ-`static` ישירות (עוטפות פנימית את
  `FilePickerPlatform.instance` בעצמן) — קריאה ל-`FilePicker.platform` נכשלת
  בקומפילציה (`undefined_getter`). הקריאה הנכונה: `FilePicker.saveFile(...)`/
  `FilePicker.pickFiles(...)` ישירות על המחלקה. בנוסף: `saveFile`'s `bytes`
  הוא **חובה** באנדרואיד/iOS (זורק `ArgumentError` אם `null`) — הפלאגין כותב
  את הבייטים בעצמו ומחזיר את הנתיב שנשמר אליו, שלא כמו בדסקטופ שבו צריך
  לכתוב את הקובץ ידנית לנתיב המוחזר.

- **2026-07-06 · M7, `share_plus` 12.0.2: `XFile.fromData`'s `name` מתעלם
  באנדרואיד/iOS — יש להשתמש ב-`ShareParams.fileNameOverrides`:** בבניית
  `XFile` מ-bytes דרך `XFile.fromData(bytes, name: '...')` (ה-implementation
  המבוסס `dart:io`, לא web), הפרמטר `name` פשוט לא נשמר/נקרא בחזרה — הערה
  בקוד המקור של `cross_file` מתעדת זאת במפורש. כדי לתת לקובץ המשותף שם קובץ
  משמעותי (`hebrew-calendar-backup-YYYY-MM-DD.json` ולא שם זמני חסר משמעות),
  יש להעביר את השם דרך `ShareParams.fileNameOverrides` (רשימה במקביל ל-
  `files`) במקום — זה נצרך בפועל בכל הפלטפורמות, כולל אלה שבהן `XFile.name`
  מתעלם.

- **2026-07-06 · M7, `flutter_riverpod`/`riverpod` 3.3.2: אין `AsyncValue.valueOrNull`
  — הגטר הנכון הוא `.value`:** גרסאות/תיעוד מאוחרים יותר של Riverpod מציגים
  `valueOrNull` כדרך ה"בטוחה" לקרוא ערך מ-`AsyncValue` בלי לזרוק (בניגוד
  ל-`requireValue`), אבל ב-3.3.2 המותקנת בפועל השם של אותו גטר הוא פשוט
  `value` (`ValueT? get value => _value?.$1;`) — `valueOrNull` לא קיים כלל
  ומדליק `undefined_getter`. לקח כללי: כמו עם `google_sign_in`/`workmanager`
  קודם (ראה למעלה) — לבדוק את ה-API בפועל של הגרסה המותקנת (`grep` בתוך
  `.pub-cache`) לפני שמניחים ששם/API מתועד/נפוץ ברשת תואם את הגרסה שנעולה
  ב-`pubspec.yaml`.

- **2026-07-06 · M7, `package_info_plus` חושף `setMockInitialValues` כ-seam
  רשמי לטסטים:** בניגוד לפלאגינים אחרים בפרויקט (`flutter_local_notifications`,
  `workmanager`) שנעטפים תמיד ב-fake/interface כדי שטסטים לא ייגעו בערוץ
  האמיתי, `PackageInfo.fromPlatform()` שומר תוצאה ב-cache סטטי (`_fromPlatform`)
  ש-`PackageInfo.setMockInitialValues(...)` ממלא מראש — קריאה לזה לפני
  `pumpWidget` בטסט מונעת לגמרי `MissingPluginException` בלי צורך ב-provider
  override כלל. שימושי כשמשתמשים בפאקג' ישירות (לא דרך שכבת domain/interface
  משלנו) ורוצים את דרך הטסט הכי קרובה למה שהמתחזק/הפאקג' עצמו תומך בו.

- **2026-07-06 · פיקוח על CI — לבדוק את ג'וב ה-build אחרי כל שלב, לא רק
  את הטסטים:** ג'וב `build-apk` נכשל בשקט מאז M4 (`flutter_local_notifications`
  דורשת core library desugaring — `isCoreLibraryDesugaringEnabled = true` +
  תלות `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`)
  והכשל התגלה רק ב-M7, כי אחרי M3b נבדק רק ג'וב הטסטים. מכיוון שבסביבת
  הפיתוח אי אפשר להריץ `flutter build` (ראה לקח dl.google.com), ג'וב
  ה-build ב-CI הוא **האימות היחיד** לשינויי Gradle/פלאגינים — חובה לוודא
  שהוא ירוק אחרי כל milestone שמוסיף פלאגין עם קוד נטיבי.

- **2026-07-06 · סבב משוב מכשיר #1, תיקון #2 — ספינר אינסופי במסך ההגדרות:**
  שורש הבעיה **לא** היה מה שהמשימה שיערה כסביר ביותר (חוסר-התאמה בין
  `firestore.rules`'s `isValidUserDoc` `hasOnly` whitelist לבין השדות
  שהאפליקציה בפועל כותבת/קוראת ב-`users/{uid}`) — נבדק לעומק ואומת: הרשימה
  הלבנה כבר כללה את כל ארבעת שדות הסנכרון מאז M5a/M5b. השורש האמיתי: ב-
  `google_sync_trigger_service.dart`'s `start()`, הקריאה
  `await _settingsStore.load()` (קריאת Firestore) הייתה **לא מוגנת בכלל** —
  לא `try/catch`, לא timeout. `googleSyncTriggerServiceProvider`
  (ב-`google_sync_providers.dart`) קורא ל-`start()` דרך
  `unawaited(service.start()...)`, כך שאם ה-`Future` נכשל (permission-denied
  כי ה-Rules האמיתיות שרצות מול הפרויקט טרם פורסמו — ראה סעיף "נותר / דורש
  פעולת משתמש" שחוזר על עצמו אחרי כל milestone; או סתם timeout רשת), החריגה
  פשוט "נבלעת" ב-Zone (בלי לקרוס, בזכות `runZonedGuarded` ב-`main.dart`),
  אבל **`_emit()` אף פעם לא נקרא** — כלומר ה-`StreamController` הפנימי (ש-
  `googleSyncStateProvider`'s `StreamProvider` צופה בו) אף פעם לא פולט אירוע
  ראשון, כך ש-`AsyncValue` נשאר ב-`loading()` **לצמיתות** — ספינר אינסופי,
  בדיוק כמו שדווח. התיקון: `start()` עוטף את הקריאה כולה ב-`try/catch` +
  `.timeout(_startTimeout)` (ניתן להזרקה, ברירת מחדל 10 שניות) — בכל מקרה
  (הצלחה, כישלון, timeout) מגיע ל-`_emit()` אחד, כך שה-UI תמיד יוצא מ-
  `loading()` תוך זמן חסום. לקח כללי: **כל** `unawaited(future...)` שמזין
  `Stream`/state ש-UI צופה בו חייב לתפוס ולמפות כל חריגה למצב-שגיאה שנפלט
  במפורש — אחרת "נראה בטוח כי יש runZonedGuarded גלובלי" הוא מלכודת: החריגה
  אכן לא מקריסה את האפליקציה, אבל גם לא מגיעה לשום מקום שה-UI יכול להגיב
  אליו, מה שמשאיר widget תלוי ב-state הביניים (`loading`) לנצח. בנוסף:
  טסט widget שרוצה לדמות "תלות חיצונית שלעולם לא מסתיימת" (למשל store שה-
  `load()` שלו לעולם לא נפתר) צריך provider נפרד להזרקת ה-timeout (כאן:
  `syncStartTimeoutProvider`) כדי שהטסט יוכל לקצר אותו במכוון — ואחרי
  שממתינים ל-`Future` שמסתיים ב-timeout, בדיקה על `Stream` broadcast חייבת
  `await` נוסף (כמו ה-`_settle()` helper הקיים בקובץ) לפני שבודקים את
  התוצאה: סיום ה-`Future` וה"מסירה" בפועל של האירוע למאזין ה-`Stream` הם
  שתי תזמונים אסינכרוניים נפרדים (לא זהים), אז `await theFuture;` לבד לא
  מבטיח שהמאזין כבר קיבל את האירוע.

- **2026-07-06 · סבב משוב מכשיר #1, תיקון #3 — `childAspectRatio` קבוע ב-
  `GridView` שובר על מסכים צרים:** `SliverGridDelegateWithFixedCrossAxisCount`
  בלי `childAspectRatio` מפורש בררת המחדל שלו היא `1.0` (תא ריבועי) —
  ב-`month_grid.dart` זה אילץ גובה תא = רוחב תא, ובמכשיר עם 7 עמודות ורוחב
  מסך ~360dp, גובה כל תא יצא ~50dp: פחות ממה ש-`DayCell`'s content באמת צריך
  (~70dp+), ומכאן "BOTTOM OVERFLOWED BY 20 PIXELS" **בכל תא**, לא רק בקצה
  מסך. התיקון בשתי שכבות: (1) `LayoutBuilder` סביב ה-`GridView` מחשב
  `childAspectRatio` מהגובה *הזמין בפועל* לגריד (`constraints.maxHeight`)
  חלקי 6 השורות, במקום להסתמך על ברירת המחדל הריבועית — כך שהתא תמיד ממלא
  את השטח שהוקצה לו בפועל; (2) `FittedBox(fit: BoxFit.scaleDown)` בתוך
  `DayCell` עצמו כרשת ביטחון נוספת — גם אם התא עדיין צר מדי (למשל תחת
  `textScaleFactor` גבוה מ-1.0), אין overflow לעולם כי כל התוכן מצטמצם יחד
  במקום לחרוג. לקח כללי: `GridView`/`SliverGridDelegateWithFixedCrossAxisCount`
  עם תוכן שאינו טקסט-בודד-קצר צריך תמיד `childAspectRatio` מחושב מהמידות
  האמיתיות (או `LayoutBuilder`), לא את ברירת המחדל הריבועית — וטסט widget
  שמאמת "אין overflow" חייב לרנדר בגודל מסך קטן ריאליסטי (לא ברירת המחדל
  800x600 הנדיבה של `flutter test`) **וגם** ב-`textScaleFactor` מוגדל, לא
  רק בגודל/סקייל ברירת המחדל — שני הגורמים יחד (לא כל אחד לחוד) הם שחישפו
  את הבאג הזה בפועל.
