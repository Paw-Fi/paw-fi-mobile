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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
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
  const InsightsSectionCard(
      {super.key, required this.colorScheme, required this.child});

  final ColorScheme colorScheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.homeCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}
