import 'package:flutter/material.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

Widget buildBudgetCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<DailyBudgetEntry> budgets,
  List<ExpenseEntry> expenses,
  UserContact? contact,
  DateRangeFilter filter, {
  VoidCallback? onTap,
  String? selectedCurrency,
}) {
  final totalBudget = _getTotalBudget(budgets);

  final currency = selectedCurrency ?? 'USD';
  final displayText = _formatLocalizedCurrency(context, totalBudget, currency);

  final title = context.l10n.budget;

  return Material(
    color: colorScheme.surface.withValues(alpha: 0.0),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: colorScheme.foreground,
                height: 1.1,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 16, color: colorScheme.mutedForeground),
                const SizedBox(width: 6),
                Text(
                  '${expenses.length} ${context.l10n.transactions}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

double _getTotalBudget(List<DailyBudgetEntry> budgets) {
  return budgets.fold(0.0, (sum, b) => sum + b.amount);
}

String _formatLocalizedCurrency(
  BuildContext context,
  double amount,
  String currency,
) {
  final normalized = double.parse(formatAmount(amount));
  final symbol = resolveCurrencySymbol(currency);
  final localized = formatLocalizedNumber(context, normalized);
  return '$symbol$localized';
}
