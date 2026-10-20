// The banner, the background download and the restart (owner request
// 2026-10-20), with Google Play faked.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/data/update/app_update_gateway.dart';
import 'package:hebrew_calendar/features/update/app_update_launcher.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlay implements AppUpdateGateway {
  _FakePlay({this.available = 50});

  final int? available;
  final List<String> calls = <String>[];
  final StreamController<void> _downloaded = StreamController<void>.broadcast();

  @override
  Future<UpdateCheck?> check() async {
    calls.add('check');
    return UpdateCheck(
      availableCode: available,
      flexibleAllowed: true,
      immediateAllowed: true,
    );
  }

  @override
  Future<bool> startFlexible() async {
    calls.add('flexible');
    return true;
  }

  @override
  Future<void> completeFlexible() async => calls.add('restart');

  @override
  Future<void> immediate() async => calls.add('immediate');

  @override
  Stream<void> get downloaded => _downloaded.stream;

  void finishDownload() => _downloaded.add(null);
}

Future<void> _pump(WidgetTester tester, _FakePlay play, {int? min}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appUpdateGatewayProvider.overrideWithValue(play),
        minVersionCodeProvider.overrideWithValue(() async => min),
        installedVersionCodeProvider.overrideWithValue(() async => 49),
      ],
      child: const MaterialApp(
        locale: Locale('he'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AppUpdateLauncher(child: Scaffold(body: Text('calendar'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final Finder _banner = find.byKey(const ValueKey<String>('app-update-banner'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('a newer version: banner, download, then restart', (
    WidgetTester tester,
  ) async {
    final _FakePlay play = _FakePlay();
    await _pump(tester, play);
    expect(_banner, findsOneWidget);
    expect(find.text('יש גרסה חדשה של לוח עברי.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('app-update-now')));
    await tester.pumpAndSettle();
    expect(_banner, findsNothing);
    expect(play.calls, <String>['check', 'flexible']);
    play.finishDownload();
    await tester.pump();
    // Past the snackbar's entrance animation, so the tap lands on it.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('הפעלה מחדש'), findsOneWidget);
    // The test window is shorter than a phone; press the action itself.
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump(const Duration(seconds: 1));
    expect(play.calls.last, 'restart');
  });

  testWidgets('"not now" hides it and remembers', (WidgetTester tester) async {
    final _FakePlay play = _FakePlay();
    await _pump(tester, play);
    await tester.tap(find.byKey(const ValueKey<String>('app-update-later')));
    await tester.pumpAndSettle();
    expect(_banner, findsNothing);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('app_update_dismissed_v1'), isNotNull);
  });

  testWidgets('no newer version: no banner', (WidgetTester tester) async {
    await _pump(tester, _FakePlay(available: null));
    expect(_banner, findsNothing);
  });

  testWidgets('below the minimum: Play\'s full-screen update', (
    WidgetTester tester,
  ) async {
    final _FakePlay play = _FakePlay();
    await _pump(tester, play, min: 50);
    expect(_banner, findsNothing);
    expect(play.calls, <String>['check', 'immediate']);
  });

  testWidgets('checks at most every 12 hours', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_update_checked_v1': DateTime.now()
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    });
    final _FakePlay play = _FakePlay();
    await _pump(tester, play);
    expect(play.calls, isEmpty);
  });
}
