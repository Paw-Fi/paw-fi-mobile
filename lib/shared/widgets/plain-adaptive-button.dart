import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

class PlainAdaptiveButton extends StatelessWidget {
  const PlainAdaptiveButton({
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
      onPressed: onPressed,
      style: AdaptiveButtonStyle.plain,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.primary),
        child: child,
      ),
    );
  }
}
