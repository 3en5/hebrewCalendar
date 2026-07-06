# ארכיטקטורה ותוכנית — HebrewCalendar

**זו התוכנית המחייבת.** שינוי בה מחייב אישור משתמש (ראה RULES.md §1).

## 1. חזון
יומן אנדרואיד בסגנון Google Calendar שבו התאריך העברי הוא ציר הזמן הראשי.
המשתמש רואה חודשים עבריים (תשרי, חשוון...), קובע אירועים על תאריך עברי,
ואירועים חוזרים חוזרים לפי הלוח העברי (למשל: כל י' בטבת, יום נישואין עברי, אזכרה).
התאריך הלועזי מוצג כמשני. סנכרון דו-כיווני מלא עם Google Calendar.

## 2. סטאק והחלטות שהתקבלו
| נושא | החלטה | תאריך |
|---|---|---|
| פלטפורמה | Flutter, יעד ראשון Android | 2026-07-06 |
| Backend | Firebase: Auth, Firestore, Storage, FCM, Cloud Functions | 2026-07-06 |
| אימות | Google Sign-In בלבד | 2026-07-06 |
| סנכרון Google Calendar | דו-כיווני מלא | 2026-07-06 |
| State management | Riverpod (autoDispose כברירת מחדל) | 2026-07-06 |
| חישובי לוח עברי | חבילת `kosher_dart` + שכבת עטיפה משלנו (`HebrewDateEngine`) | 2026-07-06 |
| תוכן דתי (חגים, זמנים, פרשה) | לא בליבה — ב-WISHLIST | 2026-07-06 |
| UI | עברית RTL, סגנון Material 3 בהשראת Google Calendar | 2026-07-06 |

## 3. שכבות
```
lib/
  core/            # theme, dimens, routing, utils, widgets משותפים
  domain/          # ישויות טהורות + לוגיקה: HebrewDate, Event, RecurrenceRule
  data/            # Firestore repos, Google Calendar sync, local cache
  features/
    auth/          # כניסה עם גוגל, מסך פתיחה
    calendar/      # תצוגות חודש/שבוע/יום/אג'נדה
    event_editor/  # יצירה/עריכה: כותרת, תיאור, מיקום, משתתפים, קבצים, תזכורות, חזרתיות
    settings/      # הגדרות, גיבוי/שחזור, ניהול סנכרון
  l10n/            # מחרוזות ARB (עברית ראשית)
```
- **domain** לא תלוי ב-Flutter/Firebase — ניתן לבדיקה טהורה.
- **data** ממומש מול ממשקים (abstract repositories) מה-domain.
- **features** צורכות providers של Riverpod בלבד; אין גישה ישירה ל-Firestore מ-widgets.

## 4. מודל הנתונים (Firestore)
```
users/{uid}                     # פרופיל, הגדרות, מצב סנכרון
users/{uid}/calendars/{calId}   # יומנים של המשתמש (ברירת מחדל: "אישי")
events/{eventId}                # אוסף שורש — כדי לאפשר שיתוף בין משתמשים
  ownerUid, calendarId
  title, description, location (טקסט + lat/lng אופציונלי)
  hebrewDate {year, month, day} # מקור האמת לזמן האירוע
  gregorianStart, gregorianEnd  # נגזר, לשאילתות וסנכרון
  allDay, startTime, endTime
  recurrence {type: none|hebrewYearly|hebrewMonthly|weekly|daily, until, exceptions[]}
  reminders [{minutesBefore, method}]
  participantUids[], participantEmails[], invitesStatus{}
  attachments [{storagePath, name, size, mime}]
  googleSync {googleEventId, etag, lastSyncedAt, dirty}
```
- **עיקרון חזרתיות עברית:** לא משכפלים מסמכים; מופעים (instances) מחושבים בזמן ריצה
  מ-`RecurrenceRule` דרך `HebrewDateEngine`, וממומשים (materialized) רק לחריגים ולסנכרון גוגל.
- אינדקסים: `events` על (`ownerUid`,`gregorianStart`) ועל (`participantUids` array-contains, `gregorianStart`).

## 5. סנכרון Google Calendar (דו-כיווני)
- OAuth scope: `calendar.events` דרך אותו Google Sign-In.
- **יצוא:** כל אירוע אפליקציה נכתב כאירוע גוגל בתאריך הלועזי הנגזר; אירוע חוזר עברי
  מיוצא כמופעים בודדים לחלון מתגלגל (24 חודשים קדימה), עם `extendedProperties`
  שמסמנות את מזהה האירוע שלנו.
- **יבוא:** sync tokens (incremental sync) של Google Calendar API; אירועי גוגל נשמרים
  עם ייצוג עברי נגזר ומסומנים כ-`source: google`.
- **קונפליקטים:** last-write-wins לפי updated timestamp; ETag למניעת דריסה עיוורת;
  לולאות נמנעות ע"י extendedProperties + השוואת חתימת תוכן.
- מנוע הסנכרון רץ כ-service באפליקציה (WorkManager תקופתי + טריגר בפתיחה) —
  לא ב-Cloud Functions, כדי שהטוקנים יישארו במכשיר.

## 6. תזכורות והתראות
- תזכורות מקומיות: `flutter_local_notifications` + תזמון מדויק (exact alarms עם הרשאה).
- הזמנות למשתתפים ועדכוני אירוע משותף: FCM דרך Cloud Function שמאזינה לשינויים ב-events.

## 7. גיבוי ושחזור
- הנתונים חיים ב-Firestore (גיבוי מובנה). בנוסף: יצוא ידני לקובץ JSON מוצפן ל-Storage/מכשיר,
  ושחזור ממנו במסך ההגדרות.

## 8. אבטחה
ראה RULES.md §5. בנוסף: App Check מופעל; Rules נבדקות עם Firebase Emulator בטסטים.

## 9. אבני דרך (Milestones)
| # | שלב | תוצר | סטטוס |
|---|---|---|---|
| M0 | תשתית | פרויקט Flutter, מבנה תיקיות, theme+dimens, CI, טסט ראשון | ⏳ |
| M1 | מנוע עברי + תצוגת חודש | HebrewDateEngine עטוף ונבדק, גריד חודש עברי RTL, ניווט חודשים | ◻ |
| M2 | אימות + CRUD (מפוצל) | **M2a** ✅: מודל דומיין `Event`/`RecurrenceRule`, ולידציה, `EventRepository` מופשט + מימוש בזיכרון, מסך עורך אירועים, שילוב עם תצוגת החודש — הכול ללא תלות ב-Firebase. **M2b** ◻ (ממתין לקונפיגורציית Firebase מהמשתמש): Google Sign-In, Firestore, Security Rules, מימוש `EventRepository` מול Firestore | חלקי |
| M3 | תצוגות + חזרתיות | שבוע/יום/אג'נדה, אירועים חוזרים עבריים כולל חריגים | ◻ |
| M4 | תזכורות | התראות מקומיות מדויקות, ניהול הרשאות | ◻ |
| M5 | סנכרון גוגל | דו-כיווני מלא כמתואר ב-§5 | ◻ |
| M6 | שיתוף והעשרה | משתתפים+הזמנות (FCM), קבצים מצורפים, מיקום | ◻ |
| M7 | גיבוי, ליטוש, שחרור | יצוא/שחזור, בדיקות קצה, חתימה, Play Store | ◻ |

כל שלב נסגר רק כשהטסטים שלו עוברים והתיעוד (INDEX/PROGRESS) מעודכן.
