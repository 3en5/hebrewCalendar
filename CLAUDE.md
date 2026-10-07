# HebrewCalendar — יומן עברי לאנדרואיד

אפליקציית יומן מלאה (בסגנון Google Calendar) שבה **התאריך העברי הוא הציר המרכזי**:
תצוגות חודש/שבוע/יום עבריות, אירועים חוזרים על בסיס תאריך עברי, פגישות, תזכורות,
משתתפים, קבצים מצורפים, מיקום, סנכרון דו-כיווני עם Google Calendar, גיבוי ושחזור.

## סטאק
- **אפליקציה:** Flutter (Dart), יעד ראשון: Android
- **Backend:** Firebase — Auth (Google Sign-In), Firestore, Storage, FCM, Functions
- **סנכרון:** Google Calendar API, דו-כיווני מלא

## חובה בתחילת כל סשן / כל סוכן-משנה
קרא לפי הסדר:
1. `docs/RULES.md` — כללי העבודה. אין לסטות מהם.
2. `docs/PROGRESS.md` — איפה הפרויקט עומד ומה השלב הנוכחי.
3. `docs/INDEX.md` — מפת הקבצים בפרויקט.
4. `docs/ARCHITECTURE.md` — התוכנית והארכיטקטורה (לפי הצורך).

## כללי ברזל (תקציר — המלא ב-docs/RULES.md)
- אין סטייה מהתוכנית ב-`docs/ARCHITECTURE.md` בלי אישור המשתמש ותיעוד.
- **אף קובץ לא עולה על 500 שורות.** עברת — פצל.
- כל קובץ חדש נרשם ב-`docs/INDEX.md`. כל סיום שלב מעדכן את `docs/PROGRESS.md`.
- לקחים ממשימות מורכבות נרשמים ב-`docs/LESSONS.md`.
- רעיונות שאינם בליבה נרשמים ב-`docs/WISHLIST.md` ולא מיושמים.
- גדלי טקסט: גודל בסיס אחד, כל השאר יחסי אליו. אין גדלים קשיחים מפוזרים בקוד.
- בידוד מלא בין משתמשים (Firestore Security Rules על `request.auth.uid`).
- אין דליפות זיכרון: כל Controller/Stream/Subscription עובר dispose/cancel.
