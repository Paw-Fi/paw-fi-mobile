import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/households/domain/entities/shared_budget.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:collection/collection.dart';

class DashboardHero extends StatefulWidget {
  final List<ConsolidatedTransaction> transactions;
  final List<DailyBudgetEntry> personalBudgets;
  final Map<String, List<SharedBudget>> householdBudgets;
  final String? preferredCurrency;

  const DashboardHero({
    super.key,
    required this.transactions,
    required this.personalBudgets,
    required this.householdBudgets,
    this.preferredCurrency,
  });

  @override
  State<DashboardHero> createState() => _DashboardHeroState();
}

class _DashboardHeroState extends State<DashboardHero> {
  late PageController _pageController;
  int _currentPage = 0;
  List<String> _currencies = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _calculateCurrencies() {
    final Set<String> currencies = {};
    if (widget.preferredCurrency != null &&
        widget.preferredCurrency!.isNotEmpty) {
      currencies.add(widget.preferredCurrency!.toUpperCase());
    }

    // Add currencies from transactions
    for (final tx in widget.transactions) {
      if (tx.entry.currency != null && tx.entry.currency!.isNotEmpty) {
        currencies.add(tx.entry.currency!.toUpperCase());
      }
    }

    // Add currencies from budgets
    for (final b in widget.personalBudgets) {
      if (b.currency != null && b.currency!.isNotEmpty)
        currencies.add(b.currency!.toUpperCase());
    }
    for (final list in widget.householdBudgets.values) {
      for (final b in list) {
        if (b.currency.isNotEmpty) currencies.add(b.currency.toUpperCase());
      }
    }

    _currencies = currencies.toList()..sort();

    // Ensure preferred is first if exists
    if (widget.preferredCurrency != null &&
        widget.preferredCurrency!.isNotEmpty) {
      final pref = widget.preferredCurrency!.toUpperCase();
      if (_currencies.contains(pref)) {
        _currencies.remove(pref);
        _currencies.insert(0, pref);
      }
    }

    if (_currencies.isEmpty) {
      _currencies = ['USD']; // Default
    }
  }

  @override
  Widget build(BuildContext context) {
    _calculateCurrencies();

    if (_currencies.isEmpty) return const SizedBox.shrink();

    // Limit height to avoid taking too much space
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _currencies.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              HapticFeedback.selectionClick();
            },
            itemBuilder: (context, index) {
              final currency = _currencies[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _CurrencyHeroCard(
                  currency: currency,
                  transactions: widget.transactions,
                  personalBudgets: widget.personalBudgets,
                  householdBudgets: widget.householdBudgets,
                ),
              );
            },
          ),
        ),
        if (_currencies.length > 1) ...[
          const SizedBox(height: 8),
          _PageIndicator(
            count: _currencies.length,
            current: _currentPage,
          ),
        ],
      ],
    );
  }
}

class _CurrencyHeroCard extends StatelessWidget {
  final String currency;
  final List<ConsolidatedTransaction> transactions;
  final List<DailyBudgetEntry> personalBudgets;
  final Map<String, List<SharedBudget>> householdBudgets;

  const _CurrencyHeroCard({
    required this.currency,
    required this.transactions,
    required this.personalBudgets,
    required this.householdBudgets,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Filter transactions for this month & currency
    final monthTransactions = transactions.where((tx) {
      if ((tx.entry.currency ?? '').toUpperCase() != currency) return false;
      return tx.entry.date
              .isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
          tx.entry.date.isBefore(endOfMonth.add(const Duration(seconds: 1)));
    }).toList();

    // Calculate Spend
    final spentCents = monthTransactions.fold<int>(0, (sum, tx) {
      // Only expenses
      if (tx.entry.type != 'income') {
        return sum + tx.entry.amountCents;
      }
      return sum;
    });

    final spent = spentCents / 100.0;

    // Calculate Budget
    double totalBudget = 0;

    // Personal Budget (latest in currency)
    final personalBudget = personalBudgets
        .where((b) => (b.currency ?? '').toUpperCase() == currency)
        .toList() // Convert to list to sort
        .sorted((a, b) => a.date.compareTo(b.date))
        .lastOrNull;

    if (personalBudget != null) {
      totalBudget += personalBudget.amountCents / 100.0;
    }

    // Household Budgets
    for (final householdId in householdBudgets.keys) {
      final budgets = householdBudgets[householdId]!;
      // Find active budget for this currency
      final budget = budgets
          .where((b) => b.currency.toUpperCase() == currency)
          .lastOrNull; // Simplification
      if (budget != null) {
        totalBudget += budget.amountCents / 100.0;
      }
    }

    final hasBudget = totalBudget > 0;
    final remaining = hasBudget ? (totalBudget - spent) : 0.0;
    final progress = hasBudget ? (spent / totalBudget).clamp(0.0, 1.0) : 0.0;

    final currencySymbol =
        NumberFormat.simpleCurrency(name: currency).currencySymbol;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // Very subtle shadow as per guidelines
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.05),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hasBudget
                ? '${remaining < 0 ? "-" : ""}$currencySymbol${remaining.abs().toStringAsFixed(0)} left'
                : '$currencySymbol${spent.toStringAsFixed(0)} spent', // Hardcoded english per request "Content is UI"
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasBudget
                      ? '$currencySymbol${spent.toStringAsFixed(0)} of $currencySymbol${totalBudget.toStringAsFixed(0)} spent'
                      : 'Spent this month ($currency)',
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (hasBudget)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: colorScheme.onSurface.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  remaining < 0 ? colorScheme.error : colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _PageIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: isActive ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurface.withOpacity(0.2),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
