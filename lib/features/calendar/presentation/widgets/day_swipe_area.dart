import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../domain/hebrew_date/hebrew_date.dart';
import '../../application/calendar_view_provider.dart';
import '../../application/hebrew_date_engine_provider.dart';

/// The month view's day detail with its own horizontal swipe (owner request
/// 2026-10-13): swiping the lower part moves one day, swiping the grid above
/// it still moves one month. Same direction as the month pages: in Hebrew
/// (RTL) a swipe to the right is the next day.
///
/// Its drag recognizer sits below the month `PageView`'s, so it wins the
/// gesture here; the day-features carousel inside it scrolls on its own row.
/// Moving past the month's last day focuses the next month's first day, and
/// the month page follows (it re-anchors on the focused date).
class DaySwipeArea extends ConsumerStatefulWidget {
  const DaySwipeArea({required this.date, required this.child, super.key});

  /// The day shown in [child]; a change animates as a page turn.
  final HebrewDate date;
  final Widget child;

  @override
  ConsumerState<DaySwipeArea> createState() => _DaySwipeAreaState();
}

class _DaySwipeAreaState extends ConsumerState<DaySwipeArea> {
  double _dragDx = 0;

  /// +1 after a swipe to the next day, -1 to the previous, 0 for any other
  /// change (a tap on a cell), which only fades.
  int _direction = 0;

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    final double dx = _dragDx;
    _dragDx = 0;
    if (dx.abs() < rem(2.5) && velocity.abs() < 300) {
      return;
    }
    final bool rightward = (velocity.abs() >= 300 ? velocity : dx) > 0;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final int step = rightward == rtl ? 1 : -1;
    setState(() => _direction = step);
    ref
        .read(calendarViewProvider.notifier)
        .setFocusedDate(
          ref.read(hebrewDateEngineProvider).addDays(widget.date, step),
        );
  }

  @override
  void didUpdateWidget(DaySwipeArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date == widget.date) {
      return;
    }
    // A change that did not come from a swipe here (a tap) only fades.
    final int expected = _direction;
    final HebrewDate swiped = ref
        .read(hebrewDateEngineProvider)
        .addDays(oldWidget.date, expected);
    if (expected == 0 || swiped != widget.date) {
      _direction = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    // The next day enters from the side the finger moved away from: from
    // the left in RTL (the finger moves right), from the right in LTR.
    final double enterFrom = _direction == 0
        ? 0
        : (_direction > 0) == rtl
        ? -1
        : 1;
    final ValueKey<HebrewDate> currentKey = ValueKey<HebrewDate>(widget.date);
    return GestureDetector(
      key: const ValueKey<String>('day-swipe-area'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dragDx = 0,
      onHorizontalDragUpdate: (DragUpdateDetails d) => _dragDx += d.delta.dx,
      onHorizontalDragEnd: _onDragEnd,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
            fit: StackFit.expand,
            children: <Widget>[...previous, ?current],
          ),
          transitionBuilder: (Widget child, Animation<double> animation) {
            if (enterFrom == 0) {
              return FadeTransition(opacity: animation, child: child);
            }
            // The outgoing page runs this animation in reverse, so it
            // leaves toward the opposite side.
            final bool incoming = child.key == currentKey;
            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset(incoming ? enterFrom : -enterFrom, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: KeyedSubtree(key: currentKey, child: widget.child),
        ),
      ),
    );
  }
}
