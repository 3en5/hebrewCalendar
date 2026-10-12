/// M17 (owner decision 2026-10-12): changes made in Google Calendar to the
/// events the app itself exported. Before M17 the import pass skipped every
/// one of our own exports, so an edit or deletion in Google was ignored and
/// later overwritten.
///
/// - An occurrence of a recurring series edited in Google becomes "this
///   occurrence only": the series skips that date and a standalone event,
///   linked to the same Google event, takes its place.
/// - An occurrence deleted in Google is skipped by the series. Only a
///   current or future occurrence counts: the export pass itself deletes
///   past instances and instances that no longer match the series, and
///   those must not turn into exceptions.
/// - A single (non-recurring) app event edited in Google takes Google's
///   content when Google's copy is newer and there is no unsent local edit.
///
/// "Edited" means the content differs from what the app would write for
/// that occurrence, not just a new etag: Google also changes the etag when
/// a participant replies, which is not an edit.
library;

import '../../domain/event/event.dart';
import '../../domain/event/event_repository.dart';
import '../../domain/event/recurrence_expander.dart';
import '../../domain/event/recurrence_rule.dart';
import '../../domain/hebrew_date/hebrew_date.dart';
import '../../domain/hebrew_date/hebrew_date_engine.dart';
import '../../domain/sync/occurrence_key.dart';
import '../../domain/sync/remote_event_snapshot.dart';
import '../../domain/sync/sync_state.dart';
import 'event_sync_mapper.dart';
import 'google_calendar_api.dart';
import 'remote_event_fields.dart';

class OwnExportChanges {
  OwnExportChanges({
    required EventRepository repository,
    required HebrewDateEngine engine,
    required DateTime Function() now,
  }) : _repository = repository,
       _engine = engine,
       _now = now;

  final EventRepository _repository;
  final HebrewDateEngine _engine;
  final DateTime Function() _now;

  /// Local events read during this pass, by id (null = not found).
  final Map<String, Event?> _byId = <String, Event?>{};

  /// googleEventId -> (series, occurrence key), built on first use.
  Map<String, (Event, String)>? _instanceIndex;

  /// Handles one of our own exports ([RemoteEventSnapshot.isOwnExport]).
  Future<void> applyOwnExport(RemoteEventSnapshot remote) async {
    final Event? owner = await _get(remote.hebcalEventId!);
    final String key = remote.hebcalOccurrence!;
    if (owner != null &&
        owner.recurrence.type != RecurrenceType.none &&
        owner.googleInstanceSync[key]?.googleEventId == remote.googleEventId) {
      await _applyToSeries(owner, key, remote);
      return;
    }
    if (owner != null &&
        owner.recurrence.type == RecurrenceType.none &&
        owner.googleSync.googleEventId == remote.googleEventId) {
      await _applyToSingle(owner, remote);
      return;
    }
    // An occurrence detached earlier: its Google event still names the
    // series, but a standalone local event now owns it.
    final Event? standalone = await _repository.getByGoogleEventId(
      remote.googleEventId,
    );
    if (standalone != null &&
        standalone.recurrence.type == RecurrenceType.none) {
      await _applyToSingle(standalone, remote);
    }
  }

  /// A cancellation the normal import found no local event for: if it is an
  /// instance of one of our series, apply it. Returns whether it was one.
  Future<bool> applyUnmatchedCancellation(RemoteEventSnapshot remote) async {
    final Map<String, (Event, String)> index = _instanceIndex ??=
        await _buildInstanceIndex();
    final (Event, String)? hit = index[remote.googleEventId];
    if (hit == null) {
      return false;
    }
    final Event? series = await _get(hit.$1.id);
    if (series != null) {
      await _skipIfCurrentOccurrence(series, hit.$2);
    }
    return true;
  }

  Future<void> _applyToSeries(
    Event series,
    String key,
    RemoteEventSnapshot remote,
  ) async {
    final HebrewDate? date = parseOccurrenceKey(key);
    if (date == null) {
      return;
    }
    if (remote.isCancelled) {
      await _skipIfCurrentOccurrence(series, key);
      return;
    }
    if (_matches(series, date, remote)) {
      await _refresh(series, remote, instanceKey: key);
      return;
    }
    if (series.googleSync.dirty) {
      // An unsent local edit of the series wins; its push rewrites this
      // instance.
      return;
    }
    final DateTime now = _now();
    final Event standalone = withRemoteContent(
      series.copyWith(
        id: '',
        recurrence: const RecurrenceRule(),
        googleInstanceSync: const <String, GoogleSyncState>{},
        createdAt: now,
      ),
      remote,
      _engine,
      now,
    );
    await _repository.putSyncedEvent(_withoutOccurrence(series, key, date));
    final Event created = await _repository.putSyncedEvent(standalone);
    _byId.remove(series.id);
    _byId[created.id] = created;
  }

