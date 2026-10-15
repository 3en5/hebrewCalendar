import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/halacha/daily_halacha.dart';
import '../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../l10n/app_localizations.dart';

/// How the daily halacha dialog was closed.
enum DailyHalachaResult {
  /// "שיננתי" (on the first visit: "and keep showing me").
  learned,

  /// "אל תציג לי יותר" (first visit only).
  stopShowing,

  /// Closed with back or by tapping outside.
  dismissed,
}

/// M25 (owner request 2026-10-15): the day's halacha, the dedication on
/// top, and "שיננתי" to close. On the very first visit it also asks
/// whether to keep showing it every day.
Future<DailyHalachaResult> showDailyHalachaDialog(
  BuildContext context, {
  required DailyHalacha halacha,
  required String? dedication,
  required String dateLabel,
  required bool firstTime,
}) async {
  final DailyHalachaResult? result = await showDialog<DailyHalachaResult>(
    context: context,
    builder: (BuildContext context) => _DailyHalachaDialog(
      halacha: halacha,
      dedication: dedication,
      dateLabel: dateLabel,
      firstTime: firstTime,
    ),
  );
  return result ?? DailyHalachaResult.dismissed;
}

class _DailyHalachaDialog extends StatelessWidget {
  const _DailyHalachaDialog({
    required this.halacha,
    required this.dedication,
    required this.dateLabel,
    required this.firstTime,
  });

  final DailyHalacha halacha;
  final String? dedication;
  final String dateLabel;
  final bool firstTime;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String? line = dedication;
    return Dialog(
      key: const ValueKey<String>('daily-halacha-dialog'),
      insetPadding: EdgeInsets.all(spacingMd),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (line != null)
            Container(
              key: const ValueKey<String>('daily-halacha-dedication'),
              color: colors.tertiaryContainer,
              padding: EdgeInsets.symmetric(
                horizontal: spacingMd,
                vertical: spacingSm,
              ),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: bodyRem,
                  fontWeight: FontWeight.w600,
                  color: colors.onTertiaryContainer,
                ),
              ),
            ),
          // Owner request 2026-10-15: the dedication stays put on top; the
          // title and the halacha scroll together under it.
          Flexible(
            child: SingleChildScrollView(
              key: const ValueKey<String>('daily-halacha-scroll'),
              padding: EdgeInsets.all(spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.dailyHalachaTitle,
                    style: TextStyle(
                      fontSize: titleLargeRem,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  SizedBox(height: spacingXs),
                  Text(
                    '${l10n.dailyHalachaBook} · ${halacha.title} · $dateLabel',
                    style: TextStyle(
                      fontSize: bodySmallRem,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: spacingSm),
                    child: const Divider(height: 1),
                  ),
                  for (int i = 0; i < halacha.sections.length; i++)
                    _Section(
                      section: halacha.sections[i],
                      showSiman:
                          i > 0 &&
                          halacha.sections[i].siman !=
                              halacha.sections[i - 1].siman,
                    ),
                  Text(
                    l10n.dailyHalachaSource,
                    style: TextStyle(
                      fontSize: captionRem,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FilledButton.icon(
                  key: const ValueKey<String>('daily-halacha-learned'),
                  onPressed: () =>
                      Navigator.of(context).pop(DailyHalachaResult.learned),
                  icon: const Icon(Icons.check),
                  label: Text(
                    firstTime
                        ? l10n.dailyHalachaLearnedKeep
                        : l10n.dailyHalachaLearned,
                  ),
                ),
                if (firstTime)
                  TextButton(
                    key: const ValueKey<String>('daily-halacha-stop'),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(DailyHalachaResult.stopShowing),
                    child: Text(l10n.dailyHalachaStop),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.showSiman});

  final HalachaSection section;
  final bool showSiman;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showSiman)
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: spacingSm),
              child: Text(
                l10n.dailyHalachaSiman(formatHebrewNumeral(section.siman)),
                style: TextStyle(
                  fontSize: bodyRem,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ),
          Text(
            l10n.dailyHalachaSeif(formatHebrewNumeral(section.seif)),
            style: TextStyle(
              fontSize: bodySmallRem,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacingXs),
          Text(
            section.text,
            style: TextStyle(fontSize: bodyLargeRem, height: 1.6),
          ),
        ],
      ),
    );
  }
}
