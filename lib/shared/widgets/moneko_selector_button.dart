import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// A tappable button that looks like an input field with a selector arrow.
/// Used for triggering pickers or menus.
class MonekoSelectorButton extends StatelessWidget {
  const MonekoSelectorButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.padding,
  });

  final String label;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Using standard iOS input colors as per MonekoInput style
    final backgroundColor =
        isDark ? AppTheme.iosInputDark : AppTheme.iosInputLight;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  color: theme.colorScheme.foreground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.unfold_more_rounded,
              color: theme.colorScheme.mutedForeground,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
