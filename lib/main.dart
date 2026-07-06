import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  runApp(const ProviderScope(child: HebrewCalendarApp()));
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
}

/// Root widget of the HebrewCalendar app.
///
/// App shell (theme, RTL Hebrew localization) plus the auth gate — signed
/// out shows [SignInScreen], signed in shows the Hebrew month view
/// (`features/auth/presentation/auth_gate.dart`).
class HebrewCalendarApp extends StatelessWidget {
  const HebrewCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('he'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}
