import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../settings/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _ChoiceTile<String?>(
            icon: Icons.language,
            title: l10n.settingsLanguage,
            value: settings.languageCode,
            options: {
              null: l10n.settingsLanguageSystem,
              'he': l10n.settingsLanguageHebrew,
              'en': l10n.settingsLanguageEnglish,
            },
            onChanged: controller.setLanguage,
          ),
          _ChoiceTile<ThemeMode>(
            icon: Icons.brightness_6,
            title: l10n.settingsTheme,
            value: settings.themeMode,
            options: {
              ThemeMode.system: l10n.settingsThemeSystem,
              ThemeMode.light: l10n.settingsThemeLight,
              ThemeMode.dark: l10n.settingsThemeDark,
            },
            onChanged: controller.setThemeMode,
          ),
          const Divider(),
          _ChoiceTile<bool>(
            icon: Icons.public,
            title: l10n.settingsLocation,
            subtitle: l10n.settingsLocationHint,
            value: settings.inIsrael,
            options: {
              true: l10n.settingsLocationIsrael,
              false: l10n.settingsLocationDiaspora,
            },
            onChanged: controller.setInIsrael,
          ),
          _ChoiceTile<ZmanimOpinion>(
            icon: Icons.schedule,
            title: l10n.settingsZmanimOpinion,
            value: settings.zmanimOpinion,
            options: {
              ZmanimOpinion.gra: l10n.settingsZmanimGra,
              ZmanimOpinion.mga: l10n.settingsZmanimMga,
            },
            onChanged: controller.setZmanimOpinion,
          ),
          _ChoiceTile<int>(
            icon: Icons.local_fire_department_outlined,
            title: l10n.settingsCandleLighting,
            value: settings.candleLightingMinutes,
            options: {
              for (final m in AppSettings.candleLightingOptions)
                m: l10n.settingsCandleLightingMinutes(m),
            },
            onChanged: controller.setCandleLightingMinutes,
          ),
        ],
      ),
    );
  }
}

/// A list tile showing the current choice; tapping opens a picker dialog.
class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        subtitle == null ? options[value]! : '${options[value]!}\n$subtitle',
      ),
      isThreeLine: subtitle != null,
      onTap: () async {
        // Wrap in a record so a `null` option can be told apart from
        // dismissing the dialog.
        final picked = await showDialog<(T,)>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(title),
            children: [
              for (final entry in options.entries)
                ListTile(
                  title: Text(entry.value),
                  trailing: entry.key == value ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, (entry.key,)),
                ),
            ],
          ),
        );
        if (picked != null) onChanged(picked.$1);
      },
    );
  }
}
