import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/app_version_provider.dart';
import 'widgets/user_guide_tile.dart';

/// The KALFAPP logo, bundled for the About screen (ARCHITECTURE.md §13).
const String kalfappLogoAsset = 'assets/brand/kalfapp_logo.png';

/// The About screen, in the KALFAPP family style shared with the owner's
/// PowerWatch app (owner-approved rebrand, ARCHITECTURE.md §13): the KALFAPP
/// logo, "אודות האפליקציה", the owner's personal explanation and sign-off,
/// then the app name, installed version ([appVersionProvider]) and a link
/// to Flutter's open-source licenses page. Reached from the calendar's
/// overflow menu and the settings screen.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<String> version = ref.watch(appVersionProvider);
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutScreenTitle)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              SingleChildScrollView(
                padding: EdgeInsetsDirectional.all(spacingXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Image.asset(
                        kalfappLogoAsset,
                        width: constraints.maxWidth * 0.55,
                        semanticLabel: l10n.aboutLogoSemantics,
                      ),
                    ),
                    SizedBox(height: spacingLg),
                    Text(
                      l10n.aboutHeading,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacingLg),
                    Text(
                      l10n.aboutBody,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                    SizedBox(height: spacingLg),
                    Text(
                      l10n.aboutSignature,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.55,
                      ),
                    ),
                    SizedBox(height: spacingXxl),
                    Container(
                      padding: EdgeInsetsDirectional.all(spacingMd),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(spacingMd),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            l10n.appTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: spacingXs),
                          Text(
                            l10n.aboutTagline,
                            style: TextStyle(fontSize: bodyRem, color: muted),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: spacingSm),
                          Text(
                            l10n.settingsVersionLabel(version.value ?? ''),
                            style: TextStyle(fontSize: bodySmallRem),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: spacingXs),
                          Text(
                            l10n.aboutDeveloperCredit,
                            style: TextStyle(
                              fontSize: captionRem,
                              color: muted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacingLg),
                    // Owner request 2026-10-15: the privacy policy and the
                    // terms of use, on the site.
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: spacingSm,
                      children: <Widget>[
                        TextButton(
                          key: const ValueKey<String>('about-privacy'),
                          onPressed: () => unawaited(
                            openSitePage(context, privacyPolicyUri),
                          ),
                          child: Text(l10n.aboutPrivacyPolicy),
                        ),
                        TextButton(
                          key: const ValueKey<String>('about-terms'),
                          onPressed: () =>
                              unawaited(openSitePage(context, termsOfUseUri)),
                          child: Text(l10n.aboutTermsOfUse),
                        ),
                      ],
                    ),
                    SizedBox(height: spacingSm),
                    Center(
                      child: OutlinedButton(
                        onPressed: () => showLicensePage(
                          context: context,
                          applicationName: l10n.appTitle,
                          applicationVersion: version.value,
                        ),
                        child: Text(l10n.aboutLicensesButton),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}
