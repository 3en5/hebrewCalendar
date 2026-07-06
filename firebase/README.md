# Firestore — כללי אבטחה ואינדקסים

קבצי הקונפיגורציה כאן מנוהלים כקוד (`docs/TESTING_AND_DEPLOY.md` §"דיפלוי" סעיף 3):

- `firestore.rules` — Security Rules (RULES.md §5): כל מסמך תחת `users/{uid}`
  נגיש רק לאותו `uid`, וכל מסמך תחת `events/{eventId}` נגיש רק ל-`ownerUid`
  שלו. הכול אחר נחסם במפורש.
- `firestore.indexes.json` — האינדקס המורכב הנדרש לשאילתת `events` לפי
  (`ownerUid`, `gregorianStart`) — ראה `docs/ARCHITECTURE.md` §4.

## פריסה

**חשוב:** הקבצים כאן הם קוד בלבד — הם לא נכנסים לתוקף עד שמישהו מפרסם אותם
בפועל לפרויקט Firebase. יש שתי דרכים:

### אפשרות א' — Firebase CLI (מומלץ, תואם RULES.md)

1. התקנת ה-CLI (חד-פעמי): `npm install -g firebase-tools`
2. התחברות: `firebase login`
3. מריצים מתיקיית שורש הריפו (איפה ש-`firebase.json` ו-`.firebaserc` נמצאים):
   ```
   firebase deploy --only firestore:rules,firestore:indexes
   ```
   הפקודה קוראת את `firebase.json`, שמצביע על `firebase/firestore.rules`
   ו-`firebase/firestore.indexes.json`, ומפרסמת אותם לפרויקט `hebrewcalendar-68363`
   (מוגדר ב-`.firebaserc`).

### אפשרות ב' — הדבקה ידנית בקונסולה

1. נכנסים ל-[Firebase Console](https://console.firebase.google.com/) → פרויקט
   `hebrewcalendar-68363` → Firestore Database → לשונית **Rules**.
2. מעתיקים את כל תוכן `firestore.rules` ומדביקים במקום התוכן הקיים, ואז
   לוחצים **Publish**.
3. עבור האינדקס: לשונית **Indexes** → **Add Index** → אוסף `events`,
   שדות `ownerUid` (Ascending) ואז `gregorianStart` (Ascending). לחלופין,
   Firestore בדרך כלל מציע קישור ליצירת האינדקס החסר אוטומטית בהודעת
   השגיאה שמתקבלת באפליקציה בפעם הראשונה שהשאילתה רצה בלי האינדקס.

## הערה

עד שהצעד הזה לא בוצע (על ידי המשתמש/מפעיל הפרויקט), Firestore עובד לפי
ברירת המחדל שלו — חסימת כל גישה ללא Rules מפורסמות. ראה `docs/PROGRESS.md`.

## עדכון M5a (סנכרון דו-כיווני עם Google Calendar)

`firestore.rules` השתנה כדי לתמוך בסנכרון גוגל (ARCHITECTURE.md §5):

- מסמך `users/{uid}` מקבל שלושה שדות חדשים לוולידציה (כולם אופציונליים,
  לא נכתבים בכניסה עצמה): `googleSyncEnabled` (bool), `googleSyncToken`
  (string|null), `googleLastSyncedAt` (timestamp|null) — נכתבים ע"י
  `lib/data/sync/firestore_sync_settings_store.dart` כשהמשתמש מפעיל/מכבה
  סנכרון או כשעובר sync pass.
- מסמך `events/{eventId}` מקבל שלושה שדות חדשים לוולידציה: `source`
  (`'app'`/`'google'`), `googleSync` (מפת `GoogleSyncState`: `googleEventId`/
  `etag`/`lastSyncedAt`/`dirty`), `googleInstanceSync` (מפה של אותו מבנה,
  לפי מפתח מופע — אירועים חוזרים בלבד).
- אוסף-משנה חדש `users/{uid}/pendingGoogleDeletions/{eventId}`: תור מחיקות
  מקומיות שממתינות לניקוי מרוחק ב-Google Calendar
  (`lib/data/firestore_event_sync_support.dart`) — נגיש רק לאותו `uid`.

**יש לפרוס מחדש** (`firebase deploy --only firestore:rules`, או הדבקה
ידנית — ראה "פריסה" למעלה) לפני שסנכרון גוגל אמיתי ייחשף מול Firestore;
עד אז כתיבת השדות החדשים עלולה להיכשל מול ה-Rules הישנות.

## עדכון M5b (סנכרון תקופתי ברקע דרך WorkManager)

`firestore.rules` מקבל שדה רביעי אופציונלי במסמך `users/{uid}`:
`googleLastSyncError` (string|null) — הודעת השגיאה מריצת הסנכרון האחרונה
שנכשלה (בפורגראונד או ברקע), מתנקה חזרה ל-null בכל ריצה מוצלחת
(`lib/data/sync/sync_engine.dart`). קיים כדי שכישלון של ריצת רקע (שרצה
ב-isolate נפרד בלי מאזין חי) עדיין יופיע במסך ההגדרות בפעם הבאה שהוא נטען
(ARCHITECTURE.md §5). **יש לפרוס מחדש** לפני שריצות רקע אמיתיות יכתבו את
השדה הזה בהצלחה מול Firestore.

## עדכון סבב משוב מכשיר #1 (תיקון #2 — הספינר האינסופי בהגדרות)

**`firestore.rules` עצמו לא השתנה בסבב הזה** — נבדק שוב לעומק ואומת: הרשימה
הלבנה (`hasOnly`) תחת `isValidUserDoc` כבר כוללת את כל ארבעת שדות הסנכרון
(`googleSyncEnabled`/`googleSyncToken`/`googleLastSyncedAt`/`googleLastSyncError`)
מאז M5a/M5b. **אבל** — וזה בדיוק הסיבה לספינר האינסופי שנצפה על המכשיר: כל
עוד הצעד "פריסה" למעלה לא בוצע בפועל מול הפרויקט האמיתי, ה-Rules שרצות שם
הן גרסה ישנה/ריקה, ו-`_settingsStore.load()` (קריאת `users/{uid}`) עלולה
להיכשל/להיתקע. שורש הבעיה תועד ב-`docs/LESSONS.md` וטופל בקוד (`google_sync_trigger_service.dart`:
timeout + מצב שגיאה עם כפתור "נסה שוב" — הספינר כבר לא יכול להישאר תלוי
לנצח), אבל **הפריסה בפועל של ה-Rules עדיין לא בוצעה** ונחוצה כדי שהסנכרון
עצמו יעבוד. ראה "פריסה" למעלה — מומלץ לבצע זאת בהקדם.

## עדכון M3a (אירועים חוזרים עבריים)

`firestore.rules` ו-`firestore.indexes.json` השתנו כדי לתמוך באירועים
חוזרים: שדה `isRecurring` (bool, נגזר מ-`recurrence.type`) נוסף לוולידציה
וטעון אינדקס מורכב חדש (`ownerUid`+`isRecurring`, ו-`ownerUid`+`isRecurring`+
`gregorianStart`) הנדרש לשאילתת `FirestoreEventRepository.watchEventsForHebrewMonth`
המפוצלת (אירועים לא-חוזרים לפי טווח תאריכים + כל האירועים החוזרים של
המשתמש). **יש לפרוס מחדש** (`firebase deploy --only
firestore:rules,firestore:indexes`, או הדבקה ידנית — ראה "פריסה" למעלה) לפני
שאירועים חוזרים ייחשפו כראוי מול Firestore אמיתי; עד אז השאילתה החדשה עלולה
להיכשל או לפספס אירועים חוזרים.
