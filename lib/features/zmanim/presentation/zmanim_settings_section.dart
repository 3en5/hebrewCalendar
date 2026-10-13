import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/zmanim/zmanim.dart';
import '../../../domain/zmanim/zmanim_location.dart';
import '../../../l10n/app_localizations.dart';
import '../application/zmanim_settings.dart';

/// Candle lighting choices besides the city's custom (sketch 12).
const List<int> kCandleLightingChoices = <int>[18, 20, 30, 40];

/// The settings screen's "זמני היום" section (M21, sketch 12): the city (or
/// the phone's position), candle lighting minutes and the end-of-Shabbat
/// method. Uses ListTile + Switch so the Google sync section stays the
/// screen's only SwitchListTile.
class ZmanimSettingsSection extends ConsumerWidget {
  const ZmanimSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ZmanimSettings settings = ref.watch(zmanimSettingsProvider);
    final ZmanimSettingsNotifier notifier = ref.read(
      zmanimSettingsProvider.notifier,
    );
    final int? customMinutes = settings.candleLightingMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.only(bottom: spacingXs),
          child: Text(
            l10n.zmanimSettingsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ListTile(
          key: const ValueKey<String>('zmanim-city'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.location_city_outlined),
          title: Text(l10n.zmanimCity),
          subtitle: Text(settings.city.name),
          enabled: !settings.useDevicePosition,
          trailing: const Icon(Icons.chevron_left),
          onTap: () => unawaited(_pickCity(context, notifier, settings)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.my_location),
          title: Text(l10n.zmanimUseDevice),
          subtitle: Text(l10n.zmanimUseDeviceSubtitle),
          trailing: Switch(
            key: const ValueKey<String>('zmanim-device-switch'),
            value: settings.useDevicePosition,
            onChanged: (bool value) async {
              final bool ok = await notifier.setUseDevicePosition(value);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.zmanimUseDeviceFailed)),
                );
              }
            },
          ),
        ),
        ListTile(
          key: const ValueKey<String>('zmanim-candles'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.local_fire_department_outlined),
          title: Text(l10n.zmanimCandleSetting),
          subtitle: Text(
            customMinutes == null
                ? l10n.zmanimCandleCityCustom(
                    settings.city.candleLightingMinutes,
                  )
                : l10n.zmanimCandleMinutes(customMinutes),
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => unawaited(_pickCandles(context, notifier, settings)),
        ),
        ListTile(
          key: const ValueKey<String>('zmanim-havdalah'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.nights_stay_outlined),
          title: Text(l10n.zmanimHavdalahSetting),
          subtitle: Text(havdalahLabel(l10n, settings.havdalah)),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => unawaited(_pickHavdalah(context, notifier, settings)),
        ),
      ],
    );
  }

  Future<void> _pickCity(
    BuildContext context,
    ZmanimSettingsNotifier notifier,
    ZmanimSettings settings,
  ) async {
    final String? id = await _choose<String>(
      context,
      AppLocalizations.of(context).zmanimCity,
      <String, String>{
        for (final ZmanimLocation city in kZmanimCities) city.id: city.name,
      },
      settings.cityId,
    );
    if (id != null) {
      await notifier.setCity(id);
    }
  }

  Future<void> _pickCandles(
    BuildContext context,
    ZmanimSettingsNotifier notifier,
    ZmanimSettings settings,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int cityMinutes = settings.city.candleLightingMinutes;
    // 0 stands for "the city's custom".
    final int? minutes =
        await _choose<int>(context, l10n.zmanimCandleSetting, <int, String>{
          0: l10n.zmanimCandleCityCustom(cityMinutes),
          for (final int m in kCandleLightingChoices)
            m: l10n.zmanimCandleMinutes(m),
        }, settings.candleLightingMinutes ?? 0);
    if (minutes == null) {
      return;
    }
    if (minutes == 0) {
      await notifier.setCity(settings.cityId);
    } else {
      await notifier.setCandleLightingMinutes(minutes);
    }
  }

  Future<void> _pickHavdalah(
    BuildContext context,
    ZmanimSettingsNotifier notifier,
    ZmanimSettings settings,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final HavdalahMethod? method = await _choose<HavdalahMethod>(
      context,
      l10n.zmanimHavdalahSetting,
      <HavdalahMethod, String>{
        for (final HavdalahMethod m in HavdalahMethod.values)
          m: havdalahLabel(l10n, m),
      },
      settings.havdalah,
    );
    if (method != null) {
      await notifier.setHavdalah(method);
    }
  }
}

String havdalahLabel(AppLocalizations l10n, HavdalahMethod method) =>
    switch (method) {
      HavdalahMethod.degrees8Point5 => l10n.zmanimHavdalahDegrees,
      HavdalahMethod.minutes72 => l10n.zmanimHavdalah72,
    };

/// A simple single-choice dialog; returns the picked key or null.
Future<T?> _choose<T>(
  BuildContext context,
  String title,
  Map<T, String> options,
  T current,
) => showDialog<T>(
  context: context,
  builder: (BuildContext context) => SimpleDialog(
    title: Text(title),
    children: <Widget>[
      for (final MapEntry<T, String> option in options.entries)
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(option.key),
          child: Row(
            children: <Widget>[
              Icon(
                option.key == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: rem(1.25),
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: spacingSm),
              Expanded(child: Text(option.value)),
            ],
          ),
        ),
    ],
  ),
);
