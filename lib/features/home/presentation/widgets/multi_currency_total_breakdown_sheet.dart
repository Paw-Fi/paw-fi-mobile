import 'package:flutter/material.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';

void showMultiCurrencyTotalBreakdownSheet({
  required BuildContext context,
  required ColorScheme colorScheme,
  required List<TransactionsFeedCurrencyTypeTotal> currencyTypeTotals,
  required CurrencyRateTable rates,
  required String targetCurrency,
  required double totalSpent,
}) {
  if (currencyTypeTotals.length <= 1) return;

  MonekoBottomSheet.show(
    context: context,
    title: context.l10n.totalSpent,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${resolveCurrencySymbol(targetCurrency)}${formatLocalizedNumber(context, totalSpent)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ...([...currencyTypeTotals]..sort(
                    (a, b) => b.expenseTotal.compareTo(a.expenseTotal),
                  ))
                .map((typeTotal) {
              if (typeTotal.expenseTotal == 0) return const SizedBox.shrink();

              final converted = rates.convert(
                typeTotal.expenseTotal,
                typeTotal.currency,
                targetCurrency,
              );
              final isTarget = typeTotal.currency == targetCurrency;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          resolveCurrencySymbol(typeTotal.currency),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typeTotal.currency,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          if (!isTarget)
                            Text(
                              '≈ ${resolveCurrencySymbol(targetCurrency)}${formatLocalizedNumber(context, converted)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      formatLocalizedNumber(context, typeTotal.expenseTotal),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}
