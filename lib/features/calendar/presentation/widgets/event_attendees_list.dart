import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/widgets/linkified_text.dart';
import '../../../../domain/event/event_attendee.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../event_editor/presentation/widgets/attendees_field.dart';

/// The event's participants in the details sheet, each email tappable to
/// mail or copy it, with their reply (owner request 2026-10-15).
class EventAttendeesList extends StatelessWidget {
  const EventAttendeesList({required this.attendees, super.key});

  final List<EventAttendee> attendees;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final EventAttendee a in attendees)
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: spacingXs),
              child: Row(
                children: <Widget>[
                  Icon(
                    attendeeResponseIcon(a.response),
                    size: rem(1.125),
                    color: muted,
                  ),
                  SizedBox(width: spacingXs),
                  Flexible(
                    child: LinkifiedText(
                      a.email,
                      style: TextStyle(fontSize: bodySmallRem),
                    ),
                  ),
                  SizedBox(width: spacingSm),
                  Text(
                    attendeeResponseLabel(l10n, a.response),
                    style: TextStyle(fontSize: captionRem, color: muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
