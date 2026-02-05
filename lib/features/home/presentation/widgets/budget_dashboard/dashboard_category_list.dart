import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/widgets/budget_dashboard/dashboard_section_widgets.dart';

class DashboardCategoryList extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final void Function(String categoryId)? onCategoryTap;
  final VoidCallback? onTap;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String? currencyCode;

  const DashboardCategoryList({
    super.key,
    required this.transactions,
    this.onCategoryTap,
    this.onTap,
    this.amountResolver,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayCurrency =
        currencyCode?.trim().isNotEmpty == true ? currencyCode!.trim() : null;
    final amountFormatter =
        NumberFormat.compactSimpleCurrency(name: displayCurrency);

    String normalizeCategoryId(String? categoryId) {
      final trimmed = categoryId?.trim();
      final normalized =
          (trimmed == null || trimmed.isEmpty) ? 'uncategorized' : trimmed;
      return normalizeCategory(normalized);
    }

    final validTx = transactions
        .where((tx) => (tx.entry.type ?? 'expense').toLowerCase() != 'income');

    final grouped =
        validTx.groupListsBy((tx) => normalizeCategoryId(tx.entry.category));

    final categoryTotals = grouped.entries.map((entry) {
      final catId = entry.key;
      final txs = entry.value;
      final total = txs.fold<double>(0.0, (sum, tx) {
        final base = tx.entry.amountCents / 100.0;
        final resolved = amountResolver?.call(tx) ?? base;
        return sum + resolved.abs();
      });

      final name = getCategoryTranslation(context, catId);

      return _CategoryTotal(
        id: catId,
        name: name,
        amount: total,
        transactionCount: txs.length,
      );
    }).toList();

    categoryTotals.sort((a, b) => b.amount.compareTo(a.amount));

    final topCategories = categoryTotals.take(5).toList();
    final maxAmount = topCategories.isNotEmpty ? topCategories.first.amount : 0;

    if (topCategories.isEmpty) {
      return DashboardSectionCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Text(
            context.l10n.noExpensesYet,
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
      children: topCategories.map((cat) {
        final percent = maxAmount > 0 ? cat.amount / maxAmount : 0.0;
        final color = getCategoryColor(cat.id);

        return DashboardListTile(
          title: cat.name,
          subtitleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${cat.transactionCount} ${context.l10n.transactionsCount}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percent,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          icon: getCategoryIcon(cat.id),
          iconColor: color,
          value: amountFormatter.format(cat.amount),
          showChevron: onCategoryTap != null,
          onTap: onCategoryTap == null ? null : () => onCategoryTap!(cat.id),
        );
      }).toList(),
    );
  }
}

class _CategoryTotal {
  final String id;
  final String name;
  final double amount;
  final int transactionCount;

  _CategoryTotal({
    required this.id,
    required this.name,
    required this.amount,
    required this.transactionCount,
  });
}
