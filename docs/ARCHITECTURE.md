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
| חגים ופרשת השבוע | **הוכנסו לתוכנית** כשלב M8 (בקשת משתמש). זמני היום, ספירת העומר וסליחות נשארים ב-WISHLIST | 2026-10-11 |
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
  source                        # 'app' | 'google' (M5a) — מקור האירוע
  googleSync {googleEventId, etag, lastSyncedAt, dirty}
  googleInstanceSync            # מפה: מפתח מופע -> {googleEventId, etag, lastSyncedAt, dirty} (M5a)
```
- **M5a — `googleSync` מול `googleInstanceSync`:** `googleSync` (כפי שהוגדר במקור) הוא המיפוי היחיד
  לגוגל של אירוע **לא**-חוזר בלבד. אירוע חוזר מיוצא כמופעים מרובים (§5), ואין לו מיפוי יחיד — עבורו
  `googleSync.dirty`/`lastSyncedAt` עדיין חלים על הסדרה כולה ("יש עריכה ממתינה לדחיפה"), אבל
  `googleEventId`/`etag` נשארים ריקים; כל מופע ממופה בנפרד תחת `googleInstanceSync[occurrenceKey]`
  (המפתח מ-`domain/sync/occurrence_key.dart`). זו הרחבה של המבנה ב-M2b/M3a, לא סתירה לו — נדרשה כי
  מסמך יחיד לא יכול להחזיק מיפוי 1:1 לכמה אירועי גוגל בו-זמנית.
- **users/{uid}** מקבל גם `googleSyncEnabled`/`googleSyncToken`/`googleLastSyncedAt` (M5a —
  `domain/sync/sync_settings_store.dart`), ו-`users/{uid}/pendingGoogleDeletions/{eventId}` הוא
  אוסף-משנה חדש: תור מחיקות מקומיות שממתינות לניקוי מרוחק (§5).
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
  מיוצא כמופעים בודדים לחלון מתגלגל (5 שנים קדימה לשנתי/חודשי, 2 לשבועי/יומי), עם `extendedProperties`
  שמסמנות את מזהה האירוע שלנו.
- **יבוא:** sync tokens (incremental sync) של Google Calendar API; אירועי גוגל נשמרים
  עם ייצוג עברי נגזר ומסומנים כ-`source: google`.
- **קונפליקטים:** last-write-wins לפי updated timestamp; ETag למניעת דריסה עיוורת;
  לולאות נמנעות ע"י extendedProperties + השוואת חתימת תוכן.
- מנוע הסנכרון רץ כ-service באפליקציה (WorkManager תקופתי + טריגר בפתיחה) —
  לא ב-Cloud Functions, כדי שהטוקנים יישארו במכשיר.
- **מימוש M5a+M5b (טריגרים בפורגראונד + סנכרון תקופתי ברקע דרך WorkManager):**
  פיצול לפי אחריות (RULES.md §2 — מנוע סנכרון מונוליתי היה חורג מ-500 שורות):
  1. **`lib/domain/sync/`** — טהור לגמרי (ללא Flutter/Firebase/googleapis): `sync_state.dart`
     (`GoogleSyncState`, `SyncStatus`), `remote_event_snapshot.dart` (`RemoteEventSnapshot` — DTO
     קריאה, ללא טיפוסי googleapis), `sync_action.dart` (`SyncAction` sealed class:
     `Create/Update/DeleteRemoteAction`, `Create/Update/DeleteLocalAction`, `SkipAction`),
     `export_candidate.dart` (`ExportCandidate`/`StaleExportInstance`/`PendingGoogleDeletion`),
     `occurrence_key.dart` (`occurrenceKeyFor` — מפתח דטרמיניסטי, גם ל-`hebcalOccurrence` וגם
     למפתח ב-`googleInstanceSync`), ו-**`sync_planner.dart`** — הליבה: `planExportActions`
     (החלטת create/update/delete ליצוא, כולל "stale instances" של סדרה חוזרת),
     `planImportActions` (last-write-wins לפי `updated`, דילוג echo של יצוא עצמי דרך
     `RemoteEventSnapshot.isOwnExport`, מחיקה משני הכיוונים), ו-`resolveConflict` (פתרון אחרי
     412 — אותה השוואת last-write-wins, אך מחליטה בין "לדחוף שוב עם ה-etag הטרי" ל"לאמץ את
     המרוחק"). כל היגיון הקונפליקטים חי כאן בלבד ונבדק ביחידה במלואו (task brief M5a §5).
  2. **`lib/data/sync/`** — האורקסטרציה/האינטגרציה: `google_calendar_api.dart` (ממשק מופשט
     `GoogleCalendarApi` + DTOs עצמאיים `GoogleEventWrite`/`GoogleEventsPage`, לא googleapis —
     כדי שיהיה fakeable ללא רשת), `google_calendar_api_impl.dart` (מימוש אמיתי מול Calendar v3
     REST ישירות דרך `package:http`, **לא** `package:googleapis`/`googleapis_auth` — ראה
     `docs/LESSONS.md`), `event_sync_mapper.dart` (בניית `GoogleEventWrite` מ-`Event`+תאריך מופע),
     `sync_import_pass.dart`/`sync_export_pass.dart` (חצי-משיכה/חצי-דחיפה, שכל אחד מהם קורא
     ל-`sync_planner.dart` ומבצע בפועל דרך `GoogleCalendarApi`+`EventRepository`),
     `sync_engine.dart` (`SyncEngine.runSync` — האורקסטרטור: טוען הגדרות, מדלג אם מנוטרל, מריץ
     import ואז export, שומר syncToken/lastSyncedAt, הופך חריגה ל-`SyncRunResult.failure`),
     ו-`firestore_sync_settings_store.dart`/`in_memory_sync_settings_store.dart` (מימוש
     `SyncSettingsStore`).
  3. **`EventRepository`** (§4/M2a) קיבל שיטות תמיכת-סנכרון: `getAllForSync`, `getByGoogleEventId`,
     `updateSyncState` (רושם מצב סנכרון **בלי** לסמן dirty מחדש — בניגוד ל-`create`/`update`
     הרגילים, שממשיכים לסמן `googleSync.dirty=true` בכל עריכה מקומית — hook בשכבת ה-repository,
     לא ב-UI, כנדרש), `takePendingGoogleDeletions` (תור שמתרוקן פעם אחת), `upsertFromGoogle`
     (יצירה/עדכון מקומי ממקור גוגל, `source: google`), ו-`applyRemoteDelete` (מחיקה שמקורה
     בגוגל — לא מתעד `PendingGoogleDeletion`, בניגוד ל-`delete` הרגיל). ב-Firestore, תור
     המחיקות הממתינות נשמר בעמידות (`users/{uid}/pendingGoogleDeletions`) ולא רק בזיכרון,
     כי M5a הוא foreground-only (ראה LESSONS.md למגבלה שנובעת מכך).
  4. **חלון יצוא מתגלגל**: 5 שנים (1826 ימים) לסדרה שנתית/חודשית, 2 שנים (730 ימים) לשבועית/יומית
     (בקשת בעלים, 2026-10-11), מ"עכשיו". **השלמה מתגלגלת:** בכל `runSync` סדרה שכבר יוצאה ולא
     נערכה מקבלת את המופעים החסרים עד סוף החלון, ברגע שהמופע החסר הראשון נכנס לשנה האחרונה
     של החלון (`_topUpRecurring` — יוצר בלבד; מופע שכבר רשום, גם אם נמחק ב-Google, לא נוצר שוב).
     אירוע חוזר
     מורחב למופעים בטווח הזה דרך `recurrence_expander.dart`'s `occurrencesForEventInRange` —
     **אותו** קוד הרחבה שמשמש את תצוגות היומן, כדי שמופעים שהמשתמש רואה בלוח יהיו בדיוק אלה
     שמיוצאים (כולל מדיניות מיפוי אדר ומדיניות יום 30, §4).
  5. **Dedup-by-extendedProperties**: בסנכרון מלא (ללא syncToken — ראשון, או אחרי 410),
     `SyncImportPass` בונה `ownExportsLookup` (מפתח `eventId|occurrenceKey` -> `googleEventId`+`etag`)
     מכל אירוע גוגל שנושא `hebcalEventId`/`hebcalOccurrence` שלנו. `SyncExportPass` בודק את
     ה-lookup הזה לפני שהוא יוצר יצוא חדש למופע ש"מצב הידוע" שלו ריק — כך אין יצוא כפול גם
     כשה-state המקומי אבד/התאפס.
  6. **הגדרות (`lib/features/settings/`)**: `google_sync_trigger_service.dart`
     (`GoogleSyncTriggerService`, בדומה ל-`reminder_sync_service.dart` — ללא Riverpod): טריגר
     פתיחת-אפליקציה (`triggerAppOpen`, מתוגבל לפעם ב-5 דקות) וטריגר עריכה מקומית (האזנה ל-
     `EventRepository.watchOccurrencesInRange` רחב, debounce 30 שניות). `enable()` מבקש את
     scope ה-`calendar.events` כ-incremental authorization (**לא** בזמן הכניסה — רק כשמפעילים
     סנכרון בהגדרות) דרך `GoogleCalendarApi.requestAccess`. `google_sync_providers.dart` מחווט
     את זה ל-Riverpod (בדומה ל-`reminder_providers.dart`), ו-`CalendarShellScreen` צופה
     ב-`googleSyncTriggerServiceProvider` (autoDispose, מבוטל בהתנתקות) כדי שהטריגרים יעבדו כל
     עוד המסך מוצג — לא רק כשמסך ההגדרות עצמו פתוח.
  7. **סנכרון תקופתי ברקע (M5b, `package:workmanager`)**: פוצל לשלוש אחריות נפרדות (RULES.md §2):
     - **`background_sync_runner.dart`** (`BackgroundSyncRunner`) — שכבת ההחלטה הטהורה (Riverpod/
       workmanager/Firebase-free, כל תלות מוזרקת כפונקציה/ממשק): בודק חתימה שקטה (`isSignedIn`,
       ללא הצגת UI), מצב מופעל/מנוטרל (`SyncSettingsStore`), מריץ מעבר סנכרון יחיד דרך
       `engineFactory` עם timeout קשיח (4 דקות ברירת מחדל), וממפה את התוצאה ל-`BackgroundSyncOutcome`
       (`success`/`permanentSkip`/`retry`) — הקונטרקט ש-WorkManager צריך (`true`=הצלחה/דילוג קבוע,
       `false`=דילוג זמני שכדאי לנסות שוב). נבדק ביחידה במלואו עם fakes.
     - **`background_sync_scheduler.dart`** (`BackgroundSyncScheduler` מופשט +
       `WorkmanagerBackgroundSyncScheduler`/`NoopBackgroundSyncScheduler`) — עטיפה דקה סביב
       `package:workmanager`'s `registerPeriodicTask`/`cancelByUniqueName` (אילוצי
       `NetworkType.connected`+`requiresBatteryNotLow`, `existingWorkPolicy: keep`, תדירות 6 שעות,
       ללא wakelocks כלל — ההסתמכות היחידה היא על אילוצי WorkManager עצמו). `google_sync_trigger_service.dart`
       מזריק אותו: `enable()`/`start()` (כשמופעל) רושמים; `disable()`/`stop()` (כשהיה מופעל) מבטלים.
     - **`background_sync_bootstrap.dart`** (`callbackDispatcher`, `@pragma('vm:entry-point')`) —
       נקודת הכניסה בפועל שנרשמת פעם אחת ב-`main.dart` (`Workmanager().initialize`, אנדרואיד
       בלבד — `kIsWeb`/`Platform.isAndroid`). רץ ב-isolate/מנוע Flutter נפרד וללא זיכרון משותף עם
       האפליקציה הראשית — בכל טיק: מאתחל Firebase (guard כפול-init), בודק `FirebaseAuth.instance.currentUser`
       (השהייה ניצולת חוצת-isolate של Firebase Auth), מאמת גוגל בשקט (`attemptLightweightAuthentication`
       + `authorizationHeaders(..., promptIfNecessary: false)` — **לעולם לא** מציג UI), ובונה
       `SyncEngine`/`FirestoreEventRepository`/`FirestoreSyncSettingsStore` חדשים לאותו `uid`. קובץ
       דק בכוונה (task brief M5b §2) — כל ההחלטה האמיתית ב-`BackgroundSyncRunner` הנבדק ביחידה; קובץ
       זה עצמו לא ניתן להרצה בפועל בסביבת הפיתוח הזו (אין Android SDK/emulator, ראה LESSONS.md).
     - **תיקוני אמינות נלווים** (RULES.md §2 — "reliability polish"): `sync_engine.dart` קיבל מנעול
       in-flight (`_inFlight`, מונע שתי ריצות בו-זמנית *באותו isolate/מופע* — לא הגנה חוצת-isolate,
       ראה תיעוד בקוד והלקח ב-LESSONS.md) וסיווג כשל-קבוע-מול-זמני (`SyncRunResult.permanent`: 401/403
       או `StateError` של היעדר חשבון/הרשאה -> קבוע; כל השאר -> זמני). `SyncSettingsStore` קיבל שדה
       `lastErrorMessage`/`saveLastError` (מתנקה בהצלחה, נשמר בכישלון) כדי שכישלון ריצת-רקע — הרצה
       ב-isolate נפרד בלי מאזין חי — עדיין יופיע במסך ההגדרות בפעם הבאה שהוא נטען
       (`google_sync_trigger_service.dart`'s `start()`). **כישלון קבוע לא מכבה את הסנכרון** — ההחלטה
       המכוונת: משאירים מופעל ומציגים שגיאה, כדי שהמשתמש ירגיש ויוכל להעניק הרשאה מחדש, במקום לאבד
       סנכרון רקע בשקט. `GoogleCalendarApiImpl` קיבל `allowInteractiveAuth` (ברירת מחדל `true`,
       `false` ב-instance של הרקע) כדי ש-`promptIfNecessary` יהיה נשלט ולא תמיד `true`.
     - **הגדרות UI**: שורת קריאה-בלבד תחת סעיף הסנכרון ("סנכרון ברקע: פעיל (כל 6 שעות)" / "כבוי"),
       נגזרת מאותו דגל מופעל/מנוטרל — אין מתג נפרד; תדירות ניתנת-להגדרה נרשמה ב-WISHLIST.md.
- **סטייה קטנה מהתוכנית המקורית:** לא נוספה תלות ב-`googleapis`/`googleapis_auth`/
  `extension_google_sign_in_as_googleapis_auth` — ראה `docs/LESSONS.md` להסבר המלא; זו בחירת
  מימוש (data layer), לא שינוי בתוכן/היקף ה-M5a עצמו.

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
- הנתונים חיים ב-Firestore (גיבוי מובנה). בנוסף: יצוא ידני לקובץ JSON, ושחזור
  ממנו במסך ההגדרות.
- **מימוש M7 (variant מקומי-לקובץ — הגרסה המבוססת-Storage נדחתה יחד עם M6/Blaze,
  ראה WISHLIST.md):**
  1. **`lib/domain/backup/backup_codec.dart`** — קידוד/פענוח טהור, ללא Flutter/
     Firebase: `encodeBackup`/`decodeBackup` ממירים `List<Event>` <-> מחרוזת JSON
     הכוללת `formatVersion` (`kBackupFormatVersion`, כרגע 1), `appVersion`
     ו-`createdAt`. מראה את אותו מבנה מפה כמו `lib/data/event_firestore_mapper.dart`
     (`hebrewDate`/`startTime`/`endTime`/`recurrence`/`googleSync`/
     `googleInstanceSync`), אך מנותק מטיפוסי `cloud_firestore`: כל `DateTime`
     מקודד כמחרוזת ISO 8601 (`toIso8601String`/`DateTime.parse`) במקום
     `Timestamp` — כך שלקובץ הזה יש אפס תלות Firebase/Flutter (כלל ה-domain,
     §3) והוא נבדק ביחידה במלואו בבידוד גמור. גרסת פורמט עתידית וגבוהה יותר
     מ-`kBackupFormatVersion` -> `BackupFormatVersionError` טיפוסי (לא סתם
     `FormatException`).
  2. **`lib/data/backup/backup_service.dart`** — `abstract class BackupService`
     (`exportToFile`/`shareBackup`/`importFromFile`, מה שמסך ההגדרות תלוי בו —
     נדרס ב-fake בטסט widget, אותו דפוס בדיוק כמו `NotificationScheduler`/
     `GoogleCalendarApi`, ראה LESSONS.md) ומימוש אמיתי `FileBackupService`:
     `exportToFile` שומר קובץ ישירות למיקום שהמשתמש בוחר (`file_picker`'s
     `saveFile`, שכותב את הבייטים בעצמו באנדרואיד/iOS), `shareBackup` פותח את
     ה-share sheet של המערכת (`share_plus`) עם אותו תוכן, ו-`importFromFile`
     מאפשר בחירת קובץ (`file_picker`'s `pickFiles(withData: true)`, קורא בייטים
     ישירות — תואם ל-scoped storage של אנדרואיד, ללא צורך בנתיב `dart:io`
     ישיר) ואז מפענח ומשחזר. `buildBackupJson`/`restoreEvents` (מעבר לממשק
     המופשט) הם החצי הטהור-יחסית שנבדק ביחידה בלי לגעת בפלאגין כלל (אותו
     עיקרון פיצול "ליבה נבדקת מול מתאם פלאגין דק" כמו M4/M5a — ראה §5/§6).
  3. **מדיניות שחזור: merge-by-id, לא "מחק והחלף":** אירוע שמזהה ה-`id` שלו
     בגיבוי תואם אירוע מקומי קיים נדרס במקום (`EventRepository.update`);
     כל אירוע אחר נוצר כחדש עם מזהה חדש לגמרי (`EventRepository.create`,
     שמתעלם תמיד מה-`id` שהתקבל — התנהגות מתועדת של הריפוזיטורי ממילא).
     שום אירוע קיים במכשיר **לא** נמחק, גם אם חסר בקובץ הגיבוי — זו האסטרטגיה
     הבטוחה ביותר: מחיקה אוטומטית לפי "חסר בגיבוי" הייתה עלולה למחוק בטעות
     אירועים שנוצרו אחרי שהגיבוי נלקח (לדוגמה שחזור גיבוי ישן בטעות). `create`/
     `update` כבר מסמנים `googleSync.dirty=true` בכל מקרה (repository hook,
     RULES.md §6) כך שסנכרון גוגל הבא דוחף מחדש כל אירוע ששוחזר בלי טיפול
     מיוחד.
  4. **הגדרות UI** (`lib/features/settings/presentation/widgets/backup_section.dart`):
     סעיף "גיבוי ושחזור" — כפתור ייצוא (+ אייקון שיתוף נפרד), כפתור שחזור עם
     דיאלוג אישור שמסביר את סמנטיקת ה-merge לפני שממשיכים, אינדיקציית התקדמות
     בזמן פעולה, וסנאקבר עברי בהצלחה/כישלון (כולל הודעה ייעודית לגרסת פורמט
     לא-נתמכת).
  5. **סטייה מהניסוח המקורי בסעיף זה:** אין הצפנת קובץ הגיבוי (הניסוח המקורי
     הזכיר "JSON מוצפן") — נרשם ל-WISHLIST.md כהרחבה עתידית; תקציר המשימה
     שהזמין את M7 בפועל ביקש רק וריאנט קובץ מקומי בלי דרישת הצפנה מפורשת.

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
| M5 | סנכרון גוגל | **M5a** ✅: מנוע סנכרון דו-כיווני מלא (`sync_planner.dart` טהור + `sync_engine.dart`/`GoogleCalendarApi`), טריגרים בפורגראונד בלבד (פתיחת אפליקציה + debounce אחרי עריכה מקומית), מסך הגדרות ראשון. **M5b** ✅: סנכרון תקופתי ברקע דרך WorkManager (`BackgroundSyncRunner`/`BackgroundSyncScheduler`/`callbackDispatcher`), מנעול in-flight + סיווג כשל קבוע/זמני ב-`SyncEngine`, שורת מצב סנכרון-ברקע במסך ההגדרות | ✅ |
| M6 | שיתוף והעשרה | **נדחה** (החלטת משתמש 2026-07-06, ראה WISHLIST — תלוי Blaze): משתתפים+הזמנות (FCM), קבצים מצורפים | נדחה |
| M7 | גיבוי, ליטוש, שחרור | ✅: יצוא/שחזור מקומי לקובץ (§7), חתימת שחרור אמיתית + ProGuard/R8 + workflow ידני עם העלאה ל-Google Play (track/rollout/draft, 2026-10-07), ליטוש (גרסה בהגדרות, error boundary גלובלי) | ✅ |
| M8 | חגים ופרשת השבוע | ראה §10. `JewishDayInfo` בשכבת domain (עוטף `kosher_dart`), הגדרת ארץ ישראל/חו״ל, תווית חג/פרשה בתא החודש ובכותרת פירוט היום, תגיות בפירוט היום | ✅ |
| M9 | עריכה ומחיקה לפי היקף | ראה §11. לאירוע חוזר עברי: "מופע זה בלבד" / "מופע זה והבאים אחריו" / "כל הסדרה" — גם בעריכה וגם במחיקה | ✅ |
| M10 | צבעים לאירועים | בחירת צבע (11 צבעי Google Calendar) בעורך, תצוגה בכל המסכים, סנכרון `colorId` דו-כיווני | ✅ |
| M11 | משתתפים וזימונים דרך Google | שדה משתתפים (מיילים) בעורך; הזימון נשלח על-ידי Google Calendar בסנכרון (`attendees`, `sendUpdates`), סטטוס אישור מוצג באפליקציה. בלי שרת ובלי Blaze — מחליף את חלק "משתתפים+הזמנות" של M6 | ✅ |
| M12 | מעבר לתאריך | כפתור היומן בסרגל: היום / תאריך עברי / תאריך לועזי — כל התצוגות קופצות ליום שנבחר | ✅ |
| M13 | חיפוש אירועים | חיפוש מילים בכותרת/תיאור/מיקום על העותק המקומי (cache) — בלי קריאות שרת, עובד גם offline; תוצאות לפי תאריך, הקשה קופצת ליום | ✅ |
| M14 | מיתוג KALFAPP | שפה עיצובית ושיווקית של משפחת KALFAPP (כמו PowerWatch): אייקון קווי בתכלת (בית + גלגל שיניים + דף לוח עם "א"), גופן Rubik, כחול KALFAPP, כותרת ממורכזת, כרטיס אירועים בתכלת, מסך "אודות" עם לוגו KALFAPP וקול אישי, טקסטים לחנות. השם נשאר "לוח עברי" | ✅ |

כל שלב נסגר רק כשהטסטים שלו עוברים והתיעוד (INDEX/PROGRESS) מעודכן.

## 10. חגים ופרשת השבוע (M8, נוסף 2026-10-11)
**מטרה:** כל יום ביומן מציג אוטומטית מה מיוחד בו לפי הלוח העברי — בלי שהמשתמש
יוסיף אירועים.

**מה מוצג:**
- חגים ומועדים (כולל חול המועד וערבי חג), צומות, ראש חודש, חנוכה ופורים.
- ימים לאומיים וימי זיכרון בישראל (יום השואה, יום הזיכרון, יום העצמאות, יום
  ירושלים) — כולל דחיות לפי היום בשבוע, כפי ש-`kosher_dart` מחשב.
- פרשת השבוע בכל שבת (כולל פרשות מחוברות ושבתות מיוחדות כשרלוונטי).

**הגדרה:** ארץ ישראל / חו״ל (ברירת מחדל: ארץ ישראל) — משפיעה על יום טוב שני
ועל סדר הפרשות. נשמרת במכשיר (`SharedPreferences`) — היא מתארת איפה המשתמש
נמצא, לא את הנתונים שלו, ולכן לא מסונכרנת.

**ארכיטקטורה:**
- `lib/domain/hebrew_date/jewish_day_info.dart` — שירות טהור: `HebrewDate` →
  רשימת תוויות (סוג: חג / צום / ראש חודש / יום לאומי / פרשה + שם בעברית). זה
  הקובץ השני (אחרי `hebrew_date_engine.dart`) שמותר לו לייבא `kosher_dart`;
  שאר הקוד רואה רק את הטיפוסים שלנו.
- Provider ב-Riverpod שמחשב את התוויות לחודש המוצג (חישוב מקומי, ללא רשת וללא
  Firestore — זה לא מידע של המשתמש).
- UI: בתא החודש — שורת טקסט קטנה אחת בשם המקוצר (`shortName`, חג קודם לפרשה);
  בפירוט היום — תגיות בשם המלא מתחת
  לכותרת התאריך. החגים **אינם** אירועים: לא נשמרים, לא מסונכרנים ל-Google
  Calendar ולא נכללים בגיבוי.

**טסטים:** תאריכים ידועים (ראש השנה, יום כיפור, חנוכה, פורים ופורים
שושן, יום העצמאות עם דחייה, פרשות בשנה מעוברת ופשוטה, הבדל ארץ ישראל/חו״ל).

## 11. עריכה ומחיקה לפי היקף (M9, אושר 2026-10-11)
הכל לפי התאריך העברי. לוגיקה טהורה ב-`lib/domain/event/recurring_edit.dart`
(`planRecurringEdit`/`planRecurringDelete` → `RecurringChangePlan`):
- **מופע זה בלבד:** המופע נכנס ל-`exceptions` של הסדרה, ובמקומו נוצר אירוע עצמאי
  (לא חוזר) באותו תאריך עברי עם השינויים.
- **מופע זה והבאים אחריו:** הסדרה הקיימת מסתיימת יום לפני המופע (`until`, אלא אם
  כבר הסתיימה קודם), חריגות אחרי הנקודה עוברות לסדרה החדשה, ונפתחת סדרה חדשה
  שהעוגן שלה הוא המופע — חוזרת לפי אותו כלל עברי. מהמופע הראשון = "כל הסדרה".
- **כל הסדרה:** כמו קודם.
- אירוע חדש שנוצר מפיצול מקבל מצב סנכרון ריק, כך שמנוע הסנכרון מייצא אותו כאירוע
  Google חדש; המופעים שיצאו מהסדרה נמחקים מ-Google כ-stale instances.
- מגבלה ידועה: בסדרה חודשית שהעוגן שלה ביום ל׳, פיצול מחודש של 29 יום מעגן את
  הסדרה החדשה ל-29.

## 12. משתתפים וזימונים (M11, אושר 2026-10-11)
- `Event.attendees` (`EventAttendee`: מייל + תשובה) נשמר ב-Firestore ובגיבוי.
- יצוא: `GoogleEventWrite.attendeeEmails` → `attendees` ב-JSON; כשיש משתתפים הבקשה
  נשלחת עם `sendUpdates=all`, כך ש-**Google** שולח את הזימון/העדכון במייל (גם למי שאין
  לו את האפליקציה). מחיקה תמיד עם `sendUpdates=all` (הודעת ביטול למוזמנים, אם יש).
- רשימה ריקה לא נשלחת — כך מוזמנים שנוספו ב-Google לאירוע של האפליקציה לא נמחקים.
  מגבלה: אי אפשר להסיר מהאפליקציה את המוזמן האחרון של אירוע (מסירים ב-Google).
- ייבוא: מוזמנים של אירועי Google נקלטים (בלי בעל החשבון, `self`). לאירועים שיצאו
  מהאפליקציה (`isOwnExport`) רק התשובות מועתקות (`updateAttendeeResponses` — בלי
  dirty ובלי `localEdits`).
- אירוע חוזר עברי מיוצא כמופעים, ולכן כל מוזמן מקבל זימון לכל מופע.

## 13. מיתוג KALFAPP (M14, אושר 2026-10-11)
- "לוח עברי" הוא חלק ממשפחת האפליקציות KALFAPP, בשפה של PowerWatch (מחשבון החשמל).
  השם נשאר "לוח עברי" (החלטת בעלים).
- אייקון: קווי מתאר בתכלת `#4BB8F5` על לבן — בית, גלגל שיניים ודף לוח עם "א". נוצר מקוד
  ב-`tool/brand/make_brand_assets.py` (רפרנס: `tool/brand/icon.svg`). רקע ה-adaptive לבן.
- גרפיקה לחנות: רקע לבן, "לוח עברי" במעבר כחול→טורקיז של לוגו KALFAPP, ולוגו KALFAPP.
- באפליקציה: גופן Rubik (OFL, `assets/fonts`, משקלים סטטיים 400–700), seed `#2196F3`,
  כותרת סרגל ממורכזת בכחול, הגדרות/אודות/התנתקות בתפריט ⋮ (כמו PowerWatch), פירוט היום
  בחודש בכרטיס תכלת מעוגל.
- "אודות": לוגו KALFAPP, "אודות האפליקציה", הסבר אישי, הסתייגות "פרויקט התנדבותי",
  הזמנה לפידבק, חתימה "נתן-אור".
