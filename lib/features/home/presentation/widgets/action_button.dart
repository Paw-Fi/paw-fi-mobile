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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorScheme.border),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label!,
              style: TextStyle(
                color: colorScheme.foreground,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          color: colorScheme.primary,
          elevation: 4,
          child: IconButton(
            onPressed: onPressed,
            icon: icon,
            color: colorScheme.primaryForeground,
          ),
        ),
      ],
    );
  }
}
