/// The real [GoogleCalendarApi]: talks to the Calendar v3 REST API directly
/// over `package:http` rather than `package:googleapis`'s generated client.
///
/// This is a deliberate deviation from the task brief's suggestion of
/// `googleapis`/`googleapis_auth`/`extension_google_sign_in_as_googleapis_auth`
/// (see `docs/LESSONS.md`): `google_sign_in` 7.x's rewritten API exposes
/// bearer-token headers directly
/// (`GoogleSignInAccount.authorizationClient.authorizationHeaders`), and the
/// generated `googleapis` `EventsResource.patch`/`delete` methods don't
/// expose a way to set the `If-Match` header ARCHITECTURE.md §5's
/// etag-based conflict detection needs — driving raw HTTP requests keeps
/// full control over headers and status codes (410/412) with two fewer
/// heavyweight, network-only-testable dependencies.
///
/// `calendar.events` OAuth scope is requested via [requestAccess] as
/// *incremental* authorization (ARCHITECTURE.md §5) — only when the settings
/// screen first enables sync, never as part of Google Sign-In itself
/// (`lib/features/auth/data/auth_repository.dart` only ever requests the
/// default profile/email scopes).
library;

import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../domain/sync/remote_event_snapshot.dart';
import 'google_calendar_api.dart';

const List<String> _kCalendarScopes = <String>[
  'https://www.googleapis.com/auth/calendar.events',
];

const String _kEventsUrl =
    'https://www.googleapis.com/calendar/v3/calendars/primary/events';

class GoogleCalendarApiImpl implements GoogleCalendarApi {
  GoogleCalendarApiImpl({GoogleSignIn? googleSignIn, http.Client? httpClient})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
      _httpClient = httpClient ?? http.Client();

  final GoogleSignIn _googleSignIn;
  final http.Client _httpClient;

  @override
  Future<bool> requestAccess() async {
    final GoogleSignInAccount? account = await _currentAccount();
    if (account == null) {
      return false;
    }
    try {
      final Map<String, String>? headers = await account.authorizationClient
          .authorizationHeaders(_kCalendarScopes, promptIfNecessary: true);
      return headers != null;
    } on GoogleSignInException {
      return false;
    }
  }

  @override
  Future<GoogleEventsPage> listChangedEvents({String? syncToken}) async {
    final List<RemoteEventSnapshot> events = <RemoteEventSnapshot>[];
    String? pageToken;
    String? nextSyncToken;
    do {
      final Uri uri = Uri.parse(_kEventsUrl).replace(
        queryParameters: <String, String>{
          'singleEvents': 'true',
          'showDeleted': 'true',
          'maxResults': '250',
          if (syncToken != null) 'syncToken': syncToken,
          if (pageToken != null) 'pageToken': pageToken,
        },
      );
      final http.Response response = await _httpClient.get(
        uri,
        headers: await _authHeaders(),
      );
      if (response.statusCode == 410) {
        throw const GoogleSyncTokenExpiredException();
      }
      _throwIfError(response);
      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> items =
          body['items'] as List<dynamic>? ?? const <dynamic>[];
      events.addAll(
        items.map(
          (dynamic item) => _snapshotFromJson(item as Map<String, dynamic>),
        ),
      );
      pageToken = body['nextPageToken'] as String?;
      nextSyncToken = body['nextSyncToken'] as String? ?? nextSyncToken;
    } while (pageToken != null);
    return GoogleEventsPage(events: events, nextSyncToken: nextSyncToken);
  }

