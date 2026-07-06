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
  isRecurring                   # נגזר מ-recurrence.type (M3a) — לשאילתת "כל האירועים החוזרים"
  reminders [{minutesBefore, method}]
  participantUids[], participantEmails[], invitesStatus{}
  attachments [{storagePath, name, size, mime}]
  googleSync {googleEventId, etag, lastSyncedAt, dirty}
```
- **עיקרון חזרתיות עברית:** לא משכפלים מסמכים; מופעים (instances) מחושבים בזמן ריצה
  מ-`RecurrenceRule` דרך `HebrewDateEngine`, וממומשים (materialized) רק לחריגים ולסנכרון גוגל.
- אינדקסים: `events` על (`ownerUid`,`gregorianStart`), על (`ownerUid`,`isRecurring`,`gregorianStart`)
  ועל (`ownerUid`,`isRecurring`) — ראה M3a למטה — וכן על (`participantUids` array-contains, `gregorianStart`).
- **מדיניות חזרתיות (M3a, `lib/domain/event/recurrence_expander.dart`):**
  - **מיפוי אדר** (`hebrewYearly` בלבד): בסיס באדר (שנה לא מעוברת) או אדר א׳ — חוזר באדר א׳
    בשנה מעוברת ובאדר רגיל בשנה לא מעוברת; בסיס באדר ב׳ — חוזר באדר ב׳ בשנה מעוברת
    ובאדר רגיל בשנה לא מעוברת.
  - **מדיניות יום 30** (`hebrewYearly` ו-`hebrewMonthly`): אירוע שעוגן ביום 30 (חשוון/כסלו)
    נופל על היום האחרון של החודש (29) בשנה/בחודש שבו החודש קצר — לא מדלג, לא "גולש"
    לחודש הבא, ולא יורה פעמיים; תמיד מופע אחד בדיוק לכל חודש/שנה עברית.
  - `weekly`/`daily` מתקדמים במספר קבוע של ימים לועזיים (חישוב דרך `HebrewDateEngine`).
  - בכל הסוגים: אין מופע לפני תאריך הבסיס, `until` הוא גבול עליון כולל, ותאריכים
    ב-`exceptions` מדולגים.

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
- **מימוש (M4, `lib/domain/notifications/`+`lib/data/notifications/`+`lib/features/notifications/`):**
  הפרדה תלת-שכבתית קפדנית לנבדקות מלאה:
  1. **מתכנן טהור** (`reminder_planner.dart`, `planReminders`) — Dart טהור, ללא Flutter/פלאגין:
     מקבל רשימת `EventOccurrence` (כבר מורחבים ע"י `recurrence_expander.dart`), `now` ואופק
     תכנון (ברירת מחדל 60 יום), ומחזיר `List<PlannedNotification>` ממוין לפי `fireAt`.
     חוקים: כל `minutesBefore` ב-`Event.reminderMinutesBefore` מייצר תזכורת אחת; תזכורת
     שזמנה כבר עבר מדולגת; תזכורת מעבר לאופק מדולגת; אירוע יום שלם (`allDay`/`startTime==null`)
     "יורה" ב-09:00 שעון מקומי ביום המופע פחות `minutesBefore`; התוצאה מוגבלת ל-60 התזכורות
     הקרובות ביותר (תקציב exact-alarm מעשי באנדרואיד). `stableId` נגזר מ-hash דטרמיניסטי
     (FNV-1a על event id + תאריך מופע + minutesBefore) — לא מ-`Object.hash`/`hashCode`, שאינם
     מובטחים יציבים בין הרצות אפליקציה (ראה LESSONS.md).
  2. **מתאם פלאגין דק** (`local_notification_scheduler.dart`, `LocalNotificationScheduler`
     מממש `NotificationScheduler` המופשט שב-`lib/domain/notifications/`) — עוטף
     `flutter_local_notifications`: ערוץ עברי יחיד (`reminders`/"תזכורות", שם מגיע מ-ARB
     בקונסטרוקציה), `zonedSchedule` עם `exactAllowWhileIdle` ונפילה חזרה ל-`inexactAllowWhileIdle`
     כשאין הרשאת exact alarm (לעולם לא קורס), אתחול אזור זמן דרך `flutter_timezone`. תזמון
     מבוסס-diff (`scheduled_notification_diff.dart`, טהור ונבדק בנפרד): מבטל רק מזהים שכבר
     לא בתוכנית, מתזמן רק חדשים/שהשתנו — לא cancelAll+reschedule מלא בכל ריענון. מפת
     "מה מתוזמן כרגע" (id -> חתימה) נשמרת ב-`shared_preferences`. הקובץ הזה עצמו **אינו**
     נבדק ביחידה ישירות (רק מיפוי לפלאגין) — כל קריאה לפלאגין עטופה כדי שלעולם לא תקריס,
     כולל בטסטי widget שאין בהם ערוץ פלאגין אמיתי.
  3. **אורקסטרטור** (`reminder_sync_service.dart`, `ReminderSyncService`) — מחבר
     `EventRepository.watchOccurrencesInRange(now, now+horizon)` (של המשתמש המחובר) ->
     debounce 500ms -> `planReminders` -> `NotificationScheduler.showScheduled`. ללא Riverpod/
     Flutter — נבדק ביחידה עם fakes (`InMemoryEventRepository`+`FakeNotificationScheduler`)
     בלבד. חיווט ה-Riverpod האמיתי (`reminder_providers.dart`): `reminderSyncServiceProvider`
     (autoDispose) מופעל מ-`CalendarShellScreen` כשמחוברים ומבוטל (subscription+כל תזכורת
     מתוזמנת) בהתנתקות (RULES.md §6). הרשאת התראות מתבקשת פעם אחת בלבד (דגל ב-
     `shared_preferences`, `ReminderPermissionController`), עם snackbar עברי אם נדחתה.
  - עורך האירועים: בורר תזכורת יחיד (`reminder_selector.dart`) הורחב מ-M2a
    (ללא/10/30/60 דקות) ל-ללא/בזמן האירוע (0)/10/30/60 דקות/יום לפני (1440 דקות).
    ריבוי תזכורות לאירוע נשאר מחוץ להיקף — ראה WISHLIST.md.
  - הרשאות אנדרואיד (`AndroidManifest.xml`): `POST_NOTIFICATIONS`+`RECEIVE_BOOT_COMPLETED`+
    `SCHEDULE_EXACT_ALARM` (לא `USE_EXACT_ALARM`, שדורש אישור/ביקורת Play Store) +
    `ScheduledNotificationReceiver`/`ScheduledNotificationBootReceiver` של הפלאגין כדי
    שתזכורות ישרדו אתחול מכשיר.

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
| M2 | אימות + CRUD (מפוצל) | **M2a** ✅: מודל דומיין `Event`/`RecurrenceRule`, ולידציה, `EventRepository` מופשט + מימוש בזיכרון, מסך עורך אירועים, שילוב עם תצוגת החודש — הכול ללא תלות ב-Firebase. **M2b** ✅: Google Sign-In (`firebase_auth`+`google_sign_in`), Firestore (`FirestoreEventRepository`), Security Rules כקוד (`firebase/`), שער אימות באפליקציה | ✅ |
| M3 | תצוגות + חזרתיות | **M3a** ✅: מנוע הרחבת חזרתיות (`recurrence_expander.dart`), שילוב ב-repositories (`EventOccurrence`), עורך אירועים (בורר חזרתיות + "עד תאריך"), מחיקת מופע יחיד/כל הסדרה. **M3b** ✅: `EventRepository.watchOccurrencesInRange` (טווח תאריכים שרירותי, לא רק חודש), תצוגות שבוע/יום/אג'נדה, `CalendarShellScreen` עם בורר תצוגה + כפתור "היום" | ✅ |
| M4 | תזכורות | התראות מקומיות מדויקות, ניהול הרשאות | ✅ |
| M5 | סנכרון גוגל | דו-כיווני מלא כמתואר ב-§5 | ◻ |
| M6 | שיתוף והעשרה | משתתפים+הזמנות (FCM), קבצים מצורפים, מיקום | ◻ |
| M7 | גיבוי, ליטוש, שחרור | יצוא/שחזור, בדיקות קצה, חתימה, Play Store | ◻ |

כל שלב נסגר רק כשהטסטים שלו עוברים והתיעוד (INDEX/PROGRESS) מעודכן.
