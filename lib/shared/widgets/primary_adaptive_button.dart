import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/moneko_text_scaling.dart';

class PrimaryAdaptiveButton extends StatelessWidget {
  const PrimaryAdaptiveButton({
    super.key,
    required this.onPressed,
    this.prefixIcon,
    required this.child,
    this.isExpanded = true,
  }) : _isOutlined = false;

  const PrimaryAdaptiveButton.outlined({
    super.key,
    required this.onPressed,
    this.prefixIcon,
    required this.child,
    this.isExpanded = true,
  }) : _isOutlined = true;

  final VoidCallback? onPressed;
  final Widget? prefixIcon;
  final Widget child;
  final bool isExpanded;
  final bool _isOutlined;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLargeText = MonekoTextScale.isAtLeast(context, 1.5);

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

    final borderRadius = BorderRadius.circular(16);
    final foreground = _isOutlined ? scheme.primary : scheme.primaryForeground;
    final button = CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color:
          _isOutlined ? scheme.surface.withValues(alpha: 0.0) : scheme.primary,
      disabledColor: _isOutlined
          ? scheme.surface.withValues(alpha: 0.0)
          : scheme.primary.withValues(alpha: 0.5),
      borderRadius: borderRadius,
      pressedOpacity: 0.7,
      onPressed: onPressed,
      child: DefaultTextStyle.merge(
        textAlign: TextAlign.center,
        maxLines: isLargeText ? null : 1,
        overflow: isLargeText ? null : TextOverflow.ellipsis,
        style: TextStyle(
          color: _isOutlined && onPressed == null
              ? foreground.withValues(alpha: 0.5)
              : foreground,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        child: content,
      ),
    );

    return SizedBox(
      width: isExpanded ? double.infinity : null,
      child: _isOutlined
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: onPressed == null
                      ? scheme.primary.withValues(alpha: 0.5)
                      : scheme.primary,
                ),
              ),
              child: button,
            )
          : button,
    );
  }
}
