# שחרור גרסה (Release) — HebrewCalendar

מדריך צעד-אחר-צעד להכנת גרסת שחרור חתומה ולהעלאתה ל-Play Console. ראה גם
`docs/TESTING_AND_DEPLOY.md` לכללי הדיפלוי הכלליים ולמסלול השחרור
(internal -> closed -> production).

## 1. יצירת keystore לשחרור (פעם אחת, לשמור לתמיד)

**חשוב:** ה-keystore הזה **שונה** מ-`android/debug.keystore` המחויב בריפו
(RULES.md §5.4 — אין לשים סודות בריפו). איבוד ה-keystore הזה = אי אפשר יותר
לעדכן את האפליקציה ב-Play Store תחת אותו מזהה — לגבות אותו במקום בטוח מחוץ
לריפו (מנהל סיסמאות, כספת ארגונית וכו').

```bash
keytool -genkey -v \
  -keystore hebrewcalendar-release.jks \
  -alias hebrewcalendar \
  -keyalg RSA -keysize 2048 -validity 10000
```

יתבקשו סיסמת keystore, סיסמת מפתח (אפשר זהה), ופרטי "distinguished name"
(שם/ארגון/מדינה וכו') — לא קריטיים לתפקוד, רק מזהים את המנפיק.

## 2. רישום ה-SHA-1 של מפתח השחרור ב-Firebase

Google Sign-In (`google_sign_in`, ARCHITECTURE.md §2/§5) בודק את חתימת ה-APK
מול הרישום ב-Firebase — APK שחתום במפתח שחרור שה-SHA-1 שלו לא רשום ייכשל
בכניסה.

1. חילוץ ה-SHA-1:
   ```bash
   keytool -list -v -keystore hebrewcalendar-release.jks -alias hebrewcalendar
   ```
   (חפש את השורה `SHA1:`).
2. Firebase Console -> Project Settings -> האפליקציה
   `il.co.natanor.kalfapp.hebrewcalendar` -> "Add fingerprint" -> להדביק את
   ה-SHA-1.
3. להוריד מחדש את `google-services.json` המעודכן (אם עובדים גם עם עותק מקומי
   — הקובץ עצמו ב-`.gitignore`, ראה RULES.md §5.4) ולוודא שהעותק שנכתב
   כ-secret `GOOGLE_SERVICES_JSON` (סעיף 3) הוא הגרסה המעודכנת.

## 3. הוספת ה-GitHub Secrets

ב-GitHub: Settings -> Secrets and variables -> Actions -> "New repository
secret", עבור כל אחד מהבאים (נצרכים ע"י `.github/workflows/release.yml`):

| Secret | ערך |
|---|---|
| `KEYSTORE_BASE64` | פלט `base64 -w0 hebrewcalendar-release.jks` (קידוד ה-keystore לטקסט) |
| `KEYSTORE_PASSWORD` | סיסמת ה-keystore מסעיף 1 |
| `KEY_ALIAS` | `hebrewcalendar` (או הכינוי שנבחר בסעיף 1) |
| `KEY_PASSWORD` | סיסמת המפתח מסעיף 1 |
| `GOOGLE_SERVICES_JSON` | תוכן `google-services.json` המלא (ראה סעיף 2) |
| `GOOGLE_PLAY_KEY` | ה-JSON של ה-Service Account של Google Play. אותו מפתח של PowerWatch, אחרי שנותנים לו הרשאה לאפליקציה הזו (סעיף 6). נדרש רק להעלאה ל-Play (`track` שונה מ-`none`) |

```bash
base64 -w0 hebrewcalendar-release.jks > keystore-base64.txt
# להדביק את תוכן keystore-base64.txt כערך של KEYSTORE_BASE64, ואז למחוק את הקובץ
```

### בנייה חתומה מקומית (ללא ה-workflow)

אם רוצים `flutter build appbundle --release`/`flutter build apk --release`
ישירות במחשב מקומי (עם Android SDK מותקן — לא זמין בסביבת סוכן זו, ראה
`docs/LESSONS.md`), ליצור `android/key.properties` (בגיטיגנור, RULES.md
§5.4 — לעולם לא להעלות לריפו) בפורמט הבא, לפני שהריצה:

```properties
storeFile=/נתיב/מוחלט/או/יחסי/ל-android/hebrewcalendar-release.jks
storePassword=<סיסמת ה-keystore>
keyAlias=hebrewcalendar
keyPassword=<סיסמת המפתח>
```

`android/app/build.gradle.kts`'s `hasReleaseSigning` קורא את הקובץ הזה
אוטומטית ומחליף את חתימת ה-debug בחתימת השחרור האמיתית — בלי הקובץ, כל בנייה
(כולל CI הרגיל) ממשיכה לחתום עם `debug.keystore` המחויב בריפו, כרגיל.

## 4. הרצת workflow השחרור

`.github/workflows/release.yml` הוא `workflow_dispatch` בלבד. הוא לא רץ
אוטומטית על push או PR, בניגוד ל-`ci.yml`.

1. GitHub ← טאב Actions ← "Release" ← "Run workflow", מה-branch הרצוי
   (בדרך כלל `main`), ובוחרים:
   - **track:** לאן להעלות את הגרסה.
     - `none`: רק בונה את ה-AAB, בלי העלאה.
     - `internal`: בדיקה פנימית.
     - `alpha`: closed testing.
     - `beta`: open testing.
     - `production`: הפצה ציבורית.
   - **rollout:** רלוונטי רק ל-`production`. זה החלק מהמשתמשים שיקבלו את
     הגרסה, למשל `0.1` = ‏10%. ערך `1` משחרר לכולם.
   - **draft:** מעלה את הגרסה כטיוטה, שמשחררים ידנית מה-Console. ב-internal
     **לא נדרש**: ב-2026-10-09 גרסה 8 עלתה עם `completed` כשהאפליקציה עוד
     הייתה בסטטוס טיוטה. ייתכן שיידרש ב-tracks אחרים, עד ה-review הראשון.
2. מה ה-workflow עושה:
   - מוודא שכל הסודות קיימים. `GOOGLE_PLAY_KEY` נבדק רק כשיש העלאה.
   - כותב את `google-services.json`, ונכשל אם הוא לא מכיל את
     `il.co.natanor.kalfapp.hebrewcalendar`.
   - מפענח את ה-keystore וכותב `android/key.properties`.
   - מחשב `versionName` ו-`versionCode` (סעיף 5) ובונה App Bundle חתום.
3. ה-AAB תמיד נשמר כ-artifact: Actions ← ההרצה ← Artifacts ←
   `hebrew-calendar-release-aab` (נשמר 7 ימים). כש-`track` שונה מ-`none`, הוא גם מועלה
   ל-Play עם הערות הגרסה מ-`distribution/whatsnew/`. צריך לעדכן אותן לפני כל
   שחרור, בעברית (`whatsnew-iw-IL`) ובאנגלית (`whatsnew-en-US`), עד 500 תווים
   כל אחת.
4. **production משוחרר רק אחרי אישור מפורש של בעל המוצר, בכל גרסה בנפרד.**
5. בסיום, בהצלחה או בכישלון, ה-workflow מוחק מה-runner את הקבצים
   המפוענחים: `release.keystore`, `key.properties` ו-`google-services.json`.

## 5. גרסאות (versionName / versionCode)

- `versionName` (מספר הגרסה שהמשתמש רואה) נגזר ישירות מ-`pubspec.yaml`'s
  `version:` (החלק שלפני ה-`+`) — לעדכן שם לפני הרצת release עבור גרסה
  חדשה משמעותית (RULES.md-style semantic versioning).
- `versionCode` (המספר הפנימי ש-Play Console דורש שיעלה בכל העלאה) הוא
  מספר ה-build ב-`pubspec.yaml` (החלק אחרי ה-`+`) **בתוספת** מספר ריצת
  ה-workflow (`GITHUB_RUN_NUMBER`) — כך שאין צורך לערוך את `pubspec.yaml`
  לפני כל הרצה כדי לקבל `versionCode` עולה; מריצים "Run workflow" שוב וזה
  עולה אוטומטית.

## 6. Play Console: הגדרה חד-פעמית והעלאה ראשונה

1. **Create app** ב-Play Console, תחת אותו חשבון מפתח של PowerWatch.
2. מריצים את ה-workflow עם `track = none` ומורידים את ה-AAB מה-artifact.
3. **ההעלאה הראשונה ידנית** (ה-API של Google לא מאפשר אותה): Testing ←
   Internal testing ← Create new release ← מעלים את ה-AAB. בהעלאה הזו
   Google מגדירה את Play App Signing.
4. **SHA-1 של Play App Signing:** אוטומטי. מריצים את workflow ‏**"Register signing SHAs in Firebase"** (`firebase-shas.yml`) אחרי שיש גרסה ב-track. השלבים הידניים למטה נשארים כגיבוי. דרישות: לחשבון השירות של `GOOGLE_PLAY_KEY` יש תפקיד **Firebase Admin** בפרויקט `hebrewcalendar-68363` (ניתן ב-2026-10-09), וגישה לאפליקציה ב-Play Console. ידנית: הוא שונה מה-SHA-1 של מפתח ההעלאה. מעתיקים
   אותו מ-Setup ← App signing ← "App signing key certificate", ומוסיפים אותו
   לאפליקציה ב-Firebase (Add fingerprint). אחר כך מורידים `google-services.json`
   מחדש ומעדכנים את ה-secret. בלי השלב הזה, Google Sign-In ייכשל בגרסאות
   שמותקנות מ-Play.
5. **Users and permissions** ← מזמינים את המייל של ה-Service Account
   (`client_email` ב-JSON של `GOOGLE_PLAY_KEY`) עם הרשאות Release לאפליקציה
   הזו.
6. מכאן כל העלאה נעשית מה-workflow. מסלול השחרור הוא internal ← closed
   (`alpha`) ← production, לפי `docs/TESTING_AND_DEPLOY.md` §דיפלוי.
7. **בדיקה סגורה:** בחשבון מפתח אישי שנפתח אחרי 13.11.2023, Google דורשת
   closed testing עם 12 בודקים לפחות, במשך 14 ימים רצופים, לפני הגשה
   ל-production.

## 7. אימות OAuth scope (`calendar.events`) לפני הפצה ציבורית

הסנכרון עם Google Calendar (ARCHITECTURE.md §5) מבקש את ה-scope
`https://www.googleapis.com/auth/calendar.events` דרך Google Sign-In. זהו
**sensitive scope** לפי מדיניות Google — **חובה** OAuth consent screen
verification של Google לפני שהאפליקציה זמינה למשתמשים שאינם test users
רשומים:

1. Google Cloud Console -> the project behind the Firebase project -> APIs
   & Services -> OAuth consent screen.
2. למלא את כל הפרטים הנדרשים (privacy policy URL, application homepage,
   הסבר שימוש ב-scope) ולשלוח ל-verification.
3. **עד לאישור:** האפליקציה יכולה לרוץ רק עבור "test users" רשומים במפורש
   במסך ה-consent (עד 100), או להישאר ב-Play Console internal/closed
   testing עם אותם test users — **לא** לקדם ל-production לפני שה-verification
   אושר, אחרת משתמשים חדשים ייתקלו במסך אזהרה/חסימה של Google בכניסה.
4. תהליך ה-verification יכול לקחת מספר ימים עד שבועות — לתכנן זמן מראש
   לפני תאריך שחרור ציבורי מתוכנן.
