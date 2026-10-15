import 'dart:async' show runZonedGuarded, unawaited;
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/font_licenses.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/calendar/application/calendar_display_mode_provider.dart';
import 'features/calendar/application/calendar_view_provider.dart';
import 'features/settings/application/background_sync_bootstrap.dart';
import 'features/settings/application/text_size_provider.dart';
import 'features/settings/application/theme_mode_provider.dart';
import 'l10n/app_localizations.dart';

/// M7 error boundary: a crash anywhere in the widget tree, or an uncaught
/// error in any unhandled `Future`/async gap outside one, is logged instead
/// of silently killing the app/isolate — Crashlytics reporting is deferred
/// (docs/WISHLIST.md, needs Blaze — same billing gate as M6's attachments/
/// Storage) so [debugPrint] is the whole story for now. [runZonedGuarded]
/// and [FlutterError.onError] are complementary, not redundant: the former
/// catches errors thrown outside Flutter's own error-handling machinery
/// (e.g. inside a bare `Future` nobody awaited), the latter catches errors
/// Flutter itself catches while building/laying out/painting a widget
/// (which never reach the zone's error handler at all).
// Not `Future<void> main() async` — nothing awaits `main` itself (it's the
// process entry point), so the guarded body below is deliberately
// fire-and-forget; `unawaited` says so explicitly rather than tripping the
// `unawaited_futures` lint (RULES.md-enforced `analysis_options.yaml`).
void main() {
  unawaited(
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        registerFontLicenses();
        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          debugPrint('FlutterError: ${details.exceptionAsString()}');
        };
        await _initializeFirebase();
        await _initializeBackgroundSync();
        // The last Hebrew/Gregorian display choice and the last view type,
        // before the first frame.
        await preloadCalendarDisplayMode();
        await preloadCalendarViewType();
        await preloadTextSize();
        runApp(const ProviderScope(child: HebrewCalendarApp()));
      },
      (Object error, StackTrace stackTrace) {
        debugPrint('Uncaught zone error: $error\n$stackTrace');
      },
    ),
  );
}

/// Initializes Firebase and Firestore offline persistence.
///
/// Deliberately only ever called from [main] — never from a widget or test
/// — so `flutter test` (which builds [HebrewCalendarApp] directly) never
/// touches Firebase (task brief M2b §5). On Android, `Firebase.initializeApp`
/// reads `android/app/google-services.json` natively; there is no
/// `firebase_options.dart` (no `flutterfire configure` was run in this
/// environment — see task brief M2b §1).
Future<void> _initializeFirebase() async {
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  // Round #10: with ~2,000 events in the offline cache, every month page's
  // range query scanned the whole cached collection. Let the SDK build
  // local indexes for the queries the app actually runs.
  try {
    await FirebaseFirestore.instance
        .persistentCacheIndexManager()
        ?.enableIndexAutoCreation();
  } catch (error) {
    debugPrint('Firestore cache index auto-creation unavailable: $error');
  }
}

/// Registers the M5b WorkManager [callbackDispatcher] — Android only (task
/// brief M5b §2: "guard kIsWeb/platform"). Like [_initializeFirebase], only
/// ever called from [main] — `flutter test` never runs this. The periodic
/// task itself is registered/cancelled separately, alongside the sync
/// enable/disable flow (`google_sync_trigger_service.dart`); this call only
/// makes the dispatcher known to the platform so a scheduled task has
/// somewhere to run once it fires.
///
/// `isInDebugMode` is omitted: the installed `workmanager` (0.9.0+3)
/// deprecated that parameter (it has no effect — use `WorkmanagerDebug`
/// handlers instead) and its default is already `false`, matching the task
/// brief's intent without triggering a `deprecated_member_use` lint.
Future<void> _initializeBackgroundSync() async {
  if (kIsWeb || !Platform.isAndroid) {
    return;
  }
  await Workmanager().initialize(callbackDispatcher);
}

/// Root widget of the HebrewCalendar app.
///
/// App shell (theme, RTL Hebrew localization) plus the auth gate — signed
/// out shows [SignInScreen], signed in shows the Hebrew month view
/// (`features/auth/presentation/auth_gate.dart`).
class HebrewCalendarApp extends ConsumerWidget {
  const HebrewCalendarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      debugShowCheckedModeBanner: false,
      locale: const Locale('he'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Owner request 2026-10-15: the settings' text size, on top of the
      // phone's own font size.
      builder: (BuildContext context, Widget? child) {
        final double size = ref.watch(textSizeProvider);
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: size == 1.0
              ? media
              : media.copyWith(
                  textScaler: AppTextScaler(media.textScaler, size),
                ),
          child: child!,
        );
      },
      home: const AuthGate(),
    );
  }
}
