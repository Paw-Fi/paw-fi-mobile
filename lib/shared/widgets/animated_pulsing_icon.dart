import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class AnimatedPulsingIcon extends HookWidget {
  const AnimatedPulsingIcon({
    super.key,
    required this.color,
    this.icon = Icons.auto_awesome_rounded,
    this.containerSize = 72.0,
    this.iconSize = 36.0,
  });

  final Color color;
  final IconData icon;
  final double containerSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    final scale = useAnimation(
      Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      ),
    );

    final opacity = useAnimation(
      Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      ),
    );

    return Transform.scale(
      scale: scale,
      child: Container(
        width: containerSize,
        height: containerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.1 * opacity),
        ),
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}
