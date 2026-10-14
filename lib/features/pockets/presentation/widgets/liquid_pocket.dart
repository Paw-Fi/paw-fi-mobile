import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'liquid_painter.dart';

class LiquidPocket extends HookWidget {
  final double fillLevel;
  final PocketColorPalette palette;

  const LiquidPocket({
    super.key,
    required this.fillLevel,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(seconds: 2),
    )..repeat();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final phase = controller.value * 2 * 3.14159;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Liquid Layer 1 (Back)
              CustomPaint(
                painter: LiquidPainter(
                  fillLevel: fillLevel,
                  colors: [palette.liquidBack, palette.liquidBack],
                  phase: phase,
                  amplitude: 8,
                ),
              ),
              // Liquid Layer 2 (Front)
              CustomPaint(
                painter: LiquidPainter(
                  fillLevel: fillLevel,
                  colors: [palette.liquidFront, palette.liquidFrontDeep],
                  phase: phase + 1.5, // Offset phase
                  amplitude: 10,
                  crestColor: palette.liquidCrest,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
