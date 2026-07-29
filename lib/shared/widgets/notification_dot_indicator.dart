import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Overlays a small, animated notification dot on a control.
class NotificationDotIndicator extends StatelessWidget {
  const NotificationDotIndicator({
    super.key,
    required this.child,
    required this.isVisible,
    this.isLoading = false,
    this.top = 4,
    this.right = 4,
  });

  final Widget child;
  final bool isVisible;
  final bool isLoading;
  final double top;
  final double right;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: top,
          right: right,
          child: IgnorePointer(
            child: AnimatedScale(
              scale: isVisible || isLoading ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: isVisible || isLoading ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isLoading
                        ? colorScheme.skeletonBase
                        : colorScheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
