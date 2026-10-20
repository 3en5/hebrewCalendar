import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/text_size_provider.dart';

/// "גודל טקסט" in settings: a slider from 90% to 140% in 5% steps (owner
/// requests 2026-10-15 and 2026-10-20), on top of the phone's font size.
/// The app follows the slider while dragging, and keeps the size when the
/// finger lifts; the month view's cells grow with it.
class TextSizeTile extends ConsumerWidget {
  const TextSizeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double size = ref.watch(textSizeProvider);
    final TextSizeNotifier notifier = ref.read(textSizeProvider.notifier);
    final String percent = l10n.settingsTextSizePercent((size * 100).round());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.format_size),
          title: Text(l10n.settingsTextSizeTitle),
          subtitle: Text(l10n.settingsTextSizeSubtitle),
          trailing: Text(
            percent,
            key: const ValueKey<String>('text-size-value'),
            style: TextStyle(fontSize: bodyRem, fontWeight: FontWeight.w700),
          ),
        ),
        Row(
          children: <Widget>[
            Text('א', style: TextStyle(fontSize: bodySmallRem)),
            Expanded(
              child: Slider(
                key: const ValueKey<String>('text-size-slider'),
                min: kTextSizeMin,
                max: kTextSizeMax,
                divisions: kTextSizeSteps,
                value: size.clamp(kTextSizeMin, kTextSizeMax),
                label: percent,
                onChanged: notifier.preview,
                onChangeEnd: (double v) => unawaited(notifier.set(v)),
              ),
            ),
            Text('א', style: TextStyle(fontSize: titleLargeRem)),
          ],
        ),
      ],
    );
  }
}
