import 'package:flutter/material.dart';

/// Shared color utilities for pockets.
/// Used by both PocketCard and PocketListTile to ensure consistent visuals.
Color getPocketColor(String? colorHex, Color fallback) {
  if (colorHex == null) return fallback;
  try {
    return Color(int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000);
  } catch (_) {
    return fallback;
  }
}

List<Color> getProgressGradient(
  Color baseColor,
  double progress,
  bool isOverBudget,
  bool isDarkMode,
) {
  final hsl = HSLColor.fromColor(baseColor);

  if (isOverBudget) {
    // Over budget: Use red tones
    final errorColor = isDarkMode
        ? HSLColor.fromAHSL(1.0, 0, 0.7, 0.5) // Bright red for dark mode
        : HSLColor.fromAHSL(1.0, 0, 0.7, 0.45); // Deep red for light mode
    return [
      errorColor.toColor(),
      errorColor
          .withLightness((errorColor.lightness - 0.1).clamp(0.0, 1.0))
          .toColor(),
    ];
  } else if (progress > 0.9) {
    // Warning state (90-100%): Use orange/amber tones
    final warningColor = isDarkMode
        ? HSLColor.fromAHSL(1.0, 30, 0.8, 0.55) // Bright orange for dark mode
        : HSLColor.fromAHSL(1.0, 30, 0.8, 0.5); // Deep orange for light mode
    return [
      warningColor.toColor(),
      warningColor
          .withLightness((warningColor.lightness - 0.1).clamp(0.0, 1.0))
          .toColor(),
    ];
  } else {
    // Normal state: Use pocket's custom color with appropriate shading
    if (isDarkMode) {
      // Dark mode: Brighten the base color for visibility
      final brightened =
          hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0));
      return [
        brightened.toColor(),
        brightened
            .withLightness((brightened.lightness - 0.15).clamp(0.0, 1.0))
            .toColor(),
      ];
    } else {
      // Light mode: Use base color with slight darkening for gradient
      return [
        baseColor,
        hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor(),
      ];
    }
  }
}
