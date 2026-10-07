import '../../domain/sync/remote_event_snapshot.dart';

/// Abstract Google Calendar access, expressed entirely in our own DTOs
/// ([GoogleEventWrite] in, [RemoteEventSnapshot] out) — never a `googleapis`
/// type — so it is fakeable in tests without any network access
/// (`FakeGoogleCalendarApi` in `test/test_support/`). The real implementation
/// is [GoogleCalendarApiImpl] (`google_calendar_api_impl.dart`); everything
/// in `sync_engine.dart` only ever talks to this interface.
abstract class GoogleCalendarApi {
  /// Ensures the `calendar.events` OAuth scope is granted, prompting the
  /// user for incremental authorization if it is not already (ARCHITECTURE.md
  /// §5 — requested when sync is first enabled, not at sign-in). Returns
  /// whether access is granted.
  ///
  /// Device-feedback round #3's contract: returning `false` means a *quiet*
  /// decline (no signed-in account, or the user dismissed the consent
  /// dialog) — nothing to show the user. Any other failure (network,
  /// authorization plumbing, an unusable Google Sign-In state) must be
  /// *thrown*, not swallowed into `false` — `GoogleSyncTriggerService.enable`
  /// relies on this distinction to only surface a real error message for
  /// genuine failures, never for a plain cancel.
  Future<bool> requestAccess();

  /// Lists events changed since [syncToken] (ARCHITECTURE.md §5 incremental
  /// sync), or every event if [syncToken] is null (first sync, or a full
  /// resync after [GoogleSyncTokenExpiredException]).
  Future<GoogleEventsPage> listChangedEvents({String? syncToken});

  /// Fetches a single event by id — used to re-fetch the latest remote
  /// state after a [GoogleEtagMismatchException] so the engine can
  /// re-resolve the conflict (ARCHITECTURE.md §5).
  Future<RemoteEventSnapshot> getEvent(String googleEventId);

  /// Creates a new Google Calendar event.
  Future<RemoteEventSnapshot> insertEvent(GoogleEventWrite event);

  /// Updates the existing event [googleEventId], using [etag] as an
  /// `If-Match` precondition when non-null. Throws
  /// [GoogleEtagMismatchException] if the precondition fails (someone else
  /// changed it since we last read it).
  Future<RemoteEventSnapshot> patchEvent({
    required String googleEventId,
    required String? etag,
    required GoogleEventWrite event,
  });

  /// Deletes the event [googleEventId]. A 404/410 (already gone) is treated
  /// as success, not an error — ARCHITECTURE.md §5 deletions are idempotent.
  Future<void> deleteEvent({required String googleEventId, String? etag});
}

/// One page of [GoogleCalendarApi.listChangedEvents] results.
class GoogleEventsPage {
  const GoogleEventsPage({required this.events, required this.nextSyncToken});

  final List<RemoteEventSnapshot> events;

  /// The token to pass as `syncToken` on the *next* sync pass. Only
  /// meaningful once every page has been consumed (mirroring Google
  /// Calendar's own pagination contract — the real implementation pages
  /// internally and only returns the final `nextSyncToken`).
  final String? nextSyncToken;
}

/// What we send to create/update a Google Calendar event — our own DTO
/// (never a `googleapis` `Event`), built by `event_sync_mapper.dart`.
class GoogleEventWrite {
  const GoogleEventWrite({
    required this.summary,
    required this.description,
    required this.location,
    required this.isAllDay,
    required this.start,
    required this.end,
    required this.hebcalEventId,
    required this.hebcalOccurrence,
  });

  final String summary;
  final String description;
  final String location;
  final bool isAllDay;
  final DateTime start;
  final DateTime end;

  /// Written to `extendedProperties.private.hebcalEventId` — identifies
  /// this remote event as one of our own exports (ARCHITECTURE.md §5).
  final String hebcalEventId;

  /// Written to `extendedProperties.private.hebcalOccurrence`.
  final String hebcalOccurrence;
}

/// Thrown by [GoogleCalendarApi.listChangedEvents] when Google Calendar
/// returns `410 GONE` for an expired/invalid `syncToken` — the caller must
/// drop its stored token and retry with `syncToken: null` for a full resync
/// (ARCHITECTURE.md §5).
class GoogleSyncTokenExpiredException implements Exception {
  const GoogleSyncTokenExpiredException();

  @override
  String toString() =>
      'GoogleSyncTokenExpiredException: sync token expired, '
      'a full resync is required.';
}

/// Thrown by [GoogleCalendarApi.patchEvent] when Google Calendar returns
/// `412 Precondition Failed` for an `If-Match` etag that no longer matches —
/// someone else changed the event since we last read it (ARCHITECTURE.md
/// §5 conflict detection).
class GoogleEtagMismatchException implements Exception {
  const GoogleEtagMismatchException(this.googleEventId);

  final String googleEventId;

  @override
  String toString() =>
      'GoogleEtagMismatchException: etag mismatch updating $googleEventId.';
}

/// Thrown for any other non-success response from the Google Calendar API,
/// so callers can distinguish "expected, handleable" failures ([
/// GoogleSyncTokenExpiredException]/[GoogleEtagMismatchException]) from
/// everything else.
class GoogleCalendarApiException implements Exception {
  const GoogleCalendarApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'GoogleCalendarApiException($statusCode): $message';
}
