import 'dart:async';

import '../domain/event/event.dart';
import '../domain/event/event_repository.dart';
import '../domain/hebrew_date/hebrew_date.dart';

/// In-memory [EventRepository]: the only implementation until Firebase
/// wiring lands in M2b, and the permanent implementation used by widget
/// tests afterwards (task brief M2a §3).
///
/// [idGenerator] and [now] are injectable so tests get deterministic ids
/// and timestamps instead of depending on a shared static counter or the
/// wall clock.
class InMemoryEventRepository implements EventRepository {
  InMemoryEventRepository({
    String Function()? idGenerator,
    DateTime Function()? now,
  }) : _idGenerator = idGenerator ?? _defaultIdGenerator,
       _now = now ?? DateTime.now;

  final String Function() _idGenerator;
  final DateTime Function() _now;
  final Map<String, Event> _events = <String, Event>{};

  /// Broadcasts a signal (no payload) whenever [_events] changes; each
  /// [watchEventsForHebrewMonth] subscription recomputes its own filtered
  /// snapshot from [_events] in response, rather than the change event
  /// carrying data itself.
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static int _idCounter = 0;

  static String _defaultIdGenerator() => 'event-${_idCounter++}';

  @override
  Stream<List<Event>> watchEventsForHebrewMonth(int year, HebrewMonth month) {
    // Built by hand (rather than an `async*` generator that `yield`s the
    // initial snapshot then `yield*`s a mapped `_changes.stream`) because
    // that two-step shape has a subscription-timing race: a broadcast
    // stream drops `add()` calls made before a listener attaches, and the
    // generator only subscribes to `_changes` *after* delivering its first
    // value — so a mutation made synchronously right after subscribing
    // (e.g. a widget that watches and immediately creates an event, or a
    // test asserting on emissions) could be silently missed. Subscribing
    // to `_changes` and emitting the initial snapshot together inside
    // `onListen` closes that gap.
    late final StreamController<List<Event>> controller;
    StreamSubscription<void>? changesSubscription;
    controller = StreamController<List<Event>>.broadcast(
      onListen: () {
        changesSubscription = _changes.stream.listen(
          (_) => controller.add(_eventsForMonth(year, month)),
        );
        controller.add(_eventsForMonth(year, month));
      },
      onCancel: () {
        unawaited(changesSubscription?.cancel());
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }

  @override
  Future<Event?> getById(String id) async => _events[id];

  @override
  Future<Event> create(Event event) async {
    final DateTime timestamp = _now();
    final Event created = event.copyWith(
      id: _idGenerator(),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    _events[created.id] = created;
    _notify();
    return created;
  }

  @override
  Future<Event> update(Event event) async {
    final Event? existing = _events[event.id];
    if (existing == null) {
      throw StateError('No event with id "${event.id}" exists.');
    }
    final Event updated = event.copyWith(
      createdAt: existing.createdAt,
      updatedAt: _now(),
    );
    _events[updated.id] = updated;
    _notify();
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    if (_events.remove(id) != null) {
      _notify();
    }
  }

  /// Closes the broadcast change stream. Not part of [EventRepository] —
  /// call it from test teardown for a repository built inside a single
  /// test; the app-wide provider instance intentionally lives for the
  /// whole app session and is never disposed.
  void dispose() {
    unawaited(_changes.close());
  }

  void _notify() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  List<Event> _eventsForMonth(int year, HebrewMonth month) {
    final List<Event> matches = _events.values
        .where(
          (Event event) =>
              event.hebrewDate.year == year && event.hebrewDate.month == month,
        )
        .toList();
    matches.sort(_compareByDayThenTime);
    return matches;
  }

  static int _compareByDayThenTime(Event a, Event b) {
    final int dayCompare = a.hebrewDate.day.compareTo(b.hebrewDate.day);
    if (dayCompare != 0) {
      return dayCompare;
    }
    if (a.allDay != b.allDay) {
      // All-day events sort before timed events on the same day, matching
      // Google Calendar's day/agenda ordering.
      return a.allDay ? -1 : 1;
    }
    final int aMinutes = a.startTime?.minutesFromMidnight ?? 0;
    final int bMinutes = b.startTime?.minutesFromMidnight ?? 0;
    if (aMinutes != bMinutes) {
      return aMinutes.compareTo(bMinutes);
    }
    return a.title.compareTo(b.title);
  }
}
