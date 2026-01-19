import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import '../../../../../core/l10n/l10n.dart';

/// Widget to display balance summary ("You owe X" / "You are owed Y")
class BalanceSummaryWidget extends ConsumerWidget {
  final String householdId;

  const BalanceSummaryWidget({
    super.key,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // In real app, fetch balance data from provider/Edge Function
    // For now, show placeholder UI with example data
    const youOwe = 45.50;
    const youAreOwed = 75.00;
    const netBalance = youAreOwed - youOwe;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.balanceSummary,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 16),

            // Net balance - prominent display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: netBalance >= 0
                    ? colorScheme.primary.withValues(alpha: 0.1)
                    : colorScheme.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        netBalance >= 0
                            ? context.l10n.youAreOwed
                            : context.l10n.youOweOthers,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${netBalance.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: netBalance >= 0
                              ? colorScheme.primary
                              : colorScheme.destructive,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    netBalance >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 32,
                    color: netBalance >= 0
                        ? colorScheme.primary
                        : colorScheme.destructive,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.border),
            const SizedBox(height: 16),

            // Breakdown
            _BalanceRow(
              label: context.l10n.youOweOthers,
              amount: youOwe,
              icon: Icons.call_made,
              colorScheme: colorScheme,
              isNegative: true,
            ),
            const SizedBox(height: 12),
            _BalanceRow(
              label: context.l10n.othersOweYou,
              amount: youAreOwed,
              icon: Icons.call_received,
              colorScheme: colorScheme,
              isNegative: false,
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedAdaptiveButton(
                    onPressed: () {
                      // View detailed breakdown
                    },
                    child: Text(context.l10n.viewDetails),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryAdaptiveButton(
                    onPressed: () {
                      // Settle up flow
                    },
                    child: Text(context.l10n.settleUp),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final dynamic colorScheme;
  final bool isNegative;

  const _BalanceRow({
    required this.label,
    required this.amount,
    required this.icon,
    required this.colorScheme,
    required this.isNegative,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isNegative ? colorScheme.destructive : colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.foreground,
              ),
            ),
          ],
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isNegative ? colorScheme.destructive : colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
