import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

@immutable
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    this.onPressed,
    required this.icon,
    this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label!,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        SizedBox(
          width: 48,
          height: 48,
          child: Material(
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            color: colorScheme.primary,
            elevation: 2,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    color: colorScheme.primaryForeground,
                    size: 22,
                  ),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
