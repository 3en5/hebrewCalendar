# אימות OAuth אצל Google — חומרים ושלבים (M18, 2026-10-12)

האפליקציה מבקשת את ההרשאה הרגישה `calendar.events`. עד שהאימות מאושר, בודקים (לא הבעלים)
רואים "Google לא אימתה את האפליקציה". ראה גם RELEASE.md §7.

## כתובות
- דף הבית: https://hebrewcalendar-68363.web.app/
- מדיניות פרטיות: https://hebrewcalendar-68363.web.app/privacy.html
- מחיקת נתונים (גם ל-Data safety ב-Play): https://hebrewcalendar-68363.web.app/privacy.html#delete
- קוד האתר: `site/`, פרסום: `.github/workflows/hosting.yml`.

## שלבים (בעלים, ב-Google Cloud Console של hebrewcalendar-68363)
1. **Search Console:** ✅ קובץ האימות `site/googlef81089490c5c16e2.html` הועלה ואומת ע"י הבעלים (2026-10-13).
2. **APIs & Services → OAuth consent screen (Branding):**
   - App name: לוח עברי · User support email: natanor.kalfa@gmail.com · App logo: `distribution/listings/images/icon.png` (120x120 ומעלה)
   - Application home page: הכתובת של דף הבית · Privacy policy: הכתובת של המדיניות
   - Authorized domains: `hebrewcalendar-68363.web.app` (ו-`hebrewcalendar-68363.firebaseapp.com` אם כבר קיים)
   - Developer contact: natanor.kalfa@gmail.com
3. **Data access (Scopes):** רק `.../auth/calendar.events` (ו-email/profile/openid, שאינם רגישים).
4. **Verification Center → Prepare for verification / Submit**, עם ההסבר והסרטון למטה.
5. עד האישור: Audience → Test users — להוסיף את המיילים של הבודקים.

## ההסבר לשימוש ב-scope (להעתיק לטופס)
Hebrew Calendar is an Android calendar organized around the Hebrew (Jewish) date. The user can turn on two-way sync with Google Calendar in the app's settings. We request https://www.googleapis.com/auth/calendar.events to (1) read the events in the user's primary Google Calendar and show them in the Hebrew calendar views, and (2) create, update and delete in the user's Google Calendar the events the user creates in the app (including events that recur by the Hebrew date, written as individual occurrences because Google Calendar has no Hebrew recurrence rule), and send invitations to participants the user adds. We do not use the data for any other purpose, do not share or sell it, and show no ads. A narrower scope is not enough: calendar.events.readonly cannot write the user's app events to Google Calendar, and calendar.events.owned does not let the app show the user's existing events.

## תסריט לסרטון (2–3 דקות, הקלטת מסך בטלפון, להעלות ל-YouTube כ-"לא רשום")
1. לפתוח את "לוח עברי" ולהראות את מסך הכניסה, ולהיכנס עם Google.
2. להראות שבסרגל העליון של מסך ההסכמה של Google מופיע שם האפליקציה "לוח עברי" (צריך להיראות ב-URL/בכותרת שזה ה-client של הפרויקט).
3. תפריט ⋮ → הגדרות → להפעיל "סנכרון עם Google Calendar".
4. במסך ההרשאה של Google: להראות את בקשת הגישה ליומן, ולאשר (בסרטון רואים את רשימת ההרשאות באנגלית אם אפשר — אפשר לשנות שפת חשבון ל-English לפני ההקלטה).
5. לחזור ליומן: להראות שאירועים קיימים מ-Google מופיעים בתצוגת החודש.
6. ליצור אירוע חדש ("יום הולדת", חוזר כל שנה), לשמור, למשוך למטה לסנכרון.
7. לפתוח את Google Calendar ולהראות שהאירוע הופיע שם.
8. למחוק את האירוע באפליקציה, לסנכרן, ולהראות שהוא נמחק גם ב-Google Calendar.
9. להראות בהגדרות את כיבוי הסנכרון ואת הקישור למדיניות הפרטיות (מסך אודות).

## הסרטון (2026-10-13)
- הועלה ל-YouTube: https://www.youtube.com/watch?v=TEMbhFNJrY4 (2:17, ערוך עם כתוביות באנגלית; הקובץ הערוך נבנה ב-ffmpeg מהקלטת המסך).
- להגשה משתמשים בכתובת ה-watch (לא shorts). פרטיות: לא רשום (Unlisted).
