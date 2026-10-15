import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebrew_calendar/core/widgets/linkified_text.dart';
import 'package:hebrew_calendar/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, String text) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('he'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Center(child: LinkifiedText(text))),
  ),
);

/// Taps the span whose text is [link] inside the rich text.
void _tapSpan(WidgetTester tester, String link) {
  final RichText rich = tester.widget<RichText>(find.byType(RichText).first);
  bool tapped = false;
  rich.text.visitChildren((InlineSpan span) {
    if (span is TextSpan && span.text == link) {
      (span.recognizer! as TapGestureRecognizer).onTap!();
      tapped = true;
      return false;
    }
    return true;
  });
  expect(tapped, isTrue);
}

void main() {
  testWidgets('plain text has no links', (WidgetTester tester) async {
    await _pump(tester, 'פגישת צוות');
    expect(find.text('פגישת צוות'), findsOneWidget);
  });

  testWidgets('a phone number offers call, WhatsApp and copy', (
    WidgetTester tester,
  ) async {
    await _pump(tester, 'להתקשר לפאבל 052-834-4147');
    _tapSpan(tester, '052-834-4147');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('link-call')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('link-whatsapp')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('link-copy')), findsOneWidget);
  });

  testWidgets('an email offers mail and copy', (WidgetTester tester) async {
    await _pump(tester, 'לשלוח ל-dana@example.co.il');
    _tapSpan(tester, 'dana@example.co.il');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('link-mail')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('link-whatsapp')), findsNothing);
  });
}
