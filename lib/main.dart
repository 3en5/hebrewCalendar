import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/calendar/presentation/placeholder_home_screen.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: HebrewCalendarApp()));
}

/// Root widget of the HebrewCalendar app.
///
/// M0 scope: app shell only — theme, RTL Hebrew localization and a
/// placeholder home screen. No feature logic lives here.
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
      home: const PlaceholderHomeScreen(),
    );
  }
}
