import 'package:flutter/material.dart';

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
    final backgroundColor = Theme.of(context).colorScheme.surfaceContainer;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(10),
      ),
      padding: padding,
      child: child,
    );
  }
}
