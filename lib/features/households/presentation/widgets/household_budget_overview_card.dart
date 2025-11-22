import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';

/// Budget overview card showing total spent, budget progress, and remaining budget
Widget buildHouseholdBudgetOverviewCard(
  BuildContext context,
  ColorScheme colorScheme,
  HouseholdSummary? summary, {
  VoidCallback? onTap,
}) {
  final totalExpensesCents = summary?.totals.totalExpensesCents ?? 0;
  final currency = (summary?.currency ?? 'USD').toUpperCase();
  final totalSpentAmount = totalExpensesCents / 100.0;
  final formattedTotalSpent = formatCurrency(totalSpentAmount, currency);
  final transactionCount = summary?.totals.transactionCount ?? 0;

  // Budget data
  final budgetStatuses = summary?.budgets ?? [];
  final hasBudget = budgetStatuses.isNotEmpty;

  int totalBudgetCents = 0;
  int totalBudgetSpentCents = 0;
  int totalBudgetRemainingCents = 0;
  bool isOverBudget = false;

  if (hasBudget) {
    for (final budget in budgetStatuses) {
      totalBudgetCents += budget.amountCents;
      totalBudgetSpentCents += budget.spentCents;
      totalBudgetRemainingCents += budget.remainingCents;
      if (budget.isOverBudget) isOverBudget = true;
    }
  }

  final budgetSpentAmount = totalBudgetSpentCents / 100.0;
  final budgetRemainingAmount = totalBudgetRemainingCents / 100.0;
  final budgetPercentage = totalBudgetCents > 0
      ? (totalBudgetSpentCents / totalBudgetCents * 100).clamp(0, 100)
      : 0.0;

  final isDark = Theme.of(context).brightness == Brightness.dark;

  final card = Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: colorScheme.outline.withValues(alpha: 0.05),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
          blurRadius: 32,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ],
    ),
    padding: const EdgeInsets.all(24.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row: Title and Transaction Count
        Row(
          children: [
            Text(
              context.l10n.spentByHousehold,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(width: 4),
            Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () => _showTotalSpentInfoDialog(context, colorScheme),
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: colorScheme.mutedForeground.withValues(alpha: 0.7),
                  ),
                );
              },
            ),
            const Spacer(),
            // Transaction count with icon
            Icon(
              Icons.receipt_outlined,
              size: 14,
              color: colorScheme.mutedForeground,
            ),
            const SizedBox(width: 4),
            Text(
              '$transactionCount',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          formattedTotalSpent,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),

        // Budget Section (only if budget exists)
        if (hasBudget) ...[
          const SizedBox(height: 24),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.border.withValues(alpha: 0.0),
                  colorScheme.border.withValues(alpha: 0.3),
                  colorScheme.border.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Text(
                context.l10n.budget,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Budget Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorScheme.muted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: budgetPercentage / 100,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOverBudget
                            ? [
                                const Color(0xFFEF4444),
                                const Color(0xFFDC2626),
                              ]
                            : budgetPercentage > 80
                                ? [
                                    const Color(0xFFF59E0B),
                                    const Color(0xFFD97706),
                                  ]
                                : [
                                    colorScheme.primary,
                                    colorScheme.primary.withValues(alpha: 0.8),
                                  ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Budget Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Spent
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.spent,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color:
                            colorScheme.mutedForeground.withValues(alpha: 0.7),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(budgetSpentAmount, currency),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Remaining
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      budgetRemainingAmount >= 0
                          ? context.l10n.remaining
                          : context.l10n.overBudget,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color:
                            colorScheme.mutedForeground.withValues(alpha: 0.7),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(budgetRemainingAmount.abs(), currency),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: budgetRemainingAmount >= 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  if (onTap == null) return card;
  return GestureDetector(
    onTap: onTap,
    child: card,
  );
}

/// Show total spent info dialog
void _showTotalSpentInfoDialog(BuildContext context, ColorScheme colorScheme) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: colorScheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.l10n.spentByHousehold,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        content: Text(
          context.l10n.spentByHouseholdTooltip,
          style: TextStyle(
            fontSize: 15,
            color: colorScheme.foreground.withValues(alpha: 0.9),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              context.l10n.gotIt,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      );
    },
  );
}
