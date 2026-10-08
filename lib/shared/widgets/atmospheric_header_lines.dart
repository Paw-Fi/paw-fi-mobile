import 'package:flutter/material.dart';

class AtmosphericHeaderBackground extends StatelessWidget {
  const AtmosphericHeaderBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).width * 0.5,
            child: AtmosphericHeaderLines(color: color),
          ),
        ),
      ),
    );
  }
}

class AtmosphericHeaderLines extends StatelessWidget {
  const AtmosphericHeaderLines({
    super.key,
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AtmosphericHeaderLinesPainter(color: color),
    );
  }
}

class _AtmosphericHeaderLinesPainter extends CustomPainter {
  const _AtmosphericHeaderLinesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final width = size.width;
    final height = size.height;

    for (var i = 1; i <= 3; i++) {
      final path = Path()
        ..moveTo(-20, height * 0.22 * i)
        ..quadraticBezierTo(
          width * 0.5,
          -10.0 + (i * 12.0),
          width + 20,
          height * 0.32 * i,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AtmosphericHeaderLinesPainter oldDelegate) =>
      oldDelegate.color != color;
}
