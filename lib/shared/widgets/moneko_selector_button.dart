import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'moneko_input.dart';

/// A tappable button that looks like an input field with a selector arrow.
/// Used for triggering pickers or menus.
class MonekoSelectorButton extends StatelessWidget {
  const MonekoSelectorButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.padding,
  })  : _isSpaceStyle = false,
        compact = false;

  const MonekoSelectorButton.space({
    super.key,
    required this.label,
    required this.onPressed,
    this.padding,
    this.compact = false,
  }) : _isSpaceStyle = true;

  final String label;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? padding;
  final bool _isSpaceStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 13 : 17,
              fontWeight: compact ? FontWeight.w400 : null,
              color: compact
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.foreground,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.unfold_more_rounded,
          color: theme.colorScheme.mutedForeground,
          size: compact ? 20 : 24,
        ),
      ],
    );
    return GestureDetector(
      onTap: onPressed,
      child: _isSpaceStyle
          ? MonekoInput.space(
              compact: compact,
              padding: padding ??
                  EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 20,
                      vertical: compact ? 8 : 24),
              child: content,
            )
          : Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.appleInputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: padding ??
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: content,
            ),
    );
  }
}
