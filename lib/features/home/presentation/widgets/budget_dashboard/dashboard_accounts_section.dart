import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';

class DashboardAccountsSection extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final List<Household> households;
  const DashboardAccountsSection({
    super.key,
    required this.transactions,
    required this.households,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Personal
    // 2. Calculate Households

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final amountFormatter = NumberFormat.compact();

    // Helper to calc spending for a scope
    Map<String, double> calcScopeStats(String? accountId) {
      // Returns { 'income': ..., 'expense': ... }
      double income = 0;
      double expense = 0;

      for (final tx in transactions) {
        if (tx.entry.date.isBefore(startOfMonth)) continue;

        if (accountId == null) {
          if (tx.accountId != null || tx.accountLabel != 'Personal') continue;
        } else {
          if (tx.accountId != accountId) continue;
        }

        final amount = tx.entry.amountCents / 100.0;
        if (tx.entry.type == 'income')
          income += amount;
        else
          expense += amount;
      }
      return {'income': income, 'expense': expense};
    }

    final colorScheme = Theme.of(context).colorScheme;
    final relativeHouseholds = households.toList();

    // Check personal has activity
    final personalStats = calcScopeStats(null);
    final hasPersonalActivity =
        personalStats['income']! > 0 || personalStats['expense']! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            'Accounts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'All currencies combined',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
            ),
          ),
        ),

        // Personal
        // Always show personal if user is viewing their currency, or if they have transactions?
        // Let's show it if there is activity, or if it is the "default" currency?
        // Simpler: Always show Personal, but values might be 0.
        if (hasPersonalActivity) // Only show if relevant to keep it clean
          _AccountRow(
            name: 'Personal',
            isPersonal: true,
            stats: personalStats,
            amountFormatter: amountFormatter,
          ),

        // Households
        ...relativeHouseholds.map((h) {
          final stats = calcScopeStats(h.id);
          return _AccountRow(
            name: h.name,
            isPortfolio: h.isPortfolio,
            stats: stats,
            amountFormatter: amountFormatter,
          );
        }),

        if (!hasPersonalActivity && relativeHouseholds.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No activity yet this month',
              style: TextStyle(color: colorScheme.mutedForeground),
            ),
          ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  final String name;
  final bool isPersonal;
  final bool isPortfolio;
  final Map<String, double> stats;
  final NumberFormat amountFormatter;

  const _AccountRow({
    required this.name,
    this.isPersonal = false,
    this.isPortfolio = false,
    required this.stats,
    required this.amountFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final income = stats['income'] ?? 0;
    final expense = stats['expense'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.homeCardBorder),
          boxShadow: [
            BoxShadow(
              color: colorScheme.homeCardShadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPersonal
                      ? colorScheme.info
                      : (isPortfolio
                          ? colorScheme.warning
                          : colorScheme.success))
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPersonal
                  ? Icons.person
                  : (isPortfolio ? Icons.trending_up : Icons.people),
              color: isPersonal
                  ? colorScheme.info
                  : (isPortfolio ? colorScheme.warning : colorScheme.success),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  isPersonal
                      ? 'Private'
                      : (isPortfolio ? 'Portfolio' : 'Shared'),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${amountFormatter.format(expense)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              if (income > 0)
                Text(
                  '+${amountFormatter.format(income)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
