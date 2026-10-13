import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// A unified input container component that adapts its background color
/// based on the proprietary iOS-style theme requirements:
/// Light: #FFFFFF
/// Dark: #2C2C2E
class MonekoInput extends StatelessWidget {
  const MonekoInput({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
  })  : _isSpaceStyle = false,
        compact = false;

  const MonekoInput.space({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.compact = false,
  }) : _isSpaceStyle = true;

  final Widget child;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool _isSpaceStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: compact ? const BoxConstraints(minHeight: 48) : null,
      decoration: BoxDecoration(
        color: _isSpaceStyle
            ? (compact ? scheme.card : scheme.appleInputBackground)
            : scheme.surfaceContainer,
        borderRadius: borderRadius ??
            BorderRadius.circular(_isSpaceStyle && !compact ? 24 : 10),
        boxShadow: _isSpaceStyle
            ? (compact
                ? scheme.groupedCardShadows
                : [
                    BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4))
                  ])
            : null,
      ),
      padding: padding,
      child: child,
    );
  }
}
