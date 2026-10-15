import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/event/event_attendee.dart';
import '../../../../l10n/app_localizations.dart';

/// Participants section of the event editor (M11): an email field with an
/// "add" button, and one chip per invited participant showing their reply.
class AttendeesField extends StatefulWidget {
  const AttendeesField({
    required this.attendees,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final List<EventAttendee> attendees;

  /// Returns whether the address was added (false: invalid or duplicate).
  final bool Function(String email) onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<AttendeesField> createState() => _AttendeesFieldState();
}

class _AttendeesFieldState extends State<AttendeesField> {
  final TextEditingController _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) {
      return;
    }
    final bool added = widget.onAdd(_controller.text);
    setState(() => _showError = !added);
    if (added) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('attendee-email-field'),
          controller: _controller,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n.eventAttendeesFieldLabel,
            helperText: l10n.eventAttendeesHelper,
            errorText: _showError ? l10n.eventAttendeesInvalid : null,
            suffixIcon: IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: l10n.eventAttendeesAdd,
              onPressed: _submit,
            ),
          ),
        ),
        if (widget.attendees.isNotEmpty) SizedBox(height: spacingSm),
        Wrap(
          spacing: spacingXs,
          runSpacing: spacingXs,
          children: <Widget>[
            for (final EventAttendee attendee in widget.attendees)
              InputChip(
                avatar: Icon(
                  attendeeResponseIcon(attendee.response),
                  size: rem(1.1),
                ),
                label: Text(attendee.email, textDirection: TextDirection.ltr),
                tooltip: attendeeResponseLabel(l10n, attendee.response),
                onDeleted: () => widget.onRemove(attendee.email),
              ),
          ],
        ),
      ],
    );
  }
}

/// The icon of a participant's reply, shared with the event details.
IconData attendeeResponseIcon(AttendeeResponse response) => switch (response) {
  AttendeeResponse.accepted => Icons.check_circle_outline,
  AttendeeResponse.declined => Icons.cancel_outlined,
  AttendeeResponse.tentative => Icons.help_outline,
  AttendeeResponse.needsAction => Icons.schedule,
};

/// The Hebrew name of a participant's reply, shared with the event details.
String attendeeResponseLabel(AppLocalizations l10n, AttendeeResponse r) =>
    switch (r) {
      AttendeeResponse.accepted => l10n.attendeeAccepted,
      AttendeeResponse.declined => l10n.attendeeDeclined,
      AttendeeResponse.tentative => l10n.attendeeTentative,
      AttendeeResponse.needsAction => l10n.attendeeNoReply,
    };
