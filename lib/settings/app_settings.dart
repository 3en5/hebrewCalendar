import 'package:flutter/material.dart';

/// Which halachic opinion is used for the proportional-hour zmanim
/// (sof zman kriat shema / tefila).
enum ZmanimOpinion { gra, mga }

/// User preferences. Immutable; update through [SettingsController].
@immutable
class AppSettings {
  const AppSettings({
    this.languageCode,
    this.themeMode = ThemeMode.system,
    this.inIsrael = true,
    this.zmanimOpinion = ZmanimOpinion.gra,
    this.candleLightingMinutes = defaultCandleLightingMinutes,
  });

  static const defaultCandleLightingMinutes = 18;
  static const candleLightingOptions = [18, 20, 22, 30, 40];

  /// `null` follows the device locale; otherwise `he` or `en`.
  final String? languageCode;
  final ThemeMode themeMode;

  /// Land of Israel vs. diaspora: affects Yom Tov Sheni and the parsha.
  final bool inIsrael;
  final ZmanimOpinion zmanimOpinion;
  final int candleLightingMinutes;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  AppSettings copyWith({
    String? Function()? languageCode,
    ThemeMode? themeMode,
    bool? inIsrael,
    ZmanimOpinion? zmanimOpinion,
    int? candleLightingMinutes,
  }) {
    return AppSettings(
      languageCode: languageCode != null ? languageCode() : this.languageCode,
      themeMode: themeMode ?? this.themeMode,
      inIsrael: inIsrael ?? this.inIsrael,
      zmanimOpinion: zmanimOpinion ?? this.zmanimOpinion,
      candleLightingMinutes:
          candleLightingMinutes ?? this.candleLightingMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.languageCode == languageCode &&
      other.themeMode == themeMode &&
      other.inIsrael == inIsrael &&
      other.zmanimOpinion == zmanimOpinion &&
      other.candleLightingMinutes == candleLightingMinutes;

  @override
  int get hashCode => Object.hash(
    languageCode,
    themeMode,
    inIsrael,
    zmanimOpinion,
    candleLightingMinutes,
  );
}
