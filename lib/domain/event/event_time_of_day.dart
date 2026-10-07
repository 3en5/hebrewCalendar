/// A pure-Dart time-of-day value (hour 0-23, minute 0-59).
///
/// Used instead of Flutter's `TimeOfDay` so the domain layer stays
/// Flutter-free (ARCHITECTURE.md §3). Presentation code is free to build a
/// Flutter `TimeOfDay` from this (or vice versa) at the UI boundary.
class EventTimeOfDay implements Comparable<EventTimeOfDay> {
  const EventTimeOfDay({required this.hour, required this.minute})
    : assert(hour >= 0 && hour <= 23, 'hour must be 0-23'),
      assert(minute >= 0 && minute <= 59, 'minute must be 0-59');

  final int hour;
  final int minute;

  /// Minutes since midnight (0-1439) — the basis for chronological
  /// comparison and for reminder-offset arithmetic.
  int get minutesFromMidnight => hour * 60 + minute;

  @override
  int compareTo(EventTimeOfDay other) =>
      minutesFromMidnight.compareTo(other.minutesFromMidnight);

  bool operator <(EventTimeOfDay other) => compareTo(other) < 0;

  bool operator <=(EventTimeOfDay other) => compareTo(other) <= 0;

  bool operator >(EventTimeOfDay other) => compareTo(other) > 0;

  bool operator >=(EventTimeOfDay other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTimeOfDay && other.hour == hour && other.minute == minute);

  @override
  int get hashCode => Object.hash(hour, minute);

  /// Returns a copy with the given fields replaced.
  EventTimeOfDay copyWith({int? hour, int? minute}) =>
      EventTimeOfDay(hour: hour ?? this.hour, minute: minute ?? this.minute);

  /// Zero-padded `HH:mm` display, e.g. `09:05`.
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
