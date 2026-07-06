import '../hebrew_date/hebrew_date.dart';
import 'event.dart';
import 'recurrence_rule.dart';

/// A single concrete occurrence of an [event] on a specific [occurrenceDate].
///
/// Per ARCHITECTURE.md §4's "materialize nothing, expand at runtime"
/// principle: recurring events are never duplicated into per-occurrence
/// documents. Instead, `recurrence_expander.dart` computes [EventOccurrence]s
/// on the fly from a single stored [Event] + its [RecurrenceRule]. A
/// non-recurring event still produces exactly one [EventOccurrence], whose
/// [occurrenceDate] is simply [Event.hebrewDate] — callers (UI, repository
/// queries) work with [EventOccurrence] uniformly and never need to branch
/// on whether an event repeats.
class EventOccurrence {
  const EventOccurrence({required this.event, required this.occurrenceDate});

  /// The underlying stored event (the "series" for a recurring event).
  final Event event;

  /// The Hebrew date this particular occurrence falls on. Equal to
  /// [Event.hebrewDate] for a non-recurring event or for the first
  /// occurrence of a recurring one; a later occurrence of a recurring event
  /// has a different [occurrenceDate] while [event] (including
  /// [Event.hebrewDate], the series' anchor date) stays the same.
  final HebrewDate occurrenceDate;

  /// Whether [event] repeats (i.e. this occurrence is one of possibly many).
  bool get isRecurring => event.recurrence.type != RecurrenceType.none;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventOccurrence &&
          other.event == event &&
          other.occurrenceDate == occurrenceDate);

  @override
  int get hashCode => Object.hash(event, occurrenceDate);

  @override
  String toString() =>
      'EventOccurrence(event: ${event.id}, occurrenceDate: $occurrenceDate)';
}

/// Chronological comparator for a mixed list of [EventOccurrence]s within
/// the same day/month: by [EventOccurrence.occurrenceDate] first, then
/// all-day events before timed ones, then start time, then title —
/// mirroring the ordering Google Calendar's day/agenda views use. Shared by
/// every [EventOccurrence]-producing repository so in-memory and Firestore
/// results sort identically.
int compareEventOccurrences(EventOccurrence a, EventOccurrence b) {
  final int dateCompare = a.occurrenceDate.compareTo(b.occurrenceDate);
  if (dateCompare != 0) {
    return dateCompare;
  }
  final Event eventA = a.event;
  final Event eventB = b.event;
  if (eventA.allDay != eventB.allDay) {
    return eventA.allDay ? -1 : 1;
  }
  final int minutesA = eventA.startTime?.minutesFromMidnight ?? 0;
  final int minutesB = eventB.startTime?.minutesFromMidnight ?? 0;
  if (minutesA != minutesB) {
    return minutesA.compareTo(minutesB);
  }
  return eventA.title.compareTo(eventB.title);
}
