import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/widget_text_styles.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/home/presentation/pages/category_details_page.dart';

class WhereTheMoneyWentWidget extends StatefulWidget {
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
  State<WhereTheMoneyWentWidget> createState() =>
      _WhereTheMoneyWentWidgetState();
}

class _WhereTheMoneyWentWidgetState extends State<WhereTheMoneyWentWidget> {
  _WhereTheMoneyWentCacheKey? _cachedKey;
  _WhereTheMoneyWentDerivedData? _cachedData;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final derivedData = _derivedDataFor();
    final filteredExpenses = derivedData.filteredExpenses;
    final totalSpent = derivedData.totalSpent;
    final explicitCategories = derivedData.sortedCategories;

    return Material(
      color: Colors.transparent,
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
                      widget.dateRange.getLabel(context),
                      style: WidgetTextStyles.dateLabel(
                          colorScheme.mutedForeground),
                    ),
                  ],
                ),
                if (widget.onHelpTap != null)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.help_outline,
                      size: 16,
                      color: colorScheme.mutedForeground,
                    ),
                    onPressed: widget.onHelpTap,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (filteredExpenses.isEmpty)
              _EmptyState(colorScheme: colorScheme)
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: explicitCategories.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final entry = explicitCategories[index];
                  final catKey = entry.key;
                  final amount = entry.value;

                  return _CategoryRow(
                    categoryKey: catKey,
                    amount: amount,
                    totalSpent: totalSpent,
                    colorScheme: colorScheme,
                    currency: widget.currency,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CategoryDetailsPage(
                            categoryKey: catKey,
                            currency: widget.currency,
                            initialDateFilter: widget.dateRange,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  _WhereTheMoneyWentDerivedData _derivedDataFor() {
    final expensesIdentity = identityHashCode(widget.expenses);
    final currency = widget.currency?.trim().toUpperCase();
    final cached = _cachedData;
    final cachedKey = _cachedKey;
    if (cached != null &&
        cachedKey != null &&
        cachedKey.expensesIdentity == expensesIdentity &&
        cachedKey.currency == currency) {
      return cached;
    }

    final key = _WhereTheMoneyWentCacheKey(
      expensesIdentity: expensesIdentity,
      expensesSignature: _expenseListSignature(widget.expenses),
      currency: currency,
    );
    if (cached != null && _cachedKey == key) {
      return cached;
    }

    var filteredExpenses = widget.expenses
        .where((e) => (e.type ?? 'expense').toLowerCase() != 'income')
        .toList(growable: false);
    if (widget.currency != null) {
      final curr = widget.currency!.toUpperCase();
      filteredExpenses = filteredExpenses
          .where((e) => e.currency?.toUpperCase() == curr)
          .toList(growable: false);
    }

    final categoryTotals = <String, double>{};
    for (final expense in filteredExpenses) {
      final cat = canonicalizeCategoryKey(expense.category);
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + expense.amount.abs();
    }

    final sortedCategories = categoryTotals.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final next = _WhereTheMoneyWentDerivedData(
      filteredExpenses: filteredExpenses,
      sortedCategories: sortedCategories,
      totalSpent: categoryTotals.values.fold<double>(0, (a, b) => a + b),
    );
    _cachedKey = key;
    _cachedData = next;
    return next;
  }
}

class _WhereTheMoneyWentDerivedData {
  const _WhereTheMoneyWentDerivedData({
    required this.filteredExpenses,
    required this.sortedCategories,
    required this.totalSpent,
  });

  final List<ExpenseEntry> filteredExpenses;
  final List<MapEntry<String, double>> sortedCategories;
  final double totalSpent;
}

class _WhereTheMoneyWentCacheKey {
  const _WhereTheMoneyWentCacheKey({
    required this.expensesIdentity,
    required this.expensesSignature,
    required this.currency,
  });

  final int expensesIdentity;
  final int expensesSignature;
  final String? currency;

  @override
  bool operator ==(Object other) {
    return other is _WhereTheMoneyWentCacheKey &&
        other.expensesSignature == expensesSignature &&
        other.currency == currency;
  }

  @override
  int get hashCode => Object.hash(expensesSignature, currency);
}

int _expenseListSignature(List<ExpenseEntry> expenses) {
  var hash = expenses.length;
  for (final expense in expenses) {
    hash = Object.hash(
      hash,
      expense.date.millisecondsSinceEpoch,
      expense.amountCents,
      expense.amount,
      expense.currency,
      expense.type,
      expense.category,
    );
  }
  return hash;
}

class _CategoryRow extends StatelessWidget {
  final String categoryKey;
  final double amount;
  final double totalSpent;
  final ColorScheme colorScheme;
  final String? currency;
  final VoidCallback? onTap;

  const _CategoryRow({
    required this.categoryKey,
    required this.amount,
    required this.totalSpent,
    required this.colorScheme,
    this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = getCategoryTranslation(context, categoryKey);
    final color = getCategoryColor(categoryKey);
    final icon = getCategoryIcon(categoryKey);

    // Calculate percentage, careful of div by zero
    final percent = totalSpent > 0 ? (amount / totalSpent) : 0.0;
    final percentString = '${(percent * 100).toStringAsFixed(0)}%';

    final symbol = resolveCurrencySymbol(currency ?? 'USD');
    final displayAmount = '$symbol${formatLocalizedNumber(context, amount)}';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          // Leading Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),

          // Name and Bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          displayAmount,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          color: color,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      percentString,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              color: colorScheme.mutedForeground,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.noData,
            style: TextStyle(
                color: colorScheme.mutedForeground,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
