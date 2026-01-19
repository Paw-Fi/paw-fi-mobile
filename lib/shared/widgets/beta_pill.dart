import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

class BetaPill extends StatelessWidget {
  const BetaPill({
    super.key,
    this.text = 'BETA',
    this.backgroundColor,
    this.textColor,
    this.fontSize = 10.0,
    this.fontWeight = FontWeight.w600,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Use theme colors with fallbacks if not provided
    final bgColor = backgroundColor ??
        (scheme.brightness == Brightness.dark
            ? scheme.warning.withValues(alpha: 0.2)
            : scheme.warning.withValues(alpha: 0.1));

    final txtColor = textColor ??
        (scheme.brightness == Brightness.dark
            ? scheme.warning
            : scheme.warning);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: scheme.brightness == Brightness.dark
              ? scheme.warning.withValues(alpha: 0.3)
              : scheme.warning.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: txtColor,
          height: 1.0,
        ),
      ),
    );
  }
}
