import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

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
  ColorScheme scheme,
  Color baseColor,
  double progress,
  bool isOverBudget,
) {
  return AppTheme.pocketProgressGradient(
    scheme: scheme,
    baseColor: baseColor,
    progress: progress,
    isOverBudget: isOverBudget,
  );
}
