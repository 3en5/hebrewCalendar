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

`.github/workflows/release.yml` הוא `workflow_dispatch` בלבד — לא רץ
אוטומטית על push/PR (בניגוד ל-`ci.yml`).

1. GitHub -> טאב Actions -> "Release" -> "Run workflow" -> להריץ מה-branch
   הרצוי (בד"כ `main`).
2. ה-workflow: מוודא שכל חמשת הסודות קיימים, כותב `google-services.json`,
   מפענח את ה-keystore ל-`android/release.keystore`, כותב
   `android/key.properties` (נקרא ע"י `android/app/build.gradle.kts`'s
   `hasReleaseSigning`), מחשב `versionName`/`versionCode` (ראה סעיף 5),
   ומריץ `flutter build appbundle --release`.
3. בסיום: קובץ `app-release.aab` זמין כ-artifact בעמוד ההרצה (Actions -> ההרצה
   -> Artifacts -> `hebrew-calendar-release-aab`).
4. ה-workflow מוחק את הקבצים המפוענחים (`release.keystore`/`key.properties`/
   `google-services.json`) מה-runner בסיום, בהצלחה או בכישלון.

## 5. גרסאות (versionName / versionCode)

- `versionName` (מספר הגרסה שהמשתמש רואה) נגזר ישירות מ-`pubspec.yaml`'s
  `version:` (החלק שלפני ה-`+`) — לעדכן שם לפני הרצת release עבור גרסה
  חדשה משמעותית (RULES.md-style semantic versioning).
- `versionCode` (המספר הפנימי ש-Play Console דורש שיעלה בכל העלאה) הוא
  מספר ה-build ב-`pubspec.yaml` (החלק אחרי ה-`+`) **בתוספת** מספר ריצת
  ה-workflow (`GITHUB_RUN_NUMBER`) — כך שאין צורך לערוך את `pubspec.yaml`
  לפני כל הרצה כדי לקבל `versionCode` עולה; מריצים "Run workflow" שוב וזה
  עולה אוטומטית.

## 6. העלאה ל-Play Console

1. Play Console -> האפליקציה -> Release -> (הבחירה בהתאם למסלול, ראה
   `docs/TESTING_AND_DEPLOY.md` §דיפלוי: **internal testing** לראשונה,
   אח"כ **closed testing**, ורק לבסוף **production**).
2. "Create new release" -> להעלות את `app-release.aab` שהורד מה-artifact.
3. למלא release notes (עברית).
4. **לפני קידום ל-production:** לבדוק crash-free rate ב-Crashlytics
   (`docs/TESTING_AND_DEPLOY.md` §5 — Crashlytics עצמו נדחה ל-WISHLIST כרגע;
   עד שיופעל, להסתמך על בדיקה ידנית + משוב מבודקי ה-internal/closed track).
5. Review -> Rollout.

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
