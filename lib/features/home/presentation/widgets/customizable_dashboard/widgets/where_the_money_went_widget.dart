import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';

class WhereTheMoneyWentWidget extends StatelessWidget {
  final List<ExpenseEntry> expenses;
  final String? currency;
  final VoidCallback? onHelpTap;

  const WhereTheMoneyWentWidget({
    super.key,
    required this.expenses,
    this.currency,
    this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Filter expenses by selected currency if applicable
    var filteredExpenses = expenses;
    if (currency != null) {
      final curr = currency!.toUpperCase();
      filteredExpenses =
          expenses.where((e) => e.currency?.toUpperCase() == curr).toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.whereTheMoneyWent,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              if (onHelpTap != null)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.help_outline,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onHelpTap,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.categoryTotalsForSelectedRange,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          buildCategoryBarChart(context, colorScheme, filteredExpenses),
        ],
      ),
    );
  }
}
