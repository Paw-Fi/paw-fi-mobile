import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Paints the wallet card surface: an organic mesh of soft color sources,
/// ambient lighting and a fine edge highlight following [shape].
///
/// Mesh coordinates are normalized to the card width and [referenceHeight],
/// so a collapsed card shows the upper part of the same surface it reveals
/// when expanded. Only gradients are used; no runtime blur filters.
class WalletMeshGradientPainter extends CustomPainter {
  const WalletMeshGradientPainter({
    required this.palette,
    required this.shape,
    this.referenceHeight = 240,
  });

  final WalletColorPalette palette;
  final CustomClipper<Path> shape;
  final double referenceHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final width = size.width;
    final height = referenceHeight;
    canvas.drawRect(bounds, Paint()..color = palette.backgroundStart);
    for (final layer in palette.meshLayers) {
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
            palette.edgeHighlight,
            palette.edgeHighlight.withValues(alpha: 0),
            palette.edgeLowlight,
          ],
          const [0, 0.45, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant WalletMeshGradientPainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.shape != shape ||
      oldDelegate.referenceHeight != referenceHeight;
}
