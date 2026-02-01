import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';

class DashboardAccountsSection extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final List<Household> households;
  final String currency;

  const DashboardAccountsSection({
    super.key,
    required this.transactions,
    required this.households,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Personal
    // 2. Calculate Households

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Helper to calc spending for a scope
    Map<String, double> calcScopeStats(String? accountId) {
      // Returns { 'income': ..., 'expense': ... }
      double income = 0;
      double expense = 0;

      for (final tx in transactions) {
        if (tx.entry.date.isBefore(startOfMonth)) continue;

        // Filter by currency
        if ((tx.entry.currency ?? '').toUpperCase() != currency.toUpperCase())
          continue;

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
    final currencySymbol =
        NumberFormat.simpleCurrency(name: currency).currencySymbol;

    // Filter households matching currency
    final relativeHouseholds = households
        .where((h) => h.currency.toUpperCase() == currency.toUpperCase())
        .toList();

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
            'Accounts ($currency)',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
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
            currencySymbol: currencySymbol,
          ),

        // Households
        ...relativeHouseholds.map((h) {
          final stats = calcScopeStats(h.id);
          // Household currency should match 'currency' here due to filter
          final symbol =
              NumberFormat.simpleCurrency(name: h.currency).currencySymbol;
          return _AccountRow(
            name: h.name,
            isPortfolio: h.isPortfolio,
            stats: stats,
            currencySymbol: symbol,
          );
        }),

        if (!hasPersonalActivity && relativeHouseholds.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No accounts with this currency',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
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
  final String currencySymbol;

  const _AccountRow({
    required this.name,
    this.isPersonal = false,
    this.isPortfolio = false,
    required this.stats,
    required this.currencySymbol,
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
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPersonal
                  ? Colors.blue.withOpacity(0.1)
                  : (isPortfolio
                      ? Colors.purple.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPersonal
                  ? Icons.person
                  : (isPortfolio ? Icons.trending_up : Icons.people),
              color: isPersonal
                  ? Colors.blue
                  : (isPortfolio ? Colors.purple : Colors.orange),
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
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-$currencySymbol${expense.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              if (income > 0)
                Text(
                  '+$currencySymbol${income.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
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
