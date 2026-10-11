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

import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;

import '../../core/auth/google_sign_in_gate.dart';
import '../../domain/sync/remote_event_snapshot.dart';
import 'google_calendar_api.dart';

const List<String> _kCalendarScopes = <String>[
  'https://www.googleapis.com/auth/calendar.events',
];

const String _kEventsUrl =
    'https://www.googleapis.com/calendar/v3/calendars/primary/events';

class GoogleCalendarApiImpl implements GoogleCalendarApi {
  GoogleCalendarApiImpl({
    GoogleSignIn? googleSignIn,
    http.Client? httpClient,
    this.allowInteractiveAuth = true,
    Future<String?> Function()? signedInEmail,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _httpClient = httpClient ?? http.Client(),
       _signedInEmail = signedInEmail ?? _firebaseUserEmail;

  final GoogleSignIn _googleSignIn;
  final http.Client _httpClient;

  /// The account obtained by the last successful [requestAccess] (the "enable
  /// sync" action). Device-feedback round #5: on some devices
  /// `attemptLightweightAuthentication()` returns null even for a signed-in
  /// user, so after an interactive authorization we keep the account here and
  /// reuse it for the sync REST calls in the same session — otherwise every
  /// `_authHeaders()` call would silently fail ("No signed-in Google account
  /// available") right after the user enabled sync. NOT persisted across app
  /// restarts: after a restart [_authHeadersForSignedInEmail] takes over.
  GoogleSignInAccount? _cachedAccount;

  /// The signed-in app user's email (the Google account they signed in
  /// with). Device-feedback round #7: after an app restart
  /// `attemptLightweightAuthentication()` returned null on the owner's
  /// phone, so *every* sync failed with "No signed-in Google account" —
  /// [_authHeaders] now falls back to requesting the calendar token
  /// directly for this account, which needs no restored
  /// [GoogleSignInAccount].
  final Future<String?> Function() _signedInEmail;

  /// Whether this instance already tried a lightweight restore and got no
  /// account, so later requests go straight to the email-based fallback
  /// instead of waiting on the restore again for every REST call.
  bool _lightweightRestoreFailed = false;

  /// The Firebase user's email. In the background isolate FirebaseAuth may
  /// still be restoring its session when sync starts (`currentUser` null for
  /// a moment), so wait briefly for the first auth state instead of failing.
  static Future<String?> _firebaseUserEmail() async {
    try {
      final fb_auth.FirebaseAuth auth = fb_auth.FirebaseAuth.instance;
      final fb_auth.User? user =
          auth.currentUser ??
          await auth.authStateChanges().first.timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
      return user?.email;
    } catch (_) {
      return null;
    }
  }

  /// How long a silent account restore may take before it counts as "no
  /// account" (it is a platform call that can stall).
  static const Duration _kLightweightRestoreTimeout = Duration(seconds: 10);

  /// Whether [_authHeaders] may prompt the user for the `calendar.events`
  /// scope (`promptIfNecessary: true`) if it isn't already silently
  /// available. Must be `false` for any instance used from a WorkManager
  /// background isolate (M5b task brief — "NEVER prompts UI from
  /// background"): there is no foreground Activity there to host a consent
  /// screen, and Android would either drop the prompt silently or crash the
  /// headless engine. Defaults to `true`, unchanged from M5a foreground
  /// behavior — [requestAccess] (the explicit "enable sync" action) always
  /// prompts regardless of this flag, since it is only ever called from the
  /// foreground settings screen.
  final bool allowInteractiveAuth;

  /// Device-feedback round #3's contract for the return value: `false`
  /// means a *quiet* decline — no signed-in account to authorize against at
  /// all, or the user explicitly dismissed the consent dialog
  /// (`GoogleSignInExceptionCode.canceled`) — nothing the caller needs to
  /// surface as an error. Anything else that goes wrong (an uninitialized
  /// `GoogleSignIn.instance`, a network failure, any other
  /// `GoogleSignInException`) is *thrown*, not swallowed into `false`, so
  /// `GoogleSyncTriggerService.enable()` can tell the two apart and only
  /// show the user a real error message for the latter.
  @override
  Future<bool> requestAccess() async {
    // The ONE place interactive Google auth is allowed: the user pressed the
    // "enable sync" toggle, so a foreground consent flow is expected. Every
    // other path (the sync REST calls below) is silent-only, so an automatic
    // or repeated sync can never pop a dialog — device-feedback round #5: the
    // previous build popped the account picker inside every REST call, which
    // looped the sign-in window open/closed during each sync pass.
    final GoogleSignInAccount? account = await _currentAccount(
      interactive: true,
    );
    if (account == null) {
      debugPrint(
        '[sync-settings] requestAccess(): no Google account (user canceled), '
        'declining quietly',
      );
      return false;
    }
    try {
      final Map<String, String>? headers = await account.authorizationClient
          .authorizationHeaders(_kCalendarScopes, promptIfNecessary: true);
      debugPrint(
        '[sync-settings] requestAccess(): authorizeScopes -> '
        'granted=${headers != null}',
      );
      if (headers != null) {
        // Reuse this authorized account for the sync run that follows enabling,
        // since silent restore is unreliable on some devices.
        _cachedAccount = account;
      }
      return headers != null;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        debugPrint(
          '[sync-settings] requestAccess(): user canceled the consent dialog',
        );
        return false;
      }
      debugPrint(
        '[sync-settings] requestAccess(): authorization failed: $error',
      );
      rethrow;
    }
  }

  @override
  Future<GoogleEventsPage> listChangedEvents({String? syncToken}) async {
    final List<RemoteEventSnapshot> events = <RemoteEventSnapshot>[];
    String? pageToken;
    String? nextSyncToken;
    // Device-feedback round #6: an unbounded first sync (no syncToken) walks
    // the user's ENTIRE Google Calendar history page by page — minutes of
    // requests where a single dropped connection killed the whole run. Bound
    // the initial import to the past year (the export window already only
    // covers 24 months forward); incremental syncs via syncToken keep these
    // bounds automatically.
    final String? initialTimeMin = syncToken == null
        ? DateTime.now()
              .toUtc()
              .subtract(const Duration(days: 365))
              .toIso8601String()
        : null;
    // Round #9: and bound it forward too, to the same ~24 months the export
    // window covers. Without timeMax, `singleEvents=true` expands every
    // open-ended recurring Google event far into the future — thousands of
    // instances for a calendar in long use.
    final String? initialTimeMax = syncToken == null
        ? DateTime.now()
              .toUtc()
              .add(const Duration(days: 730))
              .toIso8601String()
        : null;
    do {
      final Uri uri = Uri.parse(_kEventsUrl).replace(
        queryParameters: <String, String>{
          'singleEvents': 'true',
          'showDeleted': 'true',
          'maxResults': '250',
          if (initialTimeMin != null) 'timeMin': initialTimeMin,
          if (initialTimeMax != null) 'timeMax': initialTimeMax,
          if (syncToken != null) 'syncToken': syncToken,
          if (pageToken != null) 'pageToken': pageToken,
        },
      );
      final http.Response response = await _requestWithRetry(
        () async => _httpClient.get(uri, headers: await _authHeaders()),
        label: 'listChangedEvents',
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
    final http.Response response = await _requestWithRetry(
      () async => _httpClient.get(
        Uri.parse('$_kEventsUrl/$googleEventId'),
        headers: await _authHeaders(),
      ),
      label: 'getEvent',
    );
    _throwIfError(response);
    return _snapshotFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<RemoteEventSnapshot> insertEvent(GoogleEventWrite event) async {
    // Insert retries are safe against duplicates: the sync planner dedups by
    // extendedProperties before creating when local state is unknown (M5a).
    final http.Response response = await _requestWithRetry(
      () async => _httpClient.post(
        Uri.parse(_kEventsUrl),
        headers: await _authHeaders(),
        body: jsonEncode(_toJson(event)),
      ),
      label: 'insertEvent',
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
    final http.Response response = await _requestWithRetry(() async {
      final Map<String, String> headers = await _authHeaders();
      if (etag != null) {
        headers['If-Match'] = etag;
      }
      return _httpClient.patch(
        Uri.parse('$_kEventsUrl/$googleEventId'),
        headers: headers,
        body: jsonEncode(_toJson(event)),
      );
    }, label: 'patchEvent');
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
    final http.Response response = await _requestWithRetry(() async {
      final Map<String, String> headers = await _authHeaders();
      if (etag != null) {
        headers['If-Match'] = etag;
      }
      return _httpClient.delete(
        Uri.parse('$_kEventsUrl/$googleEventId'),
        headers: headers,
      );
    }, label: 'deleteEvent');
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

  static const Duration _kRequestTimeout = Duration(seconds: 30);
  static const int _kMaxRequestAttempts = 3;

  /// Device-feedback round #6: a single transient network failure
  /// ("ClientException: Software caused connection abort") mid-pagination
  /// killed an entire (minutes-long) first sync. Every REST call now gets a
  /// per-request timeout and up to [_kMaxRequestAttempts] attempts with a
  /// short backoff; only transport-level failures are retried — HTTP error
  /// statuses still surface immediately via each caller's `_throwIfError`.
  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() send, {
    required String label,
  }) async {
    Object lastError = StateError('unreachable');
    StackTrace lastStackTrace = StackTrace.current;
    for (int attempt = 1; attempt <= _kMaxRequestAttempts; attempt++) {
      try {
        return await send().timeout(_kRequestTimeout);
      } on http.ClientException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      } on TimeoutException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
      debugPrint(
        '[sync-settings] $label attempt $attempt/$_kMaxRequestAttempts '
        'failed: $lastError',
      );
      if (attempt < _kMaxRequestAttempts) {
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      }
    }
    return Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  /// The single choke point through which every method in this class
  /// touches `GoogleSignIn.instance` — routes through [GoogleSignInGate]
  /// first (device-feedback round #3: a restored FirebaseAuth session never
  /// calls `GoogleSignIn.instance.initialize()` via the interactive sign-in
  /// flow, so without this guard, calling `attemptLightweightAuthentication`
  /// here first would be the first-ever use of the singleton this process —
  /// undefined behavior per the v7 API contract, see docs/LESSONS.md).
  /// Resolves the Google account to authorize Calendar requests against.
  ///
  /// [interactive] must be `true` ONLY for an explicit, user-initiated action
  /// (enabling sync). Sync REST calls pass the default `false`, so an
  /// automatic or repeated sync is guaranteed never to pop a sign-in dialog
  /// (device-feedback round #5 — the account picker was looping mid-sync).
  ///
  /// Resolution order: the [_cachedAccount] from this session's last
  /// authorization, then a silent lightweight restore, then — only when
  /// [interactive] and [allowInteractiveAuth] — a single interactive prompt.
  Future<GoogleSignInAccount?> _currentAccount({
    bool interactive = false,
  }) async {
    if (_cachedAccount != null) {
      return _cachedAccount;
    }
    await GoogleSignInGate.ensure(_googleSignIn.initialize);
    GoogleSignInAccount? account;
    if (!_lightweightRestoreFailed || interactive) {
      try {
        account =
            await (_googleSignIn.attemptLightweightAuthentication() ??
                    Future<GoogleSignInAccount?>.value())
                .timeout(_kLightweightRestoreTimeout);
      } on TimeoutException {
        debugPrint(
          '[sync-settings] attemptLightweightAuthentication() timed out',
        );
        account = null;
      }
      _lightweightRestoreFailed = account == null;
    }
    debugPrint(
      '[sync-settings] attemptLightweightAuthentication() -> '
      'account=${account?.id}',
    );
    if (account == null && interactive && allowInteractiveAuth) {
      try {
        account = await _googleSignIn.authenticate();
        debugPrint(
          '[sync-settings] interactive authenticate() -> '
          'account=${account.id}',
        );
      } on GoogleSignInException catch (exception) {
        debugPrint(
          '[sync-settings] interactive authenticate() failed: '
          '${exception.code}',
        );
        if (exception.code != GoogleSignInExceptionCode.canceled) {
          rethrow;
        }
      }
    }
    _cachedAccount ??= account;
    return account;
  }

  Future<Map<String, String>> _authHeaders() async {
    final GoogleSignInAccount? account = await _currentAccount();
    if (account == null) {
      return _authHeadersForSignedInEmail();
    }
    final Map<String, String>? headers = await account.authorizationClient
        .authorizationHeaders(
          _kCalendarScopes,
          promptIfNecessary: allowInteractiveAuth,
        );
    if (headers == null) {
      throw StateError('Calendar access was not granted.');
    }
    return <String, String>{...headers, 'Content-Type': 'application/json'};
  }

  /// Device-feedback round #7 fallback for [_authHeaders]: no
  /// [GoogleSignInAccount] could be restored, so ask for the calendar token
  /// directly for the signed-in user's email — silently (never a prompt
  /// here, so it is also safe from the background isolate). On Android this
  /// is an `AuthorizationClient.authorize` call for that account, which
  /// succeeds without UI once the user granted `calendar.events` (they did,
  /// when enabling sync).
  Future<Map<String, String>> _authHeadersForSignedInEmail() async {
    final String? email = await _signedInEmail();
    if (email == null) {
      throw StateError(
        'No signed-in Google account available for Calendar sync '
        '(no restored account and no signed-in email).',
      );
    }
    final ClientAuthorizationTokenData? tokens = await GoogleSignInPlatform
        .instance
        .clientAuthorizationTokensForScopes(
          ClientAuthorizationTokensForScopesParameters(
            request: AuthorizationRequestDetails(
              scopes: _kCalendarScopes,
              userId: null,
              email: email,
              promptIfUnauthorized: false,
            ),
          ),
        );
    debugPrint(
      '[sync-settings] email-based calendar authorization -> '
      'granted=${tokens != null}',
    );
    if (tokens == null) {
      throw StateError(
        'Calendar access was not granted for $email '
        '(silent email-based authorization returned no token).',
      );
    }
    return <String, String>{
      'Authorization': 'Bearer ${tokens.accessToken}',
      'X-Goog-AuthUser': '0',
      'Content-Type': 'application/json',
    };
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
