import 'package:flutter/material.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_style_constants.dart';
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

    final Color fillColor;
    if (isOverBudget) {
      fillColor = colorScheme.error;
    } else if (progress > 0.9) {
      fillColor = Colors.orange;
    } else {
      fillColor = baseColor;
    }

    final iconData = getPocketIconData(pocket.icon);

    // Derive text colors for readability based on theme and background
    final titleColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode
        ? Colors.white.withOpacity(0.75)
        : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: fillColor.withValues(alpha: isDarkMode ? 0.2 : 0.12),
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
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              // Icon chip
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isDarkMode ? 0.18 : 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  iconData,
                  size: 20,
                  color: baseColor,
                ),
              ),
              const SizedBox(width: 14),
              // Main content card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withOpacity(isDarkMode ? 0.20 : 0.9),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Title + progress
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    pocket.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                    ),
                                  ),
                                ),
                                if (isOverBudget) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.priority_high_rounded,
                                    color: colorScheme.error,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                height: 4,
                                width: double.infinity,
                                color: Colors.black.withOpacity(0.08),
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
                      const SizedBox(width: 12),
                      // Amounts
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCurrency(pocket.spent, pocket.currency),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isOverBudget
                                  ? colorScheme.error
                                  : titleColor,
                            ),
                          ),
                          Text(
                            '/ ${formatCurrency(limit, pocket.currency)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
