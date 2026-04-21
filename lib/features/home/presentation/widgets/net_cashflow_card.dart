import 'package:flutter/material.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

Widget buildNetCashflowCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<DailyBudgetEntry> budgets,
  List<ExpenseEntry> currentTransactions,
  List<ExpenseEntry> previousTransactions,
  UserContact? contact,
  DateRangeFilter filter, {
  String? selectedCurrency,
  DateTime? customStartDate,
  DateTime? customEndDate,
}) {
  final currentActuals = _getIncomeAndExpenses(currentTransactions);
  final previousActuals = _getIncomeAndExpenses(previousTransactions);
  final currentNet = currentActuals.$1 - currentActuals.$2;
  final previousNet = previousActuals.$1 - previousActuals.$2;
  final isNegative = currentNet < 0;
  final absAmount = currentNet.abs();
  final symbol = resolveCurrencySymbol(selectedCurrency ?? 'USD');
  final normalized = double.parse(formatAmount(absAmount));
  final localizedAmount = formatLocalizedNumber(context, normalized);
  final displayText =
      isNegative ? '-$symbol$localizedAmount' : '$symbol$localizedAmount';
  final title = _netCashflowTitleForFilter(context, filter);
  final isBetter = currentNet > previousNet;

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
    padding: const EdgeInsets.all(18.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: _AnimatedNumberText(
            value: currentNet.abs(),
            symbol: symbol,
            isNegative: currentNet < 0,
            style: TextStyle(
              fontSize: _netCashflowFontSize(displayText),
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              color: colorScheme.foreground,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (isBetter ? colorScheme.success : colorScheme.destructive)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBetter
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: isBetter ? colorScheme.success : colorScheme.destructive,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Returns (income, expenses)
(double, double) _getIncomeAndExpenses(List<ExpenseEntry> transactions) {
  double income = 0;
  double spend = 0;
  for (final t in transactions) {
    final ttype = (t.type ?? 'expense').toLowerCase();
    if (ttype == 'income') {
      income += t.amount.abs();
    } else {
      spend += t.amount.abs();
    }
  }
  return (income, spend);
}

String _netCashflowTitleForFilter(
    BuildContext context, DateRangeFilter filter) {
  final l10n = context.l10n;
  switch (filter) {
    case DateRangeFilter.today:
      return l10n.netCashflowToday;
    case DateRangeFilter.yesterday:
      return l10n.netCashflowYesterday;
    case DateRangeFilter.thisWeek:
      return l10n.netCashflowThisWeek;
    case DateRangeFilter.lastWeek:
      return l10n.netCashflowLastWeek;
    case DateRangeFilter.last30Days:
      return l10n.netCashflowLast30Days;
    case DateRangeFilter.thisMonth:
      return l10n.netCashflowThisMonth;
    case DateRangeFilter.custom:
      return l10n.netCashflowCustom;
    // Fallback to a sensible label when we don't have a dedicated string
    case DateRangeFilter.last7Days:
    case DateRangeFilter.lastMonth:
    case DateRangeFilter.last3Months:
    case DateRangeFilter.thisYear:
    case DateRangeFilter.allTime:
      return l10n.netCashflowThisMonth;
  }
}

double _netCashflowFontSize(String displayText) {
  final length = displayText.length;

  if (length <= 6) {
    return 35;
  } else if (length <= 7) {
    return 34;
  } else if (length <= 8) {
    return 33;
  } else {
    return 32;
  }
}

/// Animated number that counts up from 0 to target value
class _AnimatedNumberText extends StatelessWidget {
  final double value;
  final String symbol;
  final TextStyle style;
  final bool isNegative;

  const _AnimatedNumberText({
    required this.value,
    required this.symbol,
    required this.style,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        final formatted =
            formatLocalizedNumber(context, double.parse(formatAmount(val)));
        final displayText =
            isNegative ? '-$symbol$formatted' : '$symbol$formatted';
        return Text(
          displayText,
          style: style,
        );
      },
    );
  }
}