  @override
  Future<RemoteEventSnapshot> getEvent(String googleEventId) async {
    final http.Response response = await _httpClient.get(
      Uri.parse('$_kEventsUrl/$googleEventId'),
      headers: await _authHeaders(),
    );
    _throwIfError(response);
    return _snapshotFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<RemoteEventSnapshot> insertEvent(GoogleEventWrite event) async {
    final http.Response response = await _httpClient.post(
      Uri.parse(_kEventsUrl),
      headers: await _authHeaders(),
      body: jsonEncode(_toJson(event)),
    );
    _throwIfError(response);
    return _snapshotFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<RemoteEventSnapshot> patchEvent({
    required String googleEventId,
    required String? etag,
    required GoogleEventWrite event,
  }) async {
    final Map<String, String> headers = await _authHeaders();
    if (etag != null) {
      headers['If-Match'] = etag;
    }
    final http.Response response = await _httpClient.patch(
      Uri.parse('$_kEventsUrl/$googleEventId'),
      headers: headers,
      body: jsonEncode(_toJson(event)),
    );
    if (response.statusCode == 412) {
      throw GoogleEtagMismatchException(googleEventId);
    }
    _throwIfError(response);
    return _snapshotFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<void> deleteEvent({
    required String googleEventId,
    String? etag,
  }) async {
    final Map<String, String> headers = await _authHeaders();
    if (etag != null) {
      headers['If-Match'] = etag;
    }
    final http.Response response = await _httpClient.delete(
      Uri.parse('$_kEventsUrl/$googleEventId'),
      headers: headers,
    );
    // 404/410 (already gone) and 412 (someone else already changed/deleted
    // it) are all "fine, it's not there the way we thought" for a delete —
    // ARCHITECTURE.md §5 deletions are idempotent, not worth retrying.
    if (response.statusCode == 404 ||
        response.statusCode == 410 ||
        response.statusCode == 412) {
      return;
    }
    _throwIfError(response);
  }

  Future<GoogleSignInAccount?> _currentAccount() {
    return _googleSignIn.attemptLightweightAuthentication() ??
        Future<GoogleSignInAccount?>.value();
  }

  Future<Map<String, String>> _authHeaders() async {
    final GoogleSignInAccount? account = await _currentAccount();
    if (account == null) {
      throw StateError(
        'No signed-in Google account available for Calendar sync.',
      );
    }
    final Map<String, String>? headers = await account.authorizationClient
        .authorizationHeaders(_kCalendarScopes, promptIfNecessary: true);
    if (headers == null) {
      throw StateError('Calendar access was not granted.');
    }
    return <String, String>{...headers, 'Content-Type': 'application/json'};
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw GoogleCalendarApiException(response.statusCode, response.body);
  }

  Map<String, dynamic> _toJson(GoogleEventWrite event) => <String, dynamic>{
    'summary': event.summary,
    'description': event.description,
    'location': event.location,
    'start': event.isAllDay
        ? <String, String>{'date': _dateOnly(event.start)}
        : <String, String>{'dateTime': event.start.toUtc().toIso8601String()},
    'end': event.isAllDay
        ? <String, String>{'date': _dateOnly(event.end)}
        : <String, String>{'dateTime': event.end.toUtc().toIso8601String()},
    'extendedProperties': <String, dynamic>{
      'private': <String, String>{
        'hebcalEventId': event.hebcalEventId,
        'hebcalOccurrence': event.hebcalOccurrence,
      },
    },
  };

  String _dateOnly(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  RemoteEventSnapshot _snapshotFromJson(Map<String, dynamic> json) {
    final bool cancelled = json['status'] == 'cancelled';
    final Map<String, dynamic>? extendedPrivate =
        (json['extendedProperties'] as Map<String, dynamic>?)?['private']
            as Map<String, dynamic>?;
    final Map<String, dynamic>? start = json['start'] as Map<String, dynamic>?;
    final Map<String, dynamic>? end = json['end'] as Map<String, dynamic>?;
    return RemoteEventSnapshot(
      googleEventId: json['id'] as String,
      etag: json['etag'] as String? ?? '',
      updatedAt: DateTime.parse(
        json['updated'] as String? ?? DateTime.now().toIso8601String(),
      ),
      isCancelled: cancelled,
      summary: json['summary'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      start: _parseEventDateTime(start),
      end: _parseEventDateTime(end),
      isAllDay: start != null && start['date'] != null,
      hebcalEventId: extendedPrivate?['hebcalEventId'] as String?,
      hebcalOccurrence: extendedPrivate?['hebcalOccurrence'] as String?,
    );
  }

  DateTime? _parseEventDateTime(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }
    final String? dateTime = map['dateTime'] as String?;
    if (dateTime != null) {
      return DateTime.parse(dateTime).toLocal();
    }
    final String? date = map['date'] as String?;
    return date == null ? null : DateTime.parse(date);
  }
}
