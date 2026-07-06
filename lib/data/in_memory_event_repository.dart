import 'dart:async';

import '../domain/event/event.dart';
import '../domain/event/event_occurrence.dart';
import '../domain/event/event_repository.dart';
import '../domain/event/recurrence_expander.dart';
import '../domain/hebrew_date/hebrew_date.dart';
import '../domain/hebrew_date/hebrew_date_engine.dart';

/// In-memory [EventRepository]: the only implementation until Firebase
/// wiring lands in M2b, and the permanent implementation used by widget
/// tests afterwards (task brief M2a §3).
///
/// [idGenerator] and [now] are injectable so tests get deterministic ids
/// and timestamps instead of depending on a shared static counter or the
/// wall clock. Recurring events are expanded into [EventOccurrence]s on
/// every read via `recurrence_expander.dart` (M3a) — the exact same
/// expansion logic `FirestoreEventRepository` uses, so behavior doesn't
/// diverge between the two [EventRepository] implementations.
class InMemoryEventRepository implements EventRepository {
  InMemoryEventRepository({
    String Function()? idGenerator,
    DateTime Function()? now,
    HebrewDateEngine engine = const HebrewDateEngine(),
  }) : _idGenerator = idGenerator ?? _defaultIdGenerator,
       _now = now ?? DateTime.now,
       _engine = engine;

  final String Function() _idGenerator;
  final DateTime Function() _now;
  final HebrewDateEngine _engine;
  final Map<String, Event> _events = <String, Event>{};

  /// Broadcasts a signal (no payload) whenever [_events] changes; each
  /// [watchEventsForHebrewMonth] subscription recomputes its own filtered
  /// snapshot from [_events] in response, rather than the change event
  /// carrying data itself.
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static int _idCounter = 0;

  static String _defaultIdGenerator() => 'event-${_idCounter++}';

  @override
  Stream<List<EventOccurrence>> watchEventsForHebrewMonth(
    int year,
    HebrewMonth month,
  ) {
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
    late final StreamController<List<EventOccurrence>> controller;
    StreamSubscription<void>? changesSubscription;
    controller = StreamController<List<EventOccurrence>>.broadcast(
      onListen: () {
        changesSubscription = _changes.stream.listen(
          (_) => controller.add(_occurrencesForMonth(year, month)),
        );
        controller.add(_occurrencesForMonth(year, month));
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

  List<EventOccurrence> _occurrencesForMonth(int year, HebrewMonth month) {
    final List<EventOccurrence> matches = <EventOccurrence>[
      for (final Event event in _events.values)
        ...occurrencesInHebrewMonth(
          event: event,
          year: year,
          month: month,
          engine: _engine,
        ),
    ];
    matches.sort(compareEventOccurrences);
    return matches;
  }
}
