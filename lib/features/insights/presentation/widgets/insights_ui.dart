import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// A modern, compact metric pill with icon, label and value.
/// Designed to replace plain text summaries with a glanceable UI.
class MetricPill extends StatelessWidget {
  const MetricPill({
    super.key,
    required this.colorScheme,
    required this.icon,
    required this.label,
    required this.value,
    this.tint,
  });

  final ColorScheme colorScheme;
  final IconData icon;
  final String label;
  final String value;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final surface = colorScheme.card;
    final border = colorScheme.border.withValues(alpha: 0.5);
    final bg = (tint ?? colorScheme.primary).withValues(alpha: 0.08);
    final iconColor = (tint ?? colorScheme.primary);

    return Container
    (
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.mutedForeground,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// A subtle section card with modern spacing and border styling.
class InsightsSectionCard extends StatelessWidget {
  const InsightsSectionCard({super.key, required this.colorScheme, required this.child});

  final ColorScheme colorScheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.border.withValues(alpha: 0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

