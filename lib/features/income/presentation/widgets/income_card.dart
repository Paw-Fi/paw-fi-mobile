import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';
import 'package:moneko/features/income/presentation/pages/income_list_page.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Income summary card for dashboard
/// Shows MTD/YTD income totals with navigation to full income list
class IncomeCard extends ConsumerWidget {
  final String? householdId;

  const IncomeCard({super.key, this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final incomeSummaryState = ref.watch(incomeSummaryProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const IncomeListPage(),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.border, width: 1),
          ),
          padding: const EdgeInsets.all(16.0),
          child: incomeSummaryState.when(
            data: (summary) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.income,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: colorScheme.mutedForeground,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // MTD Income
                  if (summary.mtdIncome != null) ...[
                    Text(
                      context.l10n.monthToDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(summary.mtdIncome!, summary.currency),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ] else ...[
                    Text(
                      context.l10n.totalIncome,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(summary.totalIncome, summary.currency),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // YTD Income (if available)
                  if (summary.ytdIncome != null) ...[
                    Row(
                      children: [
                        Text(
                          '${context.l10n.yearToDate}: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        Text(
                          formatCurrency(summary.ytdIncome!, summary.currency),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Transaction Count
                  Text(
                    '${summary.transactionCount} ${_getTransactionLabel(context, summary.transactionCount)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.income,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.failedToLoadIncome,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.destructive,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTransactionLabel(BuildContext context, int count) {
    if (count == 1) {
      return context.l10n.transactions;
    }
    return context.l10n.transactions;
  }
}
