// Device-feedback round #7: after an app restart no GoogleSignInAccount can
// be restored silently, so Calendar requests must still get a token by
// asking for it directly for the signed-in user's email.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:hebrew_calendar/core/auth/google_sign_in_gate.dart';
import 'package:hebrew_calendar/data/sync/google_calendar_api_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// No account can be restored; tokens are granted only for [grantedEmail].
class _NoRestorePlatform extends GoogleSignInPlatform {
  _NoRestorePlatform({required this.grantedEmail});

  final String grantedEmail;
  final List<AuthorizationRequestDetails> requests =
      <AuthorizationRequestDetails>[];
  int lightweightCalls = 0;

  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async {
    lightweightCalls++;
    return null;
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) =>
      throw UnimplementedError('sync must never prompt');

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    requests.add(params.request);
    return params.request.email == grantedEmail
        ? const ClientAuthorizationTokenData(accessToken: 'token-123')
        : null;
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

void main() {
  late _NoRestorePlatform platform;
  late List<http.Request> sent;
  late MockClient client;

  setUp(() {
    GoogleSignInGate.resetForTesting();
    platform = _NoRestorePlatform(grantedEmail: 'owner@example.com');
    GoogleSignInPlatform.instance = platform;
    sent = <http.Request>[];
    client = MockClient((http.Request request) async {
      sent.add(request);
      return http.Response(
        jsonEncode(<String, dynamic>{
          'items': <dynamic>[],
          'nextSyncToken': 'sync-1',
        }),
        200,
      );
    });
  });

  test(
    'falls back to an email-based token when no account is restored',
    () async {
      final GoogleCalendarApiImpl api = GoogleCalendarApiImpl(
        httpClient: client,
        allowInteractiveAuth: false,
        signedInEmail: () => 'owner@example.com',
      );

      final page = await api.listChangedEvents();

      expect(page.nextSyncToken, 'sync-1');
      expect(sent.single.headers['Authorization'], 'Bearer token-123');
      final AuthorizationRequestDetails request = platform.requests.single;
      expect(request.email, 'owner@example.com');
      expect(request.promptIfUnauthorized, isFalse);
      expect(
        request.scopes,
        contains('https://www.googleapis.com/auth/calendar.events'),
      );
    },
  );

  test('does not retry the silent restore on every request', () async {
    final GoogleCalendarApiImpl api = GoogleCalendarApiImpl(
      httpClient: client,
      allowInteractiveAuth: false,
      signedInEmail: () => 'owner@example.com',
    );

    await api.listChangedEvents();
    await api.listChangedEvents(syncToken: 'sync-1');

    expect(platform.lightweightCalls, 1);
    expect(sent, hasLength(2));
  });

  test('still fails clearly when nobody is signed in', () async {
    final GoogleCalendarApiImpl api = GoogleCalendarApiImpl(
      httpClient: client,
      allowInteractiveAuth: false,
      signedInEmail: () => null,
    );

    await expectLater(
      api.listChangedEvents(),
      throwsA(
        isA<StateError>().having(
          (StateError e) => e.message,
          'message',
          contains('No signed-in Google account'),
        ),
      ),
    );
    expect(sent, isEmpty);
  });
}
