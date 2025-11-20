import 'dart:math' as math;
import 'package:flutter/material.dart';

class LiquidPainter extends CustomPainter {
  final double fillLevel;
  final Color color;
  final double phase;
  final double amplitude;

  LiquidPainter({
    required this.fillLevel,
    required this.color,
    required this.phase,
    this.amplitude = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // If empty or full, draw simple rect
    if (fillLevel <= 0) {
      return;
    }
    if (fillLevel >= 1.0) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final baseHeight = size.height * (1 - fillLevel);

    path.moveTo(0, baseHeight);

    for (double x = 0; x <= size.width; x++) {
      final y = baseHeight +
          math.sin((x / size.width * 2 * math.pi) + phase) * amplitude;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LiquidPainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel ||
        oldDelegate.color != color ||
        oldDelegate.phase != phase ||
        oldDelegate.amplitude != amplitude;
  }
}
