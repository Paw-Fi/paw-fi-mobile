import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

class SeamlessHeaderBackground extends StatelessWidget {
  const SeamlessHeaderBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _HeaderBackdropPainter(
              colors: colors.seamlessHeaderBackdropGradient,
              borderColor: colors.seamlessHeaderBackdropBorder,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBackdropPainter extends CustomPainter {
  const _HeaderBackdropPainter({
    required this.colors,
    required this.borderColor,
  });

  final List<Color> colors;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final circles = [
      Rect.fromCircle(
        center: Offset(size.width * 0.04, -unit * 0.16),
        radius: unit * 0.90,
      ),
      Rect.fromCircle(
        center: Offset(size.width * 0.99, unit * 0.19),
        radius: unit * 0.38,
      ),
      Rect.fromCircle(
        center: Offset(size.width * 0.78, unit * 0.60),
        radius: unit * 0.62,
      ),
    ];
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final circle in circles) {
      canvas.drawOval(
        circle,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ).createShader(circle),
      );
      canvas.drawOval(
        circle,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeaderBackdropPainter oldDelegate) =>
      !listEquals(oldDelegate.colors, colors) ||
      oldDelegate.borderColor != borderColor;
}
