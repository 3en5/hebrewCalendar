import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';

/// The tapped day's "pop" (owner request 2026-10-15): the cell grows to
/// [dayPopScale] times its size, holds so its small text is easy to read,
/// and shrinks back. All the timings are here, to tune in one place.
const Duration dayPopGrow = Duration(milliseconds: 200);
const Duration dayPopHold = Duration(milliseconds: 1000);
const Duration dayPopShrink = Duration(milliseconds: 250);
const double dayPopScale = 2.0;

/// Wraps the month grid (and the agenda under it) and draws the popped
/// cell above them. A cell calls [DayPopStackState.pop] with its own
/// context; the copy grows from a point chosen so it stays inside this
/// area (an edge cell grows inwards). The copy ignores touches, so taps
/// reach the grid underneath; a new pop replaces the current one.
class DayPopStack extends StatefulWidget {
  const DayPopStack({required this.child, super.key});

  final Widget child;

  static DayPopStackState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<DayPopStackState>();

  @override
  State<DayPopStack> createState() => DayPopStackState();
}

class DayPopStackState extends State<DayPopStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: dayPopGrow + dayPopHold + dayPopShrink,
    )..addStatusListener(_onStatus);
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: dayPopScale,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: dayPopGrow.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(dayPopScale),
        weight: dayPopHold.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: dayPopScale,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: dayPopShrink.inMilliseconds.toDouble(),
      ),
    ]).animate(_controller);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _cell = null);
    }
  }

  Widget? _cell;
  Rect _rect = Rect.zero;
  Alignment _alignment = Alignment.center;

  /// Pops [cell], a copy of the cell whose context is [cellContext], over
  /// that cell's place.
  void pop(BuildContext cellContext, Widget cell) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    final RenderObject? cellBox = cellContext.findRenderObject();
    final RenderObject? area = context.findRenderObject();
    if (cellBox is! RenderBox || area is! RenderBox || !cellBox.hasSize) {
      return;
    }
    final Rect rect =
        cellBox.localToGlobal(Offset.zero, ancestor: area) & cellBox.size;
    setState(() {
      _cell = cell;
      _rect = rect;
      _alignment = _growFrom(rect, area.size);
    });
    _controller.forward(from: 0);
  }

  /// The alignment to scale [rect] about so the grown rect stays inside
  /// [area] (as far as it fits), centred on the cell otherwise.
  static Alignment _growFrom(Rect rect, Size area) {
    double axis(double start, double extent, double limit) {
      final double grown = extent * dayPopScale;
      final double centre = start + extent / 2;
      final double wanted = grown >= limit
          ? limit / 2
          : centre.clamp(grown / 2, limit - grown / 2);
      // Scaling about anchor a moves the centre to a + (centre - a) * s.
      final double anchor = (dayPopScale * centre - wanted) / (dayPopScale - 1);
      return ((anchor - start) / extent * 2 - 1).clamp(-1.0, 1.0);
    }

    return Alignment(
      axis(rect.left, rect.width, area.width),
      axis(rect.top, rect.height, area.height),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget? cell = _cell;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        widget.child,
        if (cell != null)
          Positioned.fromRect(
            rect: _rect,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _scale,
                builder: (BuildContext context, Widget? child) =>
                    Transform.scale(
                      scale: _scale.value,
                      alignment: _alignment,
                      child: child,
                    ),
                child: Material(
                  key: const ValueKey<String>('day-pop'),
                  elevation: 6,
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(rem(0.375)),
                  clipBehavior: Clip.antiAlias,
                  child: cell,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
