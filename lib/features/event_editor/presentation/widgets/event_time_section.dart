import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/event/event_time_of_day.dart';
import '../../../../l10n/app_localizations.dart';

/// Start/end time fields for the event editor, side by side, disabled while
/// the event is all-day. Uses Flutter's built-in [showTimePicker] and converts the
/// result to the domain's Flutter-free [EventTimeOfDay] immediately.
class EventTimeSection extends StatelessWidget {
  const EventTimeSection({
    required this.allDay,
    required this.startTime,
    required this.endTime,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    super.key,
  });

  final bool allDay;
  final EventTimeOfDay? startTime;
  final EventTimeOfDay? endTime;
  final ValueChanged<EventTimeOfDay?> onStartTimeChanged;
  final ValueChanged<EventTimeOfDay?> onEndTimeChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Device feedback 2026-10-13: start and end side by side, one row.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _TimeTile(
            enabled: !allDay,
            label: l10n.eventStartTimeLabel,
            time: startTime,
            onChanged: onStartTimeChanged,
          ),
        ),
        SizedBox(width: spacingSm),
        Expanded(
          child: _TimeTile(
            enabled: !allDay,
            label: l10n.eventEndTimeLabel,
            time: endTime,
            onChanged: onEndTimeChanged,
          ),
        ),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.enabled,
    required this.label,
    required this.time,
    required this.onChanged,
  });

  final bool enabled;
  final String label;
  final EventTimeOfDay? time;
  final ValueChanged<EventTimeOfDay?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsetsDirectional.zero,
      enabled: enabled,
      leading: const Icon(Icons.access_time),
      minLeadingWidth: spacingMd,
      horizontalTitleGap: spacingSm,
      title: Text(label),
      subtitle: Text(time?.toString() ?? l10n.eventNoTimeSet),
      onTap: enabled ? () => _pickTime(context) : null,
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final EventTimeOfDay? current = time;
    final TimeOfDay initial = current != null
        ? TimeOfDay(hour: current.hour, minute: current.minute)
        : TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      onChanged(EventTimeOfDay(hour: picked.hour, minute: picked.minute));
    }
  }
}
