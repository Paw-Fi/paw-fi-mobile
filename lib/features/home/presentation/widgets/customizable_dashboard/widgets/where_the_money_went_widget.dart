import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/widget_text_styles.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/insights/presentation/widgets/charts/charts.dart';

class WhereTheMoneyWentWidget extends StatelessWidget {
  final List<ExpenseEntry> expenses;
  final String? currency;
  final VoidCallback? onHelpTap;
  final DateRangeFilter dateRange;

  const WhereTheMoneyWentWidget({
    super.key,
    required this.expenses,
    this.currency,
    this.onHelpTap,
    required this.dateRange,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter expenses by selected currency if applicable
    var filteredExpenses = expenses;
    if (currency != null) {
      final curr = currency!.toUpperCase();
      filteredExpenses =
          expenses.where((e) => e.currency?.toUpperCase() == curr).toList();
    }

    return Material(
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.chartBackground,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.whereTheMoneyWent.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateRange.getLabel(context),
                      style: WidgetTextStyles.dateLabel(
                          colorScheme.mutedForeground),
                    ),
                  ],
                ),
                if (onHelpTap != null)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.help_outline,
                      size: 16,
                      color: colorScheme.mutedForeground,
                    ),
                    onPressed: onHelpTap,
                  ),
              ],
            ),
            buildCategoryBarChart(context, colorScheme, filteredExpenses),
          ],
        ),
      ),
    );
  }
}
