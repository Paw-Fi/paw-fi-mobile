import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

class PrimaryAdaptiveButton extends StatelessWidget {
  const PrimaryAdaptiveButton({
    super.key,
    required this.onPressed,
    this.prefixIcon,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget? prefixIcon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Widget content = prefixIcon == null
        ? child
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              prefixIcon!,
              const SizedBox(width: 8),
              Flexible(child: child),
            ],
          );

    return AdaptiveButton.child(
      color: scheme.primary,
      onPressed: onPressed,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.primaryForeground),
            child: content,
          ),
        ),
      ),
    );
  }
}
