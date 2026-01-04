import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

class OutlinedAdaptiveButton extends StatelessWidget {
  const OutlinedAdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: scheme.primary,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: AdaptiveButton.child(
        color: scheme.surface.withValues(alpha: 0.0),
        style: AdaptiveButtonStyle.plain,
        onPressed: onPressed,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.primary),
          child: child,
        ),
      ),
    );
  }
}
