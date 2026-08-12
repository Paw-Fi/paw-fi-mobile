import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

/// A reusable color picker with consistent behavior across platforms.
class AdaptiveColorPicker {
  /// Shows a color picker dialog adapted for the current platform.
  ///
  /// [context] - The build context
  /// [startingColor] - The initial color to display
  /// [onColorChanged] - Callback called when color is selected
  /// [label] - Optional label for the color picker title
  static void show({
    required BuildContext context,
    required Color startingColor,
    required ValueChanged<Color> onColorChanged,
    String? label,
  }) {
    MonekoAlertDialog.show(
      context: context,
      title: label ?? context.l10n.selectColor,
      confirmLabel: context.l10n.done,
      showCancelButton: false,
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: startingColor,
          onColorChanged: onColorChanged,
        ),
      ),
    );
  }
}

/// A preset color row with a leading custom-color swatch.
///
/// The leading swatch keeps the gradient affordance until a non-preset color
/// has been selected, then becomes that color so the current custom choice is
/// visible without reopening the picker.
class ColorSelectionSwatchRow extends StatelessWidget {
  const ColorSelectionSwatchRow({
    required this.selectedHex,
    required this.onChanged,
    required this.presetColors,
    required this.sweepColors,
    required this.fallbackColor,
    super.key,
  });

  final String? selectedHex;
  final ValueChanged<String> onChanged;
  final List<Color> presetColors;
  final List<Color> sweepColors;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedColor = _colorFromHex(selectedHex);
    final selectedNormalizedHex = _normalizedHex(selectedHex);
    final isCustomColor = selectedColor != null &&
        !presetColors
            .map(_colorToHex)
            .map(_normalizedHex)
            .contains(selectedNormalizedHex);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presetColors.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: () => AdaptiveColorPicker.show(
                context: context,
                startingColor: selectedColor ?? fallbackColor,
                onColorChanged: (color) => onChanged(_colorToHex(color)),
                label: context.l10n.selectColor,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCustomColor ? selectedColor : null,
                  gradient:
                      isCustomColor ? null : SweepGradient(colors: sweepColors),
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.border),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isCustomColor
                      ? Icon(
                          Icons.check,
                          key: const ValueKey('custom-color-selected'),
                          color: colorScheme.primaryForeground,
                          size: 20,
                        )
                      : Icon(
                          Icons.colorize,
                          key: const ValueKey('custom-color-picker'),
                          color: colorScheme.primaryForeground,
                          size: 20,
                        ),
                ),
              ),
            );
          }

          final presetColor = presetColors[index - 1];
          final isSelected =
              selectedNormalizedHex == _normalizedHex(_colorToHex(presetColor));
          return GestureDetector(
            onTap: () => onChanged(_colorToHex(presetColor)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: presetColor,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: colorScheme.foreground, width: 2)
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        key: const ValueKey('preset-color-selected'),
                        color: colorScheme.primaryForeground,
                        size: 20,
                      )
                    : const SizedBox(key: ValueKey('preset-color-unselected')),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _colorToHex(Color color) {
  String component(double value) {
    final byte = (value * 255.0).round().clamp(0, 255).toInt();
    return byte.toRadixString(16).padLeft(2, '0');
  }

  return '#${component(color.r)}${component(color.g)}${component(color.b)}';
}

Color? _colorFromHex(String? hex) {
  final normalizedHex = _normalizedHex(hex);
  if (normalizedHex == null) return null;
  try {
    return Color(0xFF000000 | int.parse(normalizedHex, radix: 16));
  } on FormatException {
    return null;
  }
}

String? _normalizedHex(String? hex) {
  final value = hex?.trim().replaceFirst('#', '');
  return value != null && RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)
      ? value.toLowerCase()
      : null;
}
