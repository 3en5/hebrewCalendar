import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kTextSizePrefsKey = 'app_text_size_v1';

/// The text sizes offered in settings (owner request 2026-10-15): the
/// app's own enlargement on top of the phone's font size.
const List<double> kTextSizeOptions = <double>[1.0, 1.1, 1.2, 1.3, 1.4];

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
    if (stored != null && kTextSizeOptions.contains(stored)) {
      _preloadedTextSize = stored;
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

  Future<void> set(double size) async {
    state = size;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kTextSizePrefsKey, size);
    } catch (_) {
      // Best effort: the in-memory value still applies for this session.
    }
  }
}

final NotifierProvider<TextSizeNotifier, double> textSizeProvider =
    NotifierProvider<TextSizeNotifier, double>(TextSizeNotifier.new);

/// The phone's text scaling (possibly nonlinear) times the app's [factor].
@immutable
class AppTextScaler extends TextScaler {
  const AppTextScaler(this.system, this.factor);

  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => system.textScaleFactor * factor;

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
