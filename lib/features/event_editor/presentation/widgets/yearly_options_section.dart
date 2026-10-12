import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/event/recurrence_rule.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../../../l10n/app_localizations.dart';

/// M15 (owner decision 2026-10-12): extra choices for a yearly event whose
/// Hebrew date has more than one reasonable meaning in some years. Shown
/// only when they apply: an anchor in Adar (which Adar in a leap year) and
/// an anchor on day 30 (where it falls when the month has 29 days).
class YearlyOptionsSection extends StatelessWidget {
  const YearlyOptionsSection({
    required this.anchor,
    required this.rule,
    required this.onLeapAdarChanged,
    required this.onShortMonthChanged,
    super.key,
  });

  final HebrewDate anchor;

  /// The rule as currently edited; its `effective*` values are shown.
  final RecurrenceRule rule;
  final ValueChanged<LeapAdarPolicy> onLeapAdarChanged;
  final ValueChanged<ShortMonthPolicy> onShortMonthChanged;

  static bool _isAdar(HebrewMonth month) =>
      month == HebrewMonth.adar ||
      month == HebrewMonth.adarI ||
      month == HebrewMonth.adarII;

  /// Whether the section has anything to show for [anchor].
  static bool appliesTo(HebrewDate anchor) =>
      _isAdar(anchor.month) || anchor.day == 30;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LeapAdarPolicy leapAdar = rule.effectiveLeapAdar(anchor.month);
    final ShortMonthPolicy shortMonth = rule.effectiveShortMonth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_isAdar(anchor.month)) ...<Widget>[
          SizedBox(height: spacingSm),
          Text(l10n.eventLeapAdarLabel),
          SizedBox(height: spacingXs),
          Wrap(
            spacing: spacingSm,
            children: <Widget>[
              for (final LeapAdarPolicy policy in LeapAdarPolicy.values)
                ChoiceChip(
                  label: Text(switch (policy) {
                    LeapAdarPolicy.adarI => l10n.eventLeapAdarI,
                    LeapAdarPolicy.adarII => l10n.eventLeapAdarII,
                    LeapAdarPolicy.both => l10n.eventLeapAdarBoth,
                  }),
                  selected: leapAdar == policy,
                  onSelected: (_) => onLeapAdarChanged(policy),
                ),
            ],
          ),
        ],
        if (anchor.day == 30) ...<Widget>[
          SizedBox(height: spacingSm),
          Text(l10n.eventShortMonthLabel),
          SizedBox(height: spacingXs),
          Wrap(
            spacing: spacingSm,
            children: <Widget>[
              for (final ShortMonthPolicy policy in ShortMonthPolicy.values)
                ChoiceChip(
                  label: Text(switch (policy) {
                    ShortMonthPolicy.nextMonthFirst => l10n.eventShortMonthNext,
                    ShortMonthPolicy.lastDay => l10n.eventShortMonthLast,
                  }),
                  selected: shortMonth == policy,
                  onSelected: (_) => onShortMonthChanged(policy),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
