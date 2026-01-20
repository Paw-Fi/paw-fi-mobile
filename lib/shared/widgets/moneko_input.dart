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
  });

  final Widget child;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppTheme.iosInputDark : AppTheme.iosInputLight;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      padding: padding,
      child: child,
    );
  }
}
