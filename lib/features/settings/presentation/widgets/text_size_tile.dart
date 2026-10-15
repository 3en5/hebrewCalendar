import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/text_size_provider.dart';

/// "גודל טקסט" in settings (owner request 2026-10-15): 100% to 140%, on top
/// of the phone's font size; the month view's cells grow with it.
class TextSizeTile extends ConsumerWidget {
  const TextSizeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double size = ref.watch(textSizeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.format_size),
          title: Text(l10n.settingsTextSizeTitle),
          subtitle: Text(l10n.settingsTextSizeSubtitle),
        ),
        SegmentedButton<double>(
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
              EdgeInsets.symmetric(horizontal: spacingXs),
            ),
          ),
          segments: <ButtonSegment<double>>[
            for (final double option in kTextSizeOptions)
              ButtonSegment<double>(
                value: option,
                label: FittedBox(
                  key: ValueKey<String>('text-size-${(option * 100).round()}'),
                  fit: BoxFit.scaleDown,
                  child: Text(
                    l10n.settingsTextSizePercent((option * 100).round()),
                    maxLines: 1,
                  ),
                ),
              ),
          ],
          selected: <double>{size},
          onSelectionChanged: (Set<double> s) =>
              unawaited(ref.read(textSizeProvider.notifier).set(s.first)),
        ),
      ],
    );
  }
}
