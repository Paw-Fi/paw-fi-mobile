import 'package:flutter/widgets.dart';

enum SpotlightPlacement {
  top,
  bottom,
  left,
  right,
  center,
}

class SpotlightStep {
  final String id;

  /// Key attached to the widget you want to highlight
  final GlobalKey targetKey;
  final String title;
  final String description;
  final SpotlightPlacement placement;
  final double padding;
  final double borderRadius;

  const SpotlightStep({
    required this.id,
    required this.targetKey,
    required this.title,
    required this.description,
    this.placement = SpotlightPlacement.bottom,
    this.padding = 4,
    this.borderRadius = 8,
  });
}
