import 'package:flutter/material.dart';

/// One of Google Calendar's 11 event colors (M10). The [id] is Google's
/// `colorId`, so a color picked here shows the same in Google Calendar and
/// vice versa.
class EventColorOption {
  const EventColorOption(this.id, this.color);

  /// Google Calendar `colorId` ("1".."11").
  final String id;
  final Color color;
}

/// Google Calendar's event palette, in Google's own order.
const List<EventColorOption> kEventColorOptions = <EventColorOption>[
  EventColorOption('1', Color(0xFF7986CB)), // Lavender
  EventColorOption('2', Color(0xFF33B679)), // Sage
  EventColorOption('3', Color(0xFF8E24AA)), // Grape
  EventColorOption('4', Color(0xFFE67C73)), // Flamingo
  EventColorOption('5', Color(0xFFF6BF26)), // Banana
  EventColorOption('6', Color(0xFFF4511E)), // Tangerine
  EventColorOption('7', Color(0xFF039BE5)), // Peacock
  EventColorOption('8', Color(0xFF616161)), // Graphite
  EventColorOption('9', Color(0xFF3F51B5)), // Blueberry
  EventColorOption('10', Color(0xFF0B8043)), // Basil
  EventColorOption('11', Color(0xFFD50000)), // Tomato
];

/// The display color for an event's [colorId] — the theme's primary color
/// when it has none (or an id we don't know).
Color eventColor(String? colorId, ColorScheme colorScheme) {
  for (final EventColorOption option in kEventColorOptions) {
    if (option.id == colorId) {
      return option.color;
    }
  }
  return colorScheme.primary;
}

/// Background/foreground for an event drawn as a filled block or chip (week
/// and day views): the theme's primary container for the default color,
/// otherwise the event color with a readable text color on top.
({Color background, Color foreground}) eventSurfaceColors(
  String? colorId,
  ColorScheme colorScheme,
) {
  if (colorId == null) {
    return (
      background: colorScheme.primaryContainer,
      foreground: colorScheme.onPrimaryContainer,
    );
  }
  final Color background = eventColor(colorId, colorScheme);
  final bool dark =
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
  return (
    background: background,
    foreground: dark ? Colors.white : Colors.black87,
  );
}
