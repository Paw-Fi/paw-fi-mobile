import 'package:flutter/widgets.dart';

/// Shared text styling constants matching CategoryBreakdownChart.tsx web component
class WidgetTextStyles {
  // Primary title style (matches web h1)
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // Date range subtitle style (matches web p tag)
  static const TextStyle subtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  // Primary amount style (compact, matching web financial amounts)
  static const TextStyle amount = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
  );

  // Category name style
  static const TextStyle category = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  // Category amount style
  static const TextStyle categoryAmount = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  // Date range label style (non-uppercase)
  static TextStyle dateLabel(Color color) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: color,
  );
}
