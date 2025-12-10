import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'liquid_painter.dart';

class LiquidPocket extends HookWidget {
  final double fillLevel;
  final Color color;
  final Widget? child;

  const LiquidPocket({
    super.key,
    required this.fillLevel,
    required this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(seconds: 2),
    )..repeat();

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          // Background (empty part)
          Container(color: color.withValues(alpha: 0.1)),

          // Liquid Layer 1 (Back)
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return CustomPaint(
                painter: LiquidPainter(
                  fillLevel: fillLevel,
                  color: color.withValues(alpha: 0.3),
                  phase: controller.value * 2 * 3.14159,
                  amplitude: 8,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Liquid Layer 2 (Front)
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return CustomPaint(
                painter: LiquidPainter(
                  fillLevel: fillLevel,
                  color: color,
                  phase: (controller.value * 2 * 3.14159) + 1.5, // Offset phase
                  amplitude: 10,
                ),
                size: Size.infinite,
              );
            },
          ),

          if (child != null) child!,
        ],
      ),
    );
  }
}
