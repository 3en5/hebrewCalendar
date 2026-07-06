import 'package:hebrew_calendar/data/sync/google_calendar_api.dart';
import 'package:hebrew_calendar/domain/sync/remote_event_snapshot.dart';

/// An in-memory [GoogleCalendarApi] test double — no network involved
/// (M5a task brief: "no network access to Google APIs from tests"). Used
/// both directly by `sync_engine`/`google_sync_trigger_service` tests to
/// script specific remote states/failures, and as a provider override in
/// every widget test that renders `CalendarShellScreen` (which watches
/// `googleSyncTriggerServiceProvider`), mirroring `FakeNotificationScheduler`'s
/// role for M4 (see `docs/LESSONS.md`).
class FakeGoogleCalendarApi implements GoogleCalendarApi {
  /// Whether [requestAccess] grants the `calendar.events` scope.
  bool accessGranted = true;

  int requestAccessCallCount = 0;

  /// The remote "server" state: id -> snapshot. Tests seed/inspect this
  /// directly instead of going through HTTP.
  final Map<String, RemoteEventSnapshot> events =
      <String, RemoteEventSnapshot>{};

  /// Scripted responses for [listChangedEvents], consumed one per call (so a
  /// test can script "first call: full listing", "second call: only the
  /// delta"). If empty, falls back to returning every entry in [events] with
  /// [nextSyncToken] unset.
  final List<GoogleEventsPage> scriptedPages = <GoogleEventsPage>[];

  /// If set, the next [listChangedEvents] call throws this instead of
  /// returning a page (consumed once) — used to simulate a 410 GONE.
  Object? nextListError;

  /// If set, [listChangedEvents] awaits this future before proceeding
  /// (consumed once) — lets tests hold a sync pass "in flight" to exercise
  /// `SyncEngine`'s concurrency guard and `BackgroundSyncRunner`'s timeout
  /// (M5b).
  Future<void>? holdNextListUntil;

  /// If set, the next [patchEvent] call throws this instead of succeeding
  /// (consumed once) — used to simulate a 412 conflict.
  Object? nextPatchError;

  int nextIdCounter = 0;
  final List<GoogleEventWrite> insertedEvents = <GoogleEventWrite>[];
  final List<String> deletedEventIds = <String>[];

  @override
  Future<bool> requestAccess() async {
    requestAccessCallCount++;
    return accessGranted;
  }

  @override
  Future<GoogleEventsPage> listChangedEvents({String? syncToken}) async {
    final Future<void>? hold = holdNextListUntil;
    if (hold != null) {
      holdNextListUntil = null;
      await hold;
    }
    final Object? error = nextListError;
    if (error != null) {
      nextListError = null;
      throw error;
    }
    if (scriptedPages.isNotEmpty) {
      return scriptedPages.removeAt(0);
    }
    return GoogleEventsPage(
      events: events.values.toList(),
      nextSyncToken: null,
    );
  }

  @override
  Future<RemoteEventSnapshot> getEvent(String googleEventId) async {
    final RemoteEventSnapshot? snapshot = events[googleEventId];
    if (snapshot == null) {
      throw const GoogleCalendarApiException(404, 'not found');
    }
    return snapshot;
  }

  @override
  Future<RemoteEventSnapshot> insertEvent(GoogleEventWrite event) async {
    insertedEvents.add(event);
    final String id = 'remote-${nextIdCounter++}';
    final RemoteEventSnapshot snapshot = RemoteEventSnapshot(
      googleEventId: id,
      etag: 'etag-0',
      updatedAt: DateTime.now(),
      isCancelled: false,
      summary: event.summary,
      description: event.description,
      location: event.location,
      start: event.start,
      end: event.end,
      isAllDay: event.isAllDay,
      hebcalEventId: event.hebcalEventId,
      hebcalOccurrence: event.hebcalOccurrence,
    );
    events[id] = snapshot;
    return snapshot;
  }

  @override
  Future<RemoteEventSnapshot> patchEvent({
    required String googleEventId,
    required String? etag,
    required GoogleEventWrite event,
  }) async {
    final Object? error = nextPatchError;
    if (error != null) {
      nextPatchError = null;
      throw error;
    }
    final RemoteEventSnapshot? existing = events[googleEventId];
    if (existing != null && etag != null && existing.etag != etag) {
      throw GoogleEtagMismatchException(googleEventId);
    }
    final int previousEtagNumber = existing == null
        ? -1
        : (int.tryParse(existing.etag.split('-').last) ?? -1);
    final RemoteEventSnapshot updated = RemoteEventSnapshot(
      googleEventId: googleEventId,
      etag: 'etag-${previousEtagNumber + 1}',
      updatedAt: DateTime.now(),
      isCancelled: false,
      summary: event.summary,
      description: event.description,
      location: event.location,
      start: event.start,
      end: event.end,
      isAllDay: event.isAllDay,
      hebcalEventId: event.hebcalEventId,
      hebcalOccurrence: event.hebcalOccurrence,
    );
    events[googleEventId] = updated;
    return updated;
  }

  @override
  Future<void> deleteEvent({
    required String googleEventId,
    String? etag,
  }) async {
    deletedEventIds.add(googleEventId);
    events.remove(googleEventId);
  }
}
