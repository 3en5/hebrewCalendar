import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kTextSizePrefsKey = 'app_text_size_v1';

/// The text size range in settings, on top of the phone's font size: a
/// slider from 90% to 140% in 5% steps (owner requests 2026-10-15 and
/// 2026-10-20, which added the smaller sizes).
const double kTextSizeMin = 0.9;
const double kTextSizeMax = 1.4;
const double kTextSizeStep = 0.05;

/// Number of steps between [kTextSizeMin] and [kTextSizeMax] (10).
final int kTextSizeSteps = ((kTextSizeMax - kTextSizeMin) / kTextSizeStep)
    .round();

/// [size] on the nearest step of the range, so a slider position or a stored
/// value never lands between steps (0.30000000000000004 and the like).
double snapTextSize(double size) {
  final int step =
      ((size.clamp(kTextSizeMin, kTextSizeMax) - kTextSizeMin) / kTextSizeStep)
          .round();
  return ((kTextSizeMin + step * kTextSizeStep) * 100).round() / 100;
}

/// The stored choice, read before the first frame by [preloadTextSize] so
/// the app opens at it without a jump. Null until preloaded.
double? _preloadedTextSize;

/// Reads the stored text size before `runApp` (main.dart). Bounded and best
/// effort: on any failure the app opens at 100%.
Future<void> preloadTextSize() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 2));
    final double? stored = prefs.getDouble(_kTextSizePrefsKey);
    if (stored != null && stored.isFinite) {
      _preloadedTextSize = snapTextSize(stored);
    }
  } catch (_) {
    // Keep null: 100%.
  }
}

/// The "גודל טקסט" choice, kept per device (a display preference, not
/// user data, so it isn't synced).
class TextSizeNotifier extends Notifier<double> {
  @override
  double build() => _preloadedTextSize ?? 1.0;

  /// Shows [size] at once without storing it (the slider while dragging).
  void preview(double size) => state = snapTextSize(size);

  Future<void> set(double size) async {
    final double snapped = snapTextSize(size);
    state = snapped;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kTextSizePrefsKey, snapped);
    } catch (_) {
      // Best effort: the in-memory value still applies for this session.
    }
  }
}

final NotifierProvider<TextSizeNotifier, double> textSizeProvider =
    NotifierProvider<TextSizeNotifier, double>(TextSizeNotifier.new);

/// The most the app's choice may enlarge text in total, together with the
/// phone's font size (owner decision 2026-10-15): beyond about 170% the
/// screens get cramped. A phone already set above it keeps its own size.
const double kMaxTotalTextScale = 1.7;

/// The phone's text scaling (possibly nonlinear) times the app's [factor],
/// up to [kMaxTotalTextScale]. A factor under 1 always shrinks.
@immutable
class AppTextScaler extends TextScaler {
  const AppTextScaler(this.system, this.factor);

  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) {
    final double phone = system.scale(fontSize);
    if (factor <= 1) {
      return phone * factor;
    }
    final double cap = fontSize * kMaxTotalTextScale;
    return phone >= cap ? phone : (phone * factor).clamp(phone, cap);
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => scale(100) / 100;

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler &&
      other.system == system &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);
}

/// How much bigger text at [fontSize] is drawn than its nominal size, for
/// layouts that grow with it (the month grid's rows and day numerals).
double textGrowth(BuildContext context, double fontSize) =>
    MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;