  Future<void> _applyToSingle(Event event, RemoteEventSnapshot remote) async {
    if (remote.isCancelled) {
      await _repository.applyRemoteDelete(event.id);
      _byId[event.id] = null;
      return;
    }
    if (_matches(event, event.hebrewDate, remote)) {
      await _refresh(event, remote);
      return;
    }
    if (event.googleSync.dirty || !remote.updatedAt.isAfter(event.updatedAt)) {
      return;
    }
    final Event updated = withRemoteContent(event, remote, _engine, _now());
    await _repository.putSyncedEvent(updated);
    _byId[event.id] = updated;
  }

  /// Content unchanged: keep the new etag (so a later real edit is still
  /// told apart) and the participants' replies.
  Future<void> _refresh(
    Event event,
    RemoteEventSnapshot remote, {
    String? instanceKey,
  }) async {
    final GoogleSyncState? recorded = instanceKey == null
        ? event.googleSync
        : event.googleInstanceSync[instanceKey];
    if (recorded != null && recorded.etag != remote.etag) {
      final GoogleSyncState state = recorded.copyWith(etag: remote.etag);
      await _repository.updateSyncState(
        event.id,
        googleSync: instanceKey == null ? state : null,
        googleInstanceSync: instanceKey == null
            ? null
            : <String, GoogleSyncState>{instanceKey: state},
      );
    }
    if (remote.attendees.isNotEmpty) {
      await _repository.updateAttendeeResponses(event.id, remote.attendees);
    }
  }

  Future<void> _skipIfCurrentOccurrence(Event series, String key) async {
    final HebrewDate? date = parseOccurrenceKey(key);
    final HebrewDate today = _engine.fromGregorian(_now());
    if (date == null || date < today) {
      return;
    }
    final bool isOccurrence = occurrencesInRange(
      base: series.hebrewDate,
      rule: series.recurrence,
      from: date,
      to: date,
      engine: _engine,
    ).contains(date);
    if (!isOccurrence) {
      return;
    }
    await _repository.putSyncedEvent(_withoutOccurrence(series, key, date));
    _byId.remove(series.id);
  }

  /// [series] skipping [date], no longer tracking its Google instance.
  Event _withoutOccurrence(Event series, String key, HebrewDate date) {
    final Map<String, GoogleSyncState> instances =
        Map<String, GoogleSyncState>.of(series.googleInstanceSync)..remove(key);
    return series.copyWith(
      recurrence: series.recurrence.copyWith(
        exceptions: <HebrewDate>{
          ...series.recurrence.exceptions,
          date,
        }.toList(),
      ),
      googleInstanceSync: instances,
    );
  }

  /// Whether [remote] still says what the app would write for [event] on
  /// [date] (title, description, place, color, start and end).
  bool _matches(Event event, HebrewDate date, RemoteEventSnapshot remote) {
    final GoogleEventWrite expected = buildGoogleEventWrite(
      event: event,
      occurrenceDate: date,
      engine: _engine,
    );
    final DateTime? start = remote.start;
    final DateTime? end = remote.end;
    return expected.summary == remote.summary &&
        expected.description == remote.description &&
        expected.location == remote.location &&
        expected.colorId == remote.colorId &&
        expected.isAllDay == remote.isAllDay &&
        start != null &&
        start.isAtSameMomentAs(expected.start) &&
        (end == null || end.isAtSameMomentAs(expected.end));
  }

  Future<Event?> _get(String id) async {
    if (_byId.containsKey(id)) {
      return _byId[id];
    }
    return _byId[id] = await _repository.getById(id);
  }

  Future<Map<String, (Event, String)>> _buildInstanceIndex() async {
    final Map<String, (Event, String)> index = <String, (Event, String)>{};
    for (final Event event in await _repository.getRecurringForSync()) {
      for (final MapEntry<String, GoogleSyncState> entry
          in event.googleInstanceSync.entries) {
        final String? id = entry.value.googleEventId;
        if (id != null) {
          index[id] = (event, entry.key);
        }
      }
    }
    return index;
  }
}
