import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/linkified_text.dart';
import '../../../../domain/text/text_links.dart';
import '../../../../l10n/app_localizations.dart';

/// Google Maps search link for [location] (opens the Maps app when present).
Uri googleMapsUri(String location) => Uri.https(
  'www.google.com',
  '/maps/search/',
  <String, String>{'api': '1', 'query': location},
);

/// Waze link that navigates to [location] (opens Waze when present).
Uri wazeUri(String location) => Uri.https('waze.com', '/ul', <String, String>{
  'q': location,
  'navigate': 'yes',
});

/// An event's location with buttons to open it in Google Maps or Waze
/// (owner-approved sketch 9, 2026-10-13 — chosen over in-app Places search,
/// which needs Google Cloud billing).
class LocationActions extends StatelessWidget {
  const LocationActions({required this.location, super.key});

  final String location;

  Future<void> _open(BuildContext context, Uri uri) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final String failed = AppLocalizations.of(context).locationOpenFailed;
    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Owner request 2026-10-15: an online meeting's location (a Zoom or
    // Meet link) opens the link; maps and Waze make no sense there.
    final bool online = findTextLinks(
      location,
    ).any((TextLink l) => l.kind == TextLinkKind.url);
    if (online) {
      return Padding(
        padding: EdgeInsetsDirectional.only(bottom: spacingSm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.videocam_outlined,
              size: rem(1.25),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: spacingXs),
            Expanded(child: LinkifiedText(location)),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.place_outlined,
                size: rem(1.25),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: spacingXs),
              Expanded(child: LinkifiedText(location)),
            ],
          ),
          SizedBox(height: spacingXs),
          // One row, whatever the phone's font size (owner report
          // 2026-10-15: with a larger font the two buttons stacked): each
          // takes half the width and its label shrinks to fit.
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('location-maps'),
                  style: _compact(context),
                  onPressed: () =>
                      unawaited(_open(context, googleMapsUri(location))),
                  icon: const Icon(Icons.map_outlined),
                  label: _fit(l10n.locationOpenInMaps),
                ),
              ),
              SizedBox(width: spacingSm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('location-waze'),
                  style: _compact(context),
                  onPressed: () => unawaited(_open(context, wazeUri(location))),
                  icon: const Icon(Icons.navigation_outlined),
                  label: _fit(l10n.locationNavigateWaze),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

ButtonStyle _compact(BuildContext context) => ButtonStyle(
  visualDensity: VisualDensity.compact,
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(horizontal: spacingSm),
  ),
  // From the theme's button text, so the app font is kept.
  textStyle: WidgetStatePropertyAll<TextStyle?>(
    Theme.of(context).textTheme.labelLarge,
  ),
);

Widget _fit(String text) =>
    FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));
