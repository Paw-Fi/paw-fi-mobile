import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/pockets/presentation/widgets/pocket_card.dart';
import 'package:moneko/features/utils/currency.dart';

class PocketListTile extends StatelessWidget {
  const PocketListTile({
    super.key,
    required this.pocket,
    required this.colorScheme,
    required this.totalBudget,
    required this.onTap,
  });

  final PocketEnvelope pocket;
  final ColorScheme colorScheme;
  final double totalBudget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final limit = pocket.getLimit(totalBudget);
    final progress = limit > 0 ? (pocket.spent / limit) : 0.0;
    final isOverBudget = pocket.isOverBudget(totalBudget);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color baseColor = getPocketColor(pocket.color, colorScheme.primary);
    if (isDarkMode && pocket.color != null) {
      final hsl = HSLColor.fromColor(baseColor);
      baseColor =
          hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    }

    final iconData = getPocketIconData(pocket.icon);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                size: 24,
                color: baseColor,
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pocket.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      if (isOverBudget) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.priority_high_rounded,
                          color: colorScheme.error,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 6,
                      width: double.infinity,
                      color: colorScheme.onSurface.withValues(alpha: 0.05),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: getProgressGradient(
                                baseColor,
                                progress,
                                isOverBudget,
                                isDarkMode,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(pocket.spent, pocket.currency),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isOverBudget
                        ? colorScheme.error
                        : colorScheme.foreground,
                  ),
                ),
                Text(
                  '/ ${formatCurrency(limit, pocket.currency)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.drag_handle_rounded,
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
