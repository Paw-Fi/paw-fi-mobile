import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';

class DashboardSpaceCard extends StatelessWidget {
  final String spaceName;
  final double income;
  final double expense;
  final String currency;
  final VoidCallback? onTap;

  const DashboardSpaceCard({
    super.key,
    required this.spaceName,
    required this.income,
    required this.expense,
    required this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final balance = income - expense;
    final balanceColor = balance >= 0 ? colorScheme.success : colorScheme.error;
    final formatter = NumberFormat.compactSimpleCurrency(name: currency);

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.surfaceBorder,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.workspaces_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        spaceName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRow(
                    context, 'Income', income, colorScheme.success, formatter),
                const SizedBox(height: 8),
                _buildRow(
                    context, 'Expense', expense, colorScheme.error, formatter),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: colorScheme.border.withValues(alpha: 0.5),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    Text(
                      formatter.format(balance),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: balanceColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, double amount, Color _,
      NumberFormat formatter) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.mutedForeground,
          ),
        ),
        Text(
          formatter.format(amount),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
