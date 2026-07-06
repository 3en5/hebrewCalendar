# כללי טסטים ודיפלוי — HebrewCalendar

## טסטים
### עקרונות
1. **domain הוא קודש:** כל לוגיקת התאריך העברי, החזרתיות והמרות התאריכים — unit tests מלאים,
   כולל מקרי קצה: אדר א'/ב' בשנה מעוברת, ל' חשוון/כסלו בשנים חסרות/שלמות, אירוע ב-ל' בחודש
   שלא קיים השנה, מעבר שנה עברית.
2. כל bug שתוקן מקבל טסט רגרסיה לפני התיקון (הטסט נכשל → מתקנים → עובר).
3. Widget tests למסכים מרכזיים (גריד חודש, עורך אירוע); golden tests לפריסות RTL.
4. Firestore Security Rules נבדקות עם Firebase Emulator Suite — כולל בדיקות "משתמש א' לא
   רואה נתוני משתמש ב'".
5. סף כיסוי: **90% ב-`lib/domain`**, 70% כלל-פרויקט. CI נכשל מתחת לסף.

### פירמידה
| רמה | כלי | מתי רץ |
|---|---|---|
| Unit (domain, services) | `flutter test` | כל commit |
| Widget + golden | `flutter test` | כל commit |
| Rules (emulator) | `firebase emulators:exec` | כל PR |
| Integration (מכשיר/אמולטור) | `integration_test` | לפני כל release |

## CI (GitHub Actions)
Workflow ב-`.github/workflows/ci.yml`, רץ על כל push:
1. `flutter pub get`
2. `dart format --set-exit-if-changed .`
3. `flutter analyze` (אפס warnings — `analysis_options.yaml` מחמיר)
4. `flutter test --coverage` + בדיקת ספים
5. בדיקת כלל 500 השורות (סקריפט `tool/check_file_length.sh`) — נכשל אם קובץ עבר
6. `flutter build apk --debug` (אימות בילד)

## דיפלוי
1. **Flavors:** `dev` (פרויקט Firebase נפרד) ו-`prod`. אין פיתוח מול prod.
2. **גרסאות:** semantic versioning; `versionCode` עולה אוטומטית ב-CI של release.
3. **Release build:** `flutter build appbundle --release`, חתום ב-keystore שנשמר
   מחוץ לריפו (GitHub Secrets). ProGuard/R8 מופעל.
4. **מסלול שחרור:** internal testing → closed testing → production, עם בדיקת
   crash-free rate (Crashlytics) לפני קידום.
5. אין דיפלוי עם טסטים אדומים, warnings, או TODO קריטי פתוח.
6. Firestore Rules ו-Indexes מנוהלים כקוד בריפו (`firebase/`) ומפורסים דרך CLI — לא ידנית בקונסולה.
