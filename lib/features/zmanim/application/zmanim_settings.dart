import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/zmanim/zmanim.dart';
import '../../../domain/zmanim/zmanim_location.dart';

/// The times-of-day preferences (M21, sketch 12). Per device, like the
/// Israel/diaspora calendar choice: they describe where the user is, not
/// their data, so they are not synced.
class ZmanimSettings {
  const ZmanimSettings({
    this.enabled = true,
    this.cityId = 'jerusalem',
    this.useDevicePosition = false,
    this.deviceLatitude,
    this.deviceLongitude,
    this.candleLightingMinutes,
    this.havdalah = HavdalahMethod.degrees8Point5,
  });

  final bool enabled;
  final String cityId;

  /// Use the phone's last known position instead of [cityId].
  final bool useDevicePosition;
  final double? deviceLatitude;
  final double? deviceLongitude;

  /// Minutes before sunset; null = the city's custom.
  final int? candleLightingMinutes;
  final HavdalahMethod havdalah;

  ZmanimLocation get city => zmanimCityById(cityId);

  /// Where the times are computed: the phone's position when chosen and
  /// known, else the city.
  ZmanimLocation get location {
    final double? lat = deviceLatitude;
    final double? lng = deviceLongitude;
    if (useDevicePosition && lat != null && lng != null) {
      return city.withPosition(lat, lng);
    }
    return city;
  }

  int get effectiveCandleLightingMinutes =>
      candleLightingMinutes ?? city.candleLightingMinutes;

  ZmanimSettings copyWith({
    bool? enabled,
    String? cityId,
    bool? useDevicePosition,
    double? deviceLatitude,
    double? deviceLongitude,
    int? candleLightingMinutes,
    bool clearCandleLightingMinutes = false,
    HavdalahMethod? havdalah,
  }) => ZmanimSettings(
    enabled: enabled ?? this.enabled,
    cityId: cityId ?? this.cityId,
    useDevicePosition: useDevicePosition ?? this.useDevicePosition,
    deviceLatitude: deviceLatitude ?? this.deviceLatitude,
    deviceLongitude: deviceLongitude ?? this.deviceLongitude,
    candleLightingMinutes: clearCandleLightingMinutes
        ? null
        : (candleLightingMinutes ?? this.candleLightingMinutes),
    havdalah: havdalah ?? this.havdalah,
  );
}

const String _kPrefix = 'zmanim_v1_';

class ZmanimSettingsNotifier extends Notifier<ZmanimSettings> {
  /// Set by every change, so a load that finishes after the user already
  /// changed something does not overwrite it with the stored values.
  bool _changed = false;

  @override
  ZmanimSettings build() {
    unawaited(_load());
    return const ZmanimSettings();
  }

  Future<void> _load() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final String? havdalah = p.getString('${_kPrefix}havdalah');
      if (_changed) {
        return;
      }
      state = ZmanimSettings(
        enabled: p.getBool('${_kPrefix}enabled') ?? true,
        cityId: p.getString('${_kPrefix}city') ?? 'jerusalem',
        useDevicePosition: p.getBool('${_kPrefix}device') ?? false,
        deviceLatitude: p.getDouble('${_kPrefix}lat'),
        deviceLongitude: p.getDouble('${_kPrefix}lng'),
        candleLightingMinutes: p.getInt('${_kPrefix}candles'),
        havdalah:
            HavdalahMethod.values
                .where((HavdalahMethod m) => m.name == havdalah)
                .firstOrNull ??
            HavdalahMethod.degrees8Point5,
      );
    } catch (_) {
      // No platform channel (e.g. under `flutter test`): keep the defaults.
    }
  }

  Future<void> _save() async {
    _changed = true;
    final ZmanimSettings s = state;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setBool('${_kPrefix}enabled', s.enabled);
      await p.setString('${_kPrefix}city', s.cityId);
      await p.setBool('${_kPrefix}device', s.useDevicePosition);
      if (s.deviceLatitude != null && s.deviceLongitude != null) {
        await p.setDouble('${_kPrefix}lat', s.deviceLatitude!);
        await p.setDouble('${_kPrefix}lng', s.deviceLongitude!);
      }
      final int? candles = s.candleLightingMinutes;
      if (candles == null) {
        await p.remove('${_kPrefix}candles');
      } else {
        await p.setInt('${_kPrefix}candles', candles);
      }
      await p.setString('${_kPrefix}havdalah', s.havdalah.name);
    } catch (_) {
      // Best effort: the in-memory value still applies for this session.
    }
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _save();
  }

  /// Picking a city also returns candle lighting to that city's custom.
  Future<void> setCity(String cityId) async {
    state = state.copyWith(cityId: cityId, clearCandleLightingMinutes: true);
    await _save();
  }

  Future<void> setCandleLightingMinutes(int minutes) async {
    state = state.copyWith(candleLightingMinutes: minutes);
    await _save();
  }

  Future<void> setHavdalah(HavdalahMethod method) async {
    state = state.copyWith(havdalah: method);
    await _save();
  }

  /// Turns using the phone's position on (asking for the location
  /// permission and reading a coarse position once) or off. Returns false
  /// when the position could not be read; the city stays in use then.
  Future<bool> setUseDevicePosition(bool value) async {
    if (!value) {
      state = state.copyWith(useDevicePosition: false);
      await _save();
      return true;
    }
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
      final Position position =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 15),
            ),
          );
      state = state.copyWith(
        useDevicePosition: true,
        deviceLatitude: position.latitude,
        deviceLongitude: position.longitude,
      );
      await _save();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final NotifierProvider<ZmanimSettingsNotifier, ZmanimSettings>
zmanimSettingsProvider =
    NotifierProvider<ZmanimSettingsNotifier, ZmanimSettings>(
      ZmanimSettingsNotifier.new,
    );

/// The times of [day] (a civil date) with the current settings, or null when
/// the times of day are turned off.
ZmanimDay? zmanimFor(ZmanimSettings settings, DateTime day) => !settings.enabled
    ? null
    : computeZmanim(
        day: day,
        location: settings.location,
        candleLightingMinutes: settings.effectiveCandleLightingMinutes,
        havdalah: settings.havdalah,
      );
