import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LiquidPainter extends CustomPainter {
  final double fillLevel;
  final List<Color> colors;
  final double phase;
  final double amplitude;
  final Color? crestColor;

  LiquidPainter({
    required this.fillLevel,
    required this.colors,
    required this.phase,
    this.amplitude = 10.0,
    this.crestColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fillLevel <= 0) {
      return;
    }

    final baseHeight = size.height * (1 - fillLevel);
    // The body deepens toward the bottom of the card, like light passing
    // through a thicker volume of liquid.
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, baseHeight - amplitude),
        Offset(0, size.height),
        colors,
      );

    if (fillLevel >= 1.0) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final surface = Path()..moveTo(0, baseHeight);
    for (double x = 0; x <= size.width; x++) {
      final y = baseHeight +
          math.sin((x / size.width * 2 * math.pi) + phase) * amplitude;
      surface.lineTo(x, y);
    }

    final body = Path.from(surface)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(body, paint);

    final crest = crestColor;
    if (crest != null) {
      canvas.drawPath(
        surface,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = crest,
      );
    }
  }

  @override
  bool shouldRepaint(covariant LiquidPainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel ||
        !listEquals(oldDelegate.colors, colors) ||
        oldDelegate.phase != phase ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.crestColor != crestColor;
  }
}
