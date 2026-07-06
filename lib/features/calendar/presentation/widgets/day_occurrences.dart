import '../../../../domain/event/event_occurrence.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';

/// All occurrences (all-day and timed) on a single Hebrew [date] — the
/// shared input shape for `HourGrid` (which renders only the timed ones as
/// positioned blocks) and `AllDayEventsRow` (which renders only the
/// all-day ones as a row of chips) in the week/day views (M3b), so callers
/// build one list of per-day columns instead of two parallel ones.
class DayOccurrences {
  const DayOccurrences({required this.date, required this.occurrences});

  /// The Hebrew date this column represents.
  final HebrewDate date;

  /// Every occurrence (all-day and timed) on [date].
  final List<EventOccurrence> occurrences;

  /// The timed (non-all-day) occurrences, for [HourGrid].
  List<EventOccurrence> get timed =>
      occurrences.where((EventOccurrence o) => !o.event.allDay).toList();

  /// The all-day occurrences, for `AllDayEventsRow`.
  List<EventOccurrence> get allDay =>
      occurrences.where((EventOccurrence o) => o.event.allDay).toList();
}
