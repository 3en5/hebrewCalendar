import '../hebrew_date/hebrew_date.dart';

/// A stable, deterministic string key for a single occurrence date, used:
///
/// - as the `hebcalOccurrence` value in a materialized Google event's
///   `extendedProperties.private` (ARCHITECTURE.md §5), together with
///   `hebcalEventId` (the owning [Event.id]) to identify "ours" and to key
///   [Event.googleInstanceSync].
/// - as the map key for [Event.googleInstanceSync] entries.
///
/// Deterministic and human-readable (unlike a hash) so it doubles as a
/// useful debugging aid in the Google Calendar UI's event description if
/// ever surfaced there.
String occurrenceKeyFor(HebrewDate date) =>
    '${date.year}-${date.month.name}-${date.day}';

/// The occurrence date [key] was made from by [occurrenceKeyFor], or null
/// if [key] isn't one (M17: reading a Google instance back to its date).
HebrewDate? parseOccurrenceKey(String key) {
  final List<String> parts = key.split('-');
  if (parts.length != 3) {
    return null;
  }
  final int? year = int.tryParse(parts[0]);
  final int? day = int.tryParse(parts[2]);
  HebrewMonth? month;
  for (final HebrewMonth candidate in HebrewMonth.values) {
    if (candidate.name == parts[1]) {
      month = candidate;
    }
  }
  if (year == null || day == null || month == null) {
    return null;
  }
  return HebrewDate(year: year, month: month, day: day);
}
