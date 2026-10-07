# שחרור גרסאות ל-Google Play

## הגדרה חד-פעמית

### 1. יצירת מפתח העלאה (upload keystore)
מריצים על המחשב שלך, לא בריפו:

```bash
keytool -genkey -v -keystore hebrewcalendar-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 hebrewcalendar-upload.jks > keystore.b64   # ב-macOS: base64 -i hebrewcalendar-upload.jks
```

שמור את קובץ ה-`.jks` ואת הסיסמאות במקום בטוח, למשל במנהל סיסמאות. אל תעלה אותם לגיט.

### 2. GitHub Secrets
ב-Settings → Secrets and variables → Actions של הריפו:

| Secret | ערך |
|---|---|
| `KEYSTORE_BASE64` | התוכן של `keystore.b64` |
| `KEY_STORE_PASSWORD` | סיסמת ה-keystore |
| `KEY_PASSWORD` | סיסמת המפתח (בדרך כלל זהה) |
| `KEY_ALIAS` | `upload` |
| `GOOGLE_PLAY_KEY` | ה-JSON של ה-Service Account. אותו קובץ כמו ב-PowerWatch |

### 3. Play Console
1. **Create app** בשם "לוח עברי", בשפת ברירת מחדל עברית. בחר שהאפליקציה חינמית.
2. מריצים את workflow השחרור ידנית עם `track = none`, ומורידים את ה-AAB מה-artifacts.
3. מעלים את ה-AAB ידנית ל-Internal testing. בהעלאה הזו Google מגדירה את Play App Signing.
4. תחת **Users and permissions**, נותנים ל-Service Account הרשאת Release לאפליקציה הזו.

## התהליך השוטף

| פעולה | תוצאה |
|---|---|
| push לכל branch | CI: format, analyze, tests, build |
| תג `vX.Y.Z` | בנייה חתומה והעלאה ל-**internal** |
| הרצה ידנית (Actions → Release to Google Play) | בחירת track: internal, alpha (closed), beta (open) או production |

- **production:** רק בהרצה ידנית, ורק אחרי אישור מפורש של בעל המוצר. ה-rollout מוגדר כחלק מהמשתמשים, ברירת המחדל 10%.
- **draft:** עד שהגרסה הראשונה של האפליקציה מאושרת ב-review, Google מקבלת רק העלאות במצב draft. צריך לסמן `draft`.
- **versionCode:** נקבע אוטומטית כ-`100 + מספר הריצה`. **versionName:** נלקח מהתג, או מ-`pubspec.yaml` בהרצה ידנית.
- **הערות גרסה:** `distribution/whatsnew/whatsnew-iw-IL` ו-`whatsnew-en-US`, עם עדכון לפני כל שחרור.
