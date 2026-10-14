import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Paints a [MeshSurface]: an organic mesh of soft color sources, ambient
/// lighting and a fine edge highlight following [shape].
///
/// Mesh coordinates are normalized to the width and [referenceHeight] (the
/// painted height when null), so a partially revealed card can show the
/// upper part of the same surface. Only gradients are used; no blur filters.
class MeshGradientPainter extends CustomPainter {
  const MeshGradientPainter({
    required this.surface,
    required this.shape,
    this.referenceHeight,
  });

  final MeshSurface surface;
  final CustomClipper<Path> shape;
  final double? referenceHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final width = size.width;
    final height = referenceHeight ?? size.height;
    canvas.drawRect(bounds, Paint()..color = surface.base);
    for (final layer in surface.layers) {
      final center = layer.center;
      if (center == null) {
        canvas.drawRect(
          bounds,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, layer.begin * height),
              Offset(0, layer.end * height),
              layer.colors,
              layer.stops,
            ),
        );
        continue;
      }
      // A unit circle scaled into an ellipse: the falloff reaches zero alpha
      // exactly at its edge, so the drawn shape never shows.
      canvas
        ..save()
        ..translate(center.dx * width, center.dy * height)
        ..scale(layer.radius!.width * width, layer.radius!.height * height)
        ..drawCircle(
          Offset.zero,
          1,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset.zero,
              1,
              layer.colors,
              layer.stops,
            ),
        )
        ..restore();
    }
    // Light catches the upper edge and fades; a faint tinted lower edge
    // separates pale surfaces from the page. Half the stroke is clipped away.
    canvas.drawPath(
      shape.getClip(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [
            surface.edgeHighlight,
            surface.edgeHighlight.withValues(alpha: 0),
            surface.edgeLowlight,
          ],
          const [0, 0.45, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant MeshGradientPainter oldDelegate) =>
      oldDelegate.surface != surface ||
      oldDelegate.shape != shape ||
      oldDelegate.referenceHeight != referenceHeight;
}

/// Rounded-rectangle outline for [MeshGradientPainter] edge highlights.
class RoundedRectClipper extends CustomClipper<Path> {
  const RoundedRectClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ));

  @override
  bool shouldReclip(covariant RoundedRectClipper oldClipper) =>
      oldClipper.radius != radius;
}
