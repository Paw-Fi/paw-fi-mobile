import 'package:flutter/cupertino.dart';
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

    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        color: scheme.primary,
        disabledColor: scheme.primary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        pressedOpacity: 0.7,
        onPressed: onPressed,
        child: DefaultTextStyle.merge(
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.primaryForeground,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          child: content,
        ),
      ),
    );
  }
}
