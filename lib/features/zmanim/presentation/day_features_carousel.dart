import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/hebrew_date/jewish_day_info.dart';
import '../../../domain/zmanim/zmanim.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/presentation/widgets/day_cell.dart'
    show jewishDayLabelColor;
import '../application/zmanim_settings.dart';
import 'zmanim_panel.dart' show formatZman, zmanLabel;

/// A time of the day shown as a chip: a zman, candle lighting or the end of
/// Shabbat.
class TimedDayFeature {
  const TimedDayFeature({
    required this.label,
    required this.time,
    this.isShabbat = false,
  });

  final String label;
  final DateTime time;

  /// Candle lighting or the end of Shabbat, drawn in the holiday color.
  final bool isShabbat;
}

/// The order of the day's chips (owner request 2026-10-13): the time most
/// relevant now comes first, then the day's holidays/parsha, then the rest
/// of the times from there on, wrapping around to the earlier ones.
///
/// "Now" is the current clock time on [day], so on any day the first chip is
/// the next time after this hour (on another day: what the day looks like at
/// this hour). After the day's last time, the first time of the day leads.
List<Object> orderDayFeatures({
  required List<TimedDayFeature> times,
  required List<JewishDayLabel> labels,
  required DateTime day,
  required DateTime now,
}) {
  if (times.isEmpty) {
    return <Object>[...labels];
  }
  final List<TimedDayFeature> sorted = <TimedDayFeature>[...times]
    ..sort((TimedDayFeature a, TimedDayFeature b) => a.time.compareTo(b.time));
  final DateTime reference = DateTime(
    day.year,
    day.month,
    day.day,
    now.hour,
    now.minute,
  );
  int next = sorted.indexWhere(
    (TimedDayFeature t) => !t.time.isBefore(reference),
  );
  if (next < 0) {
    next = 0;
  }
  final List<TimedDayFeature> rotated = <TimedDayFeature>[
    ...sorted.sublist(next),
    ...sorted.sublist(0, next),
  ];
  return <Object>[rotated.first, ...labels, ...rotated.skip(1)];
}

/// The selected day's features under the month grid, in one swipeable row
/// (owner request 2026-10-13): holidays, parsha, Rosh Chodesh, candle
/// lighting / end of Shabbat and the times of day. The first chip is the
/// most relevant one for the current hour ([orderDayFeatures]); two small
/// arrows hint that the row scrolls and move it a step when tapped.
class DayFeaturesCarousel extends ConsumerStatefulWidget {
  const DayFeaturesCarousel({
    required this.day,
    required this.labels,
    this.now,
    super.key,
  });

  /// The civil (Gregorian) date shown.
  final DateTime day;
  final List<JewishDayLabel> labels;

  /// The current time; tests pass a fixed one.
  final DateTime? now;

  @override
  ConsumerState<DayFeaturesCarousel> createState() =>
      _DayFeaturesCarouselState();
}

class _DayFeaturesCarouselState extends ConsumerState<DayFeaturesCarousel> {
  final ScrollController _controller = ScrollController();
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateArrows);
  }

  @override
  void didUpdateWidget(DayFeaturesCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new day starts again from its most relevant chip.
    if (oldWidget.day != widget.day && _controller.hasClients) {
      _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateArrows)
      ..dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_controller.hasClients) {
      return;
    }
    final ScrollPosition p = _controller.position;
    final bool back = p.pixels > p.minScrollExtent + 1;
    final bool forward = p.pixels < p.maxScrollExtent - 1;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  void _step(int direction) {
    if (!_controller.hasClients) {
      return;
    }
    final ScrollPosition p = _controller.position;
    final double target = (p.pixels + direction * p.viewportDimension * 0.6)
        .clamp(p.minScrollExtent, p.maxScrollExtent);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ZmanimSettings settings = ref.watch(zmanimSettingsProvider);
    final ZmanimDay? zmanim = zmanimFor(settings, widget.day);
    final List<TimedDayFeature> times = <TimedDayFeature>[
      if (zmanim != null) ...<TimedDayFeature>[
        for (final Zman zman in Zman.values)
          if (zmanim.times[zman] != null)
            TimedDayFeature(
              label: zmanLabel(l10n, zman),
              time: zmanim.times[zman]!,
            ),
        if (zmanim.candleLighting != null)
          TimedDayFeature(
            label: l10n.zmanCandleLighting,
            time: zmanim.candleLighting!,
            isShabbat: true,
          ),
        if (zmanim.havdalah != null)
          TimedDayFeature(
            label: l10n.zmanHavdalah,
            time: zmanim.havdalah!,
            isShabbat: true,
          ),
      ],
    ];
    final List<Object> features = orderDayFeatures(
      times: times,
      labels: widget.labels,
      day: widget.day,
      now: widget.now ?? DateTime.now(),
    );
    if (features.isEmpty) {
      return const SizedBox.shrink();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateArrows();
      }
    });

    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: rem(1.9),
      child: Row(
        children: <Widget>[
          // RTL: the row starts on the right, so "back" is the right arrow.
          _Arrow(
            icon: Icons.chevron_right,
            enabled: _canBack,
            onTap: () => _step(-1),
          ),
          Expanded(
            // The edges fade out where more chips are hidden.
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (Rect bounds) => LinearGradient(
                // RTL: the row's start (and "back") is on the right.
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: <Color>[
                  _canBack ? Colors.transparent : Colors.black,
                  Colors.black,
                  Colors.black,
                  _canForward ? Colors.transparent : Colors.black,
                ],
                stops: const <double>[0, 0.06, 0.94, 1],
              ).createShader(bounds),
              child: ListView.separated(
                key: const ValueKey<String>('day-features-carousel'),
                controller: _controller,
                scrollDirection: Axis.horizontal,
                itemCount: features.length,
                separatorBuilder: (_, _) => SizedBox(width: spacingXs),
                itemBuilder: (BuildContext context, int index) {
                  final Object feature = features[index];
                  if (feature is TimedDayFeature) {
                    return _Chip(
                      text: '${feature.label} ${formatZman(feature.time)}',
                      color: feature.isShabbat
                          ? colors.tertiary
                          : colors.primary,
                      icon: feature.isShabbat
                          ? Icons.local_fire_department_outlined
                          : Icons.schedule,
                      strong: index == 0,
                    );
                  }
                  final JewishDayLabel label = feature as JewishDayLabel;
                  return _Chip(
                    text: label.kind == JewishDayKind.parsha
                        ? l10n.monthAgendaParshaTag(label.name)
                        : label.name,
                    color: jewishDayLabelColor(colors, label.kind),
                    strong: index == 0,
                  );
                },
              ),
            ),
          ),
          _Arrow(
            icon: Icons.chevron_left,
            enabled: _canForward,
            onTap: () => _step(1),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkResponse(
      onTap: enabled ? onTap : null,
      radius: rem(1),
      child: Icon(
        icon,
        size: rem(1.1),
        color: color.withValues(alpha: enabled ? 0.9 : 0.25),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.color,
    this.icon,
    this.strong = false,
  });

  final String text;
  final Color color;
  final IconData? icon;

  /// The first, most relevant chip: filled instead of tinted.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color foreground = strong ? theme.colorScheme.surface : color;
    return Center(
      child: Container(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacingSm,
          vertical: spacingXs / 2,
        ),
        decoration: BoxDecoration(
          color: strong ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(spacingMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: rem(0.85), color: foreground),
              SizedBox(width: math.max(2, spacingXs / 2)),
            ],
            Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
