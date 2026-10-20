import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/hebrew_date/hebrew_numerals.dart';
import '../../../domain/learning/daily_parsha.dart';
import '../../../l10n/app_localizations.dart';
import '../application/daily_parsha_providers.dart';

/// The font with the Torah's cantillation marks (pubspec.yaml).
const String kMikraFontFamily = 'NotoSerifHebrew';

/// The day's portion (sketches 67-68, owner-approved 2026-10-19): the
/// title of the mode, the parsha, aliyah, verses and date, then each verse
/// once with a "פעמיים" tag in the twice-reading modes, Onkelos in a soft
/// color, and Rashi in a box under the verse.
class DailyParshaContent extends StatelessWidget {
  const DailyParshaContent({
    required this.parsha,
    required this.parshaName,
    required this.aliyah,
    required this.mode,
    required this.dateLabel,
    super.key,
  });

  final DailyParsha parsha;
  final String parshaName;
  final int aliyah;
  final ParshaStudyMode mode;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String title = switch (mode) {
      ParshaStudyMode.targum => l10n.parshaModeTargum,
      ParshaStudyMode.targumRashi => l10n.parshaModeTargumRashi,
      ParshaStudyMode.chumashRashi => l10n.parshaModeChumashRashi,
    };
    final String source = switch (mode) {
      ParshaStudyMode.targum => l10n.parshaSourceTargum,
      ParshaStudyMode.targumRashi => l10n.parshaSourceTargumRashi,
      ParshaStudyMode.chumashRashi => l10n.parshaSourceRashi,
    };
    final TextStyle meta = TextStyle(
      fontSize: bodySmallRem,
      color: colors.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: titleLargeRem,
            fontWeight: FontWeight.w700,
            color: colors.primary,
          ),
        ),
        SizedBox(height: spacingXs),
        Text(
          l10n.parshaMeta(
            parshaName,
            l10n.parshaAliyah('$aliyah'),
            _range(parsha),
            dateLabel,
          ),
          style: meta,
        ),
        if (mode.twice) ...<Widget>[
          SizedBox(height: spacingXs),
          Text(l10n.parshaTwiceNote, style: meta),
        ],
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacingSm),
          child: const Divider(height: 1),
        ),
        for (final ParshaPortion part in parsha.parts)
          for (final ParshaVerse verse in part.verses)
            _Verse(verse: verse, mode: mode),
        Text(
          source,
          style: TextStyle(
            fontSize: captionRem,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// "בראשית י״ב, י״ד – י״ג, ד׳" (and the second part's, in a combined week).
  static String _range(DailyParsha parsha) => <String>[
    for (final ParshaPortion part in parsha.parts)
      '${part.book} ${_ref(part.verses.first)} – ${_ref(part.verses.last)}',
  ].join(' · ');

  static String _ref(ParshaVerse v) =>
      '${formatHebrewNumeral(v.chapter)}, ${formatHebrewNumeral(v.verse)}';
}

class _Verse extends StatelessWidget {
  const _Verse({required this.verse, required this.mode});

  final ParshaVerse verse;
  final ParshaStudyMode mode;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: verse.sectionBreak ? spacingLg : spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                DailyParshaContent._ref(verse),
                style: TextStyle(
                  fontSize: captionRem,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
              if (mode.twice) ...<Widget>[
                SizedBox(width: spacingXs),
                _Tag(
                  text: l10n.parshaTwiceTag,
                  background: colors.primaryContainer,
                  foreground: colors.onPrimaryContainer,
                ),
              ],
            ],
          ),
          SizedBox(height: spacingXs / 2),
          Text(
            verse.mikra,
            style: TextStyle(
              fontFamily: kMikraFontFamily,
              fontSize: bodyLargeRem * 1.1,
              height: 1.7,
              color: colors.onSurface,
            ),
          ),
          if (mode.targumShown) ...<Widget>[
            SizedBox(height: spacingXs / 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: spacingXs / 2),
                  child: _Tag(
                    text: l10n.parshaTargumTag,
                    background: colors.secondaryContainer,
                    foreground: colors.onSecondaryContainer,
                  ),
                ),
                Expanded(
                  child: Text(
                    verse.targum,
                    style: TextStyle(
                      fontFamily: kMikraFontFamily,
                      fontSize: bodyRem,
                      height: 1.6,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (mode.rashiShown && verse.rashi.isNotEmpty)
            _RashiBox(comments: verse.rashi),
        ],
      ),
    );
  }
}

class _RashiBox extends StatelessWidget {
  const _RashiBox({required this.comments});

  final List<RashiComment> comments;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle style = TextStyle(
      fontFamily: kMikraFontFamily,
      fontSize: bodySmallRem * 1.05,
      height: 1.6,
      color: colors.onSurface,
    );
    return Container(
      key: const ValueKey<String>('parsha-rashi'),
      margin: EdgeInsets.only(top: spacingXs),
      padding: EdgeInsets.all(spacingSm),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(spacingSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Tag(
                text: l10n.parshaRashiTag,
                background: colors.tertiaryContainer,
                foreground: colors.onTertiaryContainer,
              ),
            ],
          ),
          for (final RashiComment c in comments)
            Padding(
              padding: EdgeInsets.only(top: spacingXs),
              child: Text.rich(
                TextSpan(
                  style: style,
                  children: <InlineSpan>[
                    if (c.head.isNotEmpty)
                      TextSpan(
                        text: '${c.head} ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    TextSpan(text: c.body),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsetsDirectional.only(end: spacingXs),
    padding: EdgeInsets.symmetric(horizontal: spacingXs, vertical: 1),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(spacingXs),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: captionRem,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    ),
  );
}
