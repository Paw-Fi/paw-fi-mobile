import 'package:flutter/material.dart';
import 'package:moneko/shared/widgets/bundled_icon_metrics.dart';

Widget buildBundledIconImage(String asset, {required double size}) {
  final (scale, offsetX, offsetY) =
      bundledIconMetrics[asset] ?? (1.0, 0.0, 0.0);
  final imageSize = size * scale;

  return SizedBox.square(
    dimension: size,
    child: ClipRect(
      child: OverflowBox(
        minWidth: imageSize,
        maxWidth: imageSize,
        minHeight: imageSize,
        maxHeight: imageSize,
        child: Transform.translate(
          offset: Offset(offsetX * size, offsetY * size),
          child: Image.asset(
            asset,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => SizedBox.square(dimension: imageSize),
          ),
        ),
      ),
    ),
  );
}
