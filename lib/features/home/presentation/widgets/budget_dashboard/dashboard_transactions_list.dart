import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/widgets/budget_dashboard/dashboard_section_widgets.dart';
import 'package:intl/intl.dart';

class DashboardTransactionsList extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final void Function(ConsolidatedTransaction tx)? onTransactionTap;
  final VoidCallback? onTap;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String Function(ConsolidatedTransaction tx)? accountLabelResolver;
  final String? currency;

  const DashboardTransactionsList({
    super.key,
    required this.transactions,
    this.onTransactionTap,
    this.onTap,
    this.amountResolver,
    this.accountLabelResolver,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recent = transactions.take(10).toList();

    String normalizeCategoryId(String? categoryId) {
      final trimmed = categoryId?.trim();
      final normalized =
          (trimmed == null || trimmed.isEmpty) ? 'uncategorized' : trimmed;
      return normalizeCategory(normalized);
    }

    if (recent.isEmpty) {
      return DashboardSectionCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Text(
            context.l10n.noTransactionsYet,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
        ),
      );
    }

    return DashboardSectionCard(
      onTap: onTap,
      children: List.generate(recent.length, (index) {
        final tx = recent[index];
        final categoryId = normalizeCategoryId(tx.entry.category);
        final isIncome = (tx.entry.type ?? 'expense').toLowerCase() == 'income';
        final categoryName = getCategoryTranslation(context, categoryId);
        final baseAmount = tx.entry.amountCents / 100.0;
        final resolvedAmount = amountResolver?.call(tx) ?? baseAmount;
        final displayAmount = isIncome ? resolvedAmount : resolvedAmount.abs();
        final accountLabel = accountLabelResolver?.call(tx) ?? tx.accountLabel;
        final displayCurrency =
            currency?.trim().isNotEmpty == true ? currency!.trim() : null;
        final currencyCode = amountResolver == null
            ? (tx.entry.currency ?? displayCurrency ?? 'USD')
            : (displayCurrency ?? tx.entry.currency ?? 'USD');
        final shouldShowLabel = accountLabelResolver != null
            ? accountLabel.trim().isNotEmpty
            : accountLabel.trim().isNotEmpty && accountLabel != 'Personal';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          child: TransactionListTile(
            category: categoryId,
            title: tx.entry.rawText ?? categoryName,
            amount: displayAmount,
            currency: currencyCode,
            isIncome: isIncome,
            date: tx.entry.date,
            subtitleWidget: Row(
              children: [
                if (shouldShowLabel)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      accountLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                Text(
                  DateFormat.MMMd().format(tx.entry.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            onTap:
                onTransactionTap == null ? null : () => onTransactionTap!(tx),
          ),
        );
      }),
    );
  }
}
