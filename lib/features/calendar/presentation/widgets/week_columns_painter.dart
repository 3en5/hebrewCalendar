import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// The week view's column guides (owner request 2026-10-13): a faint dashed
/// line between the days (and between the hour labels and the first day),
/// so the eye can follow a day down the hours, plus a light tint behind
/// the Shabbat column and today's column.
///
/// Paints across the whole week page, behind the header, the all-day row
/// and the hour grid ([paintTints]) or on top of them ([paintLines]), with
/// the same geometry as their `Row`s: a [labelWidth] slot on the start side,
/// then seven equal day columns in reading order.
class WeekColumnsPainter extends CustomPainter {
  const WeekColumnsPainter({
    required this.labelWidth,
    required this.textDirection,
    required this.lineColor,
    required this.shabbatTint,
    required this.todayTint,
    this.todayIndex,
    this.paintTints = true,
    this.paintLines = true,
  });

  final double labelWidth;
  final TextDirection textDirection;
  final Color lineColor;
  final Color shabbatTint;
  final Color todayTint;

  /// 0 = Sunday .. 6 = Shabbat; null when today is not in this week.
  final int? todayIndex;
  final bool paintTints;
  final bool paintLines;

  static const int _days = 7;
  static const double _dash = 4;
  static const double _gap = 4;

  /// The left edge of day column [i] (0 = Sunday), in paint coordinates.
  double _left(Size size, int i) {
    final double dayWidth = (size.width - labelWidth) / _days;
    return textDirection == TextDirection.rtl
        ? size.width - labelWidth - (i + 1) * dayWidth
        : labelWidth + i * dayWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double dayWidth = (size.width - labelWidth) / _days;
    if (dayWidth <= 0) {
      return;
    }
    if (paintTints) {
      void tint(int i, Color color) => canvas.drawRect(
        Rect.fromLTWH(_left(size, i), 0, dayWidth, size.height),
        Paint()..color = color,
      );
      tint(_days - 1, shabbatTint);
      final int? today = todayIndex;
      if (today != null) {
        tint(today, todayTint);
      }
    }
    if (paintLines) {
      final Paint paint = Paint()
        ..color = lineColor
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      // Boundaries 0..6: before each day; 0 separates the hour labels.
      for (int i = 0; i < _days; i++) {
        final double x = textDirection == TextDirection.rtl
            ? _left(size, i) + dayWidth
            : _left(size, i);
        final Path line = Path()
          ..moveTo(x, 0)
          ..lineTo(x, size.height);
        for (final PathMetric metric in line.computeMetrics()) {
          for (double d = 0; d < metric.length; d += _dash + _gap) {
            canvas.drawPath(metric.extractPath(d, d + _dash), paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(WeekColumnsPainter old) =>
      old.labelWidth != labelWidth ||
      old.textDirection != textDirection ||
      old.lineColor != lineColor ||
      old.shabbatTint != shabbatTint ||
      old.todayTint != todayTint ||
      old.todayIndex != todayIndex ||
      old.paintTints != paintTints ||
      old.paintLines != paintLines;
}
