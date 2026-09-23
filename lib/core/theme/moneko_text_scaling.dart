import 'package:flutter/material.dart';

/// Text scaling modes for components with different layout constraints.
enum MonekoTextScaling {
  /// Preserve the user's complete system text scale.
  accessible,

  /// Keep dense financial components readable without letting extreme scaling
  /// break their compact geometry.
  constrained,

  /// Use a tighter bound for inherently compact navigation and micro UI.
  compact,
}

extension MonekoTextScalingValues on MonekoTextScaling {
  double? get maxScaleFactor {
    switch (this) {
      case MonekoTextScaling.accessible:
        return null;
      case MonekoTextScaling.constrained:
        return 1.35;
      case MonekoTextScaling.compact:
        return 1.2;
    }
  }
}

/// Applies the smallest text-scaling policy needed by a constrained subtree.
class MonekoTextScale extends StatelessWidget {
  const MonekoTextScale({
    required this.mode,
    required this.child,
    super.key,
  });

  final MonekoTextScaling mode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxScaleFactor = mode.maxScaleFactor;
    if (maxScaleFactor == null) return child;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxScaleFactor,
      child: child,
    );
  }

  /// Reads the unmodified system scale so layouts can adapt only when needed.
  static bool isAtLeast(BuildContext context, double scale) {
    final textScaler = MediaQuery.textScalerOf(context);
    return textScaler.scale(16) / 16 >= scale;
  }
}
