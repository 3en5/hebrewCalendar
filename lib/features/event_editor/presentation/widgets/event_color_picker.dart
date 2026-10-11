import 'package:flutter/material.dart';

import '../../../../core/theme/dimens.dart';
import '../../../../core/theme/event_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// A row of color swatches for the event editor (M10): the default color
/// first (null), then Google Calendar's 11 event colors.
class EventColorPicker extends StatelessWidget {
  const EventColorPicker({
    required this.selectedColorId,
    required this.onChanged,
    super.key,
  });

  final String? selectedColorId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: spacingSm,
      runSpacing: spacingSm,
      children: <Widget>[
        _Swatch(
          color: colorScheme.primary,
          selected: selectedColorId == null,
          tooltip: l10n.eventColorDefault,
          onTap: () => onChanged(null),
        ),
        for (final EventColorOption option in kEventColorOptions)
          _Swatch(
            key: ValueKey<String>('event-color-${option.id}'),
            color: option.color,
            selected: selectedColorId == option.id,
            tooltip: l10n.eventColorOption(option.id),
            onTap: () => onChanged(option.id),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final Color color;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double size = rem(2.0);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: size / 2,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 2.5,
                    )
                  : null,
            ),
            child: selected
                ? Icon(Icons.done, size: rem(1.1), color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}
