import '../hebrew_date/hebrew_date.dart';
import '../hebrew_date/hebrew_date_engine.dart';
import 'default_calendar_id.dart';
import 'event.dart';
import 'event_time_of_day.dart';
import 'recurrence_rule.dart';

/// The synthetic owner uid used for every demo-mode event — there is no
/// signed-in user in demo mode (task brief #5), so this is only ever
/// compared against itself within the in-memory demo repository, never sent
/// anywhere (no Firestore/Google calls happen in demo mode at all).
const String kDemoOwnerUid = 'demo';

/// Builds a handful of realistic Hebrew sample events for demo mode: the
/// Play Store review flow where "כניסה במצב הדגמה" on the sign-in screen
/// enters the full calendar UI without authentication (task brief #5,
/// Google Play requires reviewers be able to see real content without
/// creating an account). Pure and Flutter/Firebase-free like every other
/// domain function — [today]/[now] are supplied by the caller rather than
/// read from the wall clock here, so this stays deterministic and testable.
List<Event> buildDemoEvents({
  required HebrewDate today,
  required DateTime now,
  required HebrewDateEngine engine,
}) {
  final HebrewDate tomorrow = engine.addDays(today, 1);
  final HebrewDate inTwoDays = engine.addDays(today, 2);
  return <Event>[
    // A recurring Hebrew-calendar birthday — demonstrates the app's central
    // feature (Hebrew-date-based yearly recurrence) right away.
    Event(
      id: 'demo-birthday',
      ownerUid: kDemoOwnerUid,
      calendarId: kDefaultCalendarId,
      title: 'יום הולדת עברי',
      description: 'אירוע לדוגמה: חוזר כל שנה באותו תאריך עברי.',
      hebrewDate: today,
      recurrence: const RecurrenceRule(type: RecurrenceType.hebrewYearly),
      createdAt: now,
      updatedAt: now,
    ),
    // A timed meeting — demonstrates start/end times, location and a
    // reminder.
    Event(
      id: 'demo-meeting',
      ownerUid: kDemoOwnerUid,
      calendarId: kDefaultCalendarId,
      title: 'פגישה עם הצוות',
      description: 'אירוע לדוגמה: פגישה עם שעת התחלה וסיום.',
      location: 'משרד ראשי',
      hebrewDate: tomorrow,
      allDay: false,
      startTime: const EventTimeOfDay(hour: 10, minute: 0),
      endTime: const EventTimeOfDay(hour: 11, minute: 0),
      reminderMinutesBefore: const <int>[30],
      createdAt: now,
      updatedAt: now,
    ),
    // A plain all-day event — the third common shape (no time, no
    // recurrence).
    Event(
      id: 'demo-trip',
      ownerUid: kDemoOwnerUid,
      calendarId: kDefaultCalendarId,
      title: 'טיול משפחתי',
      description: 'אירוע לדוגמה: אירוע יום שלם.',
      hebrewDate: inTwoDays,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}
