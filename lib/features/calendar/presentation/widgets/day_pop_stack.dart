import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';

/// The pressed day's "pop" (owner requests 2026-10-15): when a finger
/// touches a cell it grows to [dayPopScale] times its size, so its small
/// text is easy to read; it stays that big while the finger is held, and
/// [dayPopHold] after the finger lifts it shrinks back. A drag (changing
/// month, scrolling) cancels it at once. All the timings are here, to tune
/// in one place.
const Duration dayPopGrow = Duration(milliseconds: 200);
const Duration dayPopHold = Duration(milliseconds: 500);
const Duration dayPopShrink = Duration(milliseconds: 250);
const double dayPopScale = 2.0;

/// Wraps the month grid (and the agenda under it) and draws the popped
/// cell above them. A cell reports its press with [DayPopStackState.press],
/// [DayPopStackState.release] and [DayPopStackState.cancel]; the copy grows
/// from a point chosen so it stays inside this area (an edge cell grows
/// inwards). The copy ignores touches, so they reach the grid underneath;
/// a new press replaces the current pop.
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
  /// 0 is the cell's own size, 1 is fully grown.
  late final AnimationController _controller;
  late final Animation<double> _scale;
  Timer? _holdTimer;
  bool _released = false;

  Widget? _cell;
  Rect _rect = Rect.zero;
  Alignment _alignment = Alignment.center;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: dayPopGrow,
      reverseDuration: dayPopShrink,
    )..addStatusListener(_onStatus);
    _scale = Tween<double>(begin: 1, end: dayPopScale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  void _onStatus(AnimationStatus status) {
    if (!mounted) {
      return;
    }
    if (status == AnimationStatus.completed && _released) {
      _startHold();
    } else if (status == AnimationStatus.dismissed && _cell != null) {
      setState(() => _cell = null);
    }
  }

  /// The hold counts from when the finger lifted and the cell is fully
  /// grown, so even a quick tap shows the big cell for [dayPopHold].
  void _startHold() {
    _holdTimer?.cancel();
    _holdTimer = Timer(dayPopHold, () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  /// A finger touched the cell whose context is [cellContext]: grow [cell],
  /// a copy of it, over that cell's place, and keep it until [release].
  void press(BuildContext cellContext, Widget cell) {
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
    // Reset first: going back to 0 reports "dismissed", which clears the
    // previous pop, not this one.
    _holdTimer?.cancel();
    _controller.value = 0;
    _released = false;
    setState(() {
      _cell = cell;
      _rect = rect;
      _alignment = _growFrom(rect, area.size);
    });
    _controller.forward();
  }

  /// The finger lifted: shrink back [dayPopHold] after the cell is fully
  /// grown.
  void release() {
    if (_cell == null) {
      return;
    }
    _released = true;
    if (_controller.status == AnimationStatus.completed) {
      _startHold();
    }
  }

  /// The touch became a drag: remove the pop at once.
  void cancel() {
    _holdTimer?.cancel();
    _controller.value = 0;
    if (_cell != null) {
      setState(() => _cell = null);
    }
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
    _holdTimer?.cancel();
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
