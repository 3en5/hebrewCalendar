/// Placeholder calendar id used until per-user calendars (ARCHITECTURE.md
/// §4, `users/{uid}/calendars/{calId}`) land. Shared by the event editor
/// (new events) and the M5a sync engine's import path (events created from
/// a Google Calendar snapshot) so both agree on where an event with no
/// explicit calendar assignment lives.
const String kDefaultCalendarId = 'default';
