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
