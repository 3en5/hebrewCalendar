import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/halacha/daily_halacha.dart';
import '../../../domain/learning/daily_parsha.dart';
import '../../../l10n/app_localizations.dart';
import '../../halacha/presentation/daily_halacha_dialog.dart';
import '../application/daily_parsha_providers.dart';
import 'daily_parsha_content.dart';

enum LearningTrack { halacha, parsha }

/// The day's portion, ready to show.
class ParshaOfDay {
  const ParshaOfDay({
    required this.parsha,
    required this.parshaName,
    required this.aliyah,
    required this.mode,
  });

  final DailyParsha parsha;
  final String parshaName;
  final int aliyah;
  final ParshaStudyMode mode;
}

/// M26 (sketch 68): the morning window with a tab for each enabled study,
/// the dedication fixed on top. A ✓ marks what was already done today, and
/// the window opens on the first study not done yet. Each tab's button
/// ("שיננתי" / "סיימתי") calls [onDone] and moves to the next open tab, or
/// closes the window when all are done.
Future<void> showDailyLearningDialog(
  BuildContext context, {
  required DailyHalacha? halacha,
  required ParshaOfDay? parsha,
  required String? dedication,
  required String dateLabel,
  required Set<LearningTrack> done,
  required Future<void> Function(LearningTrack track) onDone,
}) => showDialog<void>(
  context: context,
  builder: (BuildContext context) => _DailyLearningDialog(
    halacha: halacha,
    parsha: parsha,
    dedication: dedication,
    dateLabel: dateLabel,
    done: done,
    onDone: onDone,
  ),
);

class _DailyLearningDialog extends StatefulWidget {
  const _DailyLearningDialog({
    required this.halacha,
    required this.parsha,
    required this.dedication,
    required this.dateLabel,
    required this.done,
    required this.onDone,
  });

  final DailyHalacha? halacha;
  final ParshaOfDay? parsha;
  final String? dedication;
  final String dateLabel;
  final Set<LearningTrack> done;
  final Future<void> Function(LearningTrack track) onDone;

  @override
  State<_DailyLearningDialog> createState() => _DailyLearningDialogState();
}

class _DailyLearningDialogState extends State<_DailyLearningDialog>
    with SingleTickerProviderStateMixin {
  late final List<LearningTrack> _tracks = <LearningTrack>[
    if (widget.halacha != null) LearningTrack.halacha,
    if (widget.parsha != null) LearningTrack.parsha,
  ];
  late final Set<LearningTrack> _done = <LearningTrack>{...widget.done};
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    final int open = _tracks.indexWhere(
      (LearningTrack t) => !_done.contains(t),
    );
    _tabs = TabController(
      length: _tracks.length,
      vsync: this,
      initialIndex: open < 0 ? 0 : open,
    )..addListener(_onTab);
  }

  void _onTab() => setState(() {});

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTab)
      ..dispose();
    super.dispose();
  }

  Future<void> _finish(LearningTrack track) async {
    setState(() => _done.add(track));
    unawaited(widget.onDone(track));
    final int next = _tracks.indexWhere(
      (LearningTrack t) => !_done.contains(t),
    );
    if (next < 0) {
      Navigator.of(context).pop();
    } else {
      _tabs.animateTo(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final LearningTrack track = _tracks[_tabs.index];
    final String? line = widget.dedication;
    return Dialog(
      key: const ValueKey<String>('daily-learning-dialog'),
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
          if (_tracks.length > 1)
            TabBar(
              controller: _tabs,
              tabs: <Widget>[
                for (final LearningTrack t in _tracks)
                  Tab(
                    key: ValueKey<String>('daily-learning-tab-${t.name}'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (_done.contains(t)) ...<Widget>[
                          Icon(
                            Icons.check_circle,
                            size: bodyRem * 1.1,
                            color: colors.primary,
                          ),
                          SizedBox(width: spacingXs),
                        ],
                        Text(
                          t == LearningTrack.halacha
                              ? l10n.dailyLearningTabHalacha
                              : l10n.dailyLearningTabParsha,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          Flexible(
            child: SingleChildScrollView(
              // A new scroll position per tab, so each opens at its top.
              key: ValueKey<String>('daily-learning-scroll-${track.name}'),
              padding: EdgeInsets.all(spacingMd),
              child: switch (track) {
                LearningTrack.halacha => DailyHalachaContent(
                  halacha: widget.halacha!,
                  dateLabel: widget.dateLabel,
                ),
                LearningTrack.parsha => DailyParshaContent(
                  parsha: widget.parsha!.parsha,
                  parshaName: widget.parsha!.parshaName,
                  aliyah: widget.parsha!.aliyah,
                  mode: widget.parsha!.mode,
                  dateLabel: widget.dateLabel,
                ),
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(spacingMd),
            child: FilledButton.icon(
              key: ValueKey<String>('daily-learning-done-${track.name}'),
              onPressed: () => unawaited(_finish(track)),
              icon: const Icon(Icons.check),
              label: Text(
                track == LearningTrack.halacha
                    ? l10n.dailyHalachaLearned
                    : l10n.parshaDone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
