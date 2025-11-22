import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

class SubtleAdaptiveButton extends StatelessWidget {
  const SubtleAdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdaptiveButton.child(
      color: scheme.surfaceContainerHighest,
      onPressed: onPressed,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onSurface),
        child: child,
      ),
    );
  }
}
