import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:intl/intl.dart';

// Data providers
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';

/// Unified Widget Details Page - Modern Premium Implementation
///
/// Refactored to align with 2025 UI/UX standards:
/// - Clean hierarchy and typography (SF Pro style)
/// - "Inset Grouped" layout feel
/// - Soft shadows and rounded corners
/// - Clear data visualization
class WidgetDetailsPage extends ConsumerWidget {
  final String widgetType;
  final DashboardWidgetConfig? config;
  final String currency;

  const WidgetDetailsPage({
    super.key,
    required this.widgetType,
    this.config,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Apple-style background color
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    String title;
    String question;

    switch (widgetType) {
      case 'budgetRemaining':
        title = context.l10n.budgetRemaining;
        question = 'How much is left?';
        break;
      case 'pocketHealthScorecard':
        title = context.l10n.pocketHealth;
        question = 'Where should I focus?';
        break;
      case 'recurringExpensesSummary':
        title = context.l10n.recurringExpenses;
        question = 'What are my fixed costs?';
        break;
      case 'topExpenses':
        title = context.l10n.topExpenses;
        question = 'Where is money going?';
        break;
      case 'incomeVsExpenses':
        title = context.l10n.incomeVsExpenses;
        question = 'Am I cash positive?';
        break;
      case 'spendingRate':
        title = context.l10n.spendingRate;
        question = 'How fast am I spending?';
        break;
      default:
        title = 'Details';
        question = '';
    }

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: title,      
      ),
      body: Padding(
        padding: EdgeInsets.only(top: getSubPageTopPadding(context)),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Large Title / Question Header
              if (question.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        
              // Main Content
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: _buildDetailsContent(context, colorScheme, widgetType, ref, surfaceColor),
                ),
              ),
        
              // Bottom Spacer
              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsContent(
    BuildContext context,
    ColorScheme colorScheme,
    String type,
    WidgetRef ref,
    Color surfaceColor,
  ) {
    switch (type) {
      case 'budgetRemaining':
        return _buildBudgetRemainingDetails(context, colorScheme, ref, surfaceColor);
      case 'pocketHealthScorecard':
        return _buildPocketHealthDetails(context, colorScheme, ref, surfaceColor);
      case 'recurringExpensesSummary':
        return _buildRecurringExpensesDetails(context, colorScheme, ref, surfaceColor);
      case 'topExpenses':
        return _buildTopExpensesDetails(context, colorScheme, ref, surfaceColor);
      case 'incomeVsExpenses':
        return _buildIncomeVsExpensesDetails(context, colorScheme, ref, surfaceColor);
      case 'spendingRate':
        return _buildSpendingRateDetails(context, colorScheme, ref, surfaceColor);
      default:
        return Center(
          child: Text(
            'Details for $type',
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        );
    }
  }

  // ============================================================================
  // BUDGET REMAINING DETAILS
  // ============================================================================
  Widget _buildBudgetRemainingDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
    Color surfaceColor,
  ) {
    final analyticsData = ref.watch(analyticsProvider);
    final pocketsState = ref.watch(pocketsProvider(const PocketsScopeParams(
      scope: PocketsScopeType.personal,
      householdId: null,
    )));
    final recurringState = ref.watch(recurringTransactionsProvider(null));

    if (pocketsState.isLoading || recurringState.data.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final pockets = pocketsState.saved;
    final totalBudget = pocketsState.totalBudget;

    // Calculate spent
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final expenses = analyticsData.allExpenses.where((e) =>
        e.currency == currency &&
        e.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
        e.type != 'income').toList();

    final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    // Calculate recurring committed
    final recurringItems = recurringState.data.value ?? [];
    final recurringMonthly = recurringItems.where((r) => r.currency == currency && r.type == 'expense').fold<double>(0, (sum, r) {
      final amount = r.amount;
      switch ((r.recurrenceRule?.frequency ?? 'monthly').toLowerCase()) {
        case 'daily': return sum + (amount * 30);
        case 'weekly': return sum + (amount * 4);
        case 'monthly': return sum + amount;
        case 'yearly': return sum + (amount / 12);
        default: return sum + amount;
      }
    });

    final remaining = totalBudget - totalSpent - recurringMonthly;
    final daysLeftInMonth = DateTime(now.year, now.month + 1, 0).day - now.day + 1;
    final dailyBudget = remaining > 0 ? remaining / daysLeftInMonth : 0;
    final percentUsed = totalBudget > 0 ? ((totalSpent + recurringMonthly) / totalBudget * 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Insight Card
        _InsightCard(
          colorScheme: colorScheme,
          surfaceColor: surfaceColor,
          icon: Icons.account_balance_wallet,
          title: 'Your Situation',
          content: totalBudget > 0
              ? 'You started with ${formatCurrency(totalBudget, currency)}. After spending ${formatCurrency(totalSpent, currency)} and accounting for ${formatCurrency(recurringMonthly, currency)} in bills, you have ${formatCurrency(remaining, currency)} left.'
              : 'Start by setting up a budget in your pockets settings to track your spending limits.',
        ),
        
        const SizedBox(height: 24),

        // Hero Stat Card
        _ModernCard(
          surfaceColor: surfaceColor,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'REMAINING BUDGET',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatCurrency(remaining, currency),
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: remaining >= 0 ? colorScheme.primary : colorScheme.error,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$daysLeftInMonth days left • ${formatCurrency(dailyBudget.toDouble(), currency)}/day safe',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.05)),
              _StatRow(
                label: 'Total Budget',
                value: formatCurrency(totalBudget, currency),
                isFirst: true,
                colorScheme: colorScheme,
              ),
              _StatRow(
                label: 'Spent So Far',
                value: formatCurrency(totalSpent, currency),
                valueColor: colorScheme.error,
                colorScheme: colorScheme,
              ),
              _StatRow(
                label: 'Recurring Bills',
                value: formatCurrency(recurringMonthly, currency),
                valueColor: Colors.orange,
                isLast: true,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Action Section
        if (totalBudget > 0)
          _ActionCard(
            colorScheme: colorScheme,
            title: 'Recommendation',
            content: percentUsed < 80
                ? 'You are on track. Consider allocating the surplus to savings.'
                : percentUsed < 100
                    ? 'Caution advised. You are nearing your limit.'
                    : 'Budget exceeded. Halt non-essential spending immediately.',
            isPositive: percentUsed < 80,
            isWarning: percentUsed >= 80 && percentUsed < 100,
          ),

        const SizedBox(height: 32),
        
        // Breakdown Title
        _SectionHeader(title: 'Category Breakdown', colorScheme: colorScheme),
        const SizedBox(height: 12),

        if (pockets.isEmpty)
           _EmptyStateSimple(message: 'No categories set up', colorScheme: colorScheme)
        else
          ...pockets.map((pocket) {
            final pocketSpent = pocket.spent;
            final pocketAllocated = (totalBudget * pocket.percentage / 100);
            final percentage = pocketAllocated > 0 ? (pocketSpent / pocketAllocated * 100) : 0;
            
            return _ModernCategoryCard(
              name: pocket.name,
              amount: '${formatCurrency(pocketSpent, currency)} / ${formatCurrency(pocketAllocated, currency)}',
              percentage: percentage / 100,
              color: percentage > 100 ? colorScheme.error : percentage > 80 ? Colors.orange : colorScheme.primary,
              surfaceColor: surfaceColor,
              colorScheme: colorScheme,
            );
          }),
      ],
    );
  }

  // ============================================================================
  // POCKET HEALTH DETAILS
  // ============================================================================
  Widget _buildPocketHealthDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
    Color surfaceColor,
  ) {
    final pocketsState = ref.watch(pocketsProvider(const PocketsScopeParams(
      scope: PocketsScopeType.personal,
      householdId: null,
    )));

    if (pocketsState.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final pockets = pocketsState.saved;
    final totalBudget = pocketsState.totalBudget;

    if (pockets.isEmpty) {
      return _EmptyState(
        colorScheme: colorScheme,
        surfaceColor: surfaceColor,
        title: 'No Pockets Yet',
        description: 'Set up budget pockets to see health analysis.',
      );
    }

    final sortedPockets = List<PocketEnvelope>.from(pockets)..sort((a, b) {
      final aAllocated = totalBudget * a.percentage / 100;
      final bAllocated = totalBudget * b.percentage / 100;
      final aPercent = aAllocated > 0 ? (a.spent / aAllocated * 100) : 0;
      final bPercent = bAllocated > 0 ? (b.spent / bAllocated * 100) : 0;
      return bPercent.compareTo(aPercent);
    });

    final overBudgetPockets = sortedPockets.where((p) {
      final allocated = totalBudget * p.percentage / 100;
      return p.spent > allocated;
    }).toList();

    final warningPockets = sortedPockets.where((p) {
      final allocated = totalBudget * p.percentage / 100;
      final percent = allocated > 0 ? (p.spent / allocated * 100) : 0;
      return percent > 80 && percent <= 100;
    }).toList();

    final healthyPockets = sortedPockets.where((p) {
      final allocated = totalBudget * p.percentage / 100;
      final percent = allocated > 0 ? (p.spent / allocated * 100) : 0;
      return percent <= 80;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsightCard(
          colorScheme: colorScheme,
          surfaceColor: surfaceColor,
          icon: Icons.health_and_safety,
          title: 'Health Check',
          content: overBudgetPockets.isNotEmpty
              ? '${overBudgetPockets.length} categories are over budget. Focus on reducing spend here.'
              : warningPockets.isNotEmpty
                  ? '${warningPockets.length} categories are nearing their limits. Proceed with caution.'
                  : 'All systems go. You are staying within budget across all categories.',
        ),

        const SizedBox(height: 24),

        // Status Grid
        Row(
          children: [
            Expanded(
              child: _StatusCard(
                count: overBudgetPockets.length.toString(),
                label: 'CRITICAL',
                color: colorScheme.error,
                surfaceColor: surfaceColor,
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusCard(
                count: warningPockets.length.toString(),
                label: 'AT RISK',
                color: Colors.orange,
                surfaceColor: surfaceColor,
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusCard(
                count: healthyPockets.length.toString(),
                label: 'HEALTHY',
                color: AppTheme.success,
                surfaceColor: surfaceColor,
                colorScheme: colorScheme,
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        _SectionHeader(title: 'Pocket Status', colorScheme: colorScheme),
        const SizedBox(height: 12),

        ...sortedPockets.map((pocket) {
          final allocated = totalBudget * pocket.percentage / 100;
          final percent = allocated > 0 ? (pocket.spent / allocated * 100) : 0;
          final remaining = allocated - pocket.spent;
          
          Color statusColor = percent > 100 ? colorScheme.error : (percent > 80 ? Colors.orange : AppTheme.success);
          
          return _ModernCard(
            surfaceColor: surfaceColor,
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pocket.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              remaining >= 0 
                                  ? '${formatCurrency(remaining, currency)} left'
                                  : '${formatCurrency(remaining.abs(), currency)} over',
                              style: TextStyle(
                                fontSize: 13,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${percent.toInt()}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                          Text(
                            formatCurrency(pocket.spent, currency),
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: LinearProgressIndicator(
                    value: (percent / 100).clamp(0.0, 1.0),
                    backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(statusColor),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ============================================================================
  // RECURRING EXPENSES DETAILS
  // ============================================================================
  Widget _buildRecurringExpensesDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
    Color surfaceColor,
  ) {
    final recurringState = ref.watch(recurringTransactionsProvider(null));

    if (recurringState.data.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final allRecurring = recurringState.data.value ?? [];
    final recurringExpenses = allRecurring.where((r) => 
      r.currency == currency && r.type == 'expense'
    ).toList();

    if (recurringExpenses.isEmpty) {
      return _EmptyState(
        colorScheme: colorScheme,
        surfaceColor: surfaceColor,
        title: 'No Subscriptions',
        description: 'Add recurring bills to track fixed costs.',
      );
    }

    // Calculations
    final monthlyEquivalents = recurringExpenses.map((r) {
      final amount = r.amount;
      final monthly = switch ((r.recurrenceRule?.frequency ?? 'monthly').toLowerCase()) {
        'daily' => amount * 30,
        'weekly' => amount * 4,
        'monthly' => amount,
        'yearly' => amount / 12,
        _ => amount,
      };
      return MapEntry(r, monthly);
    }).toList();

    final totalMonthly = monthlyEquivalents.fold<double>(0, (sum, e) => sum + e.value);
    
    // Group by frequency
    final byFrequency = <String, List<RecurringTransaction>>{};
    for (final r in recurringExpenses) {
      final freq = (r.recurrenceRule?.frequency ?? 'monthly');
      byFrequency.putIfAbsent(freq, () => []).add(r);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsightCard(
          colorScheme: colorScheme,
          surfaceColor: surfaceColor,
          icon: Icons.calendar_today,
          title: 'Fixed Costs',
          content: 'You have committed to ${formatCurrency(totalMonthly, currency)} in monthly recurring expenses.',
        ),

        const SizedBox(height: 24),

        _ModernCard(
          surfaceColor: surfaceColor,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'TOTAL MONTHLY COMMITMENT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatCurrency(totalMonthly, currency),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        for (final entry in byFrequency.entries) ...[
          _SectionHeader(title: entry.key.toUpperCase(), colorScheme: colorScheme),
          const SizedBox(height: 12),
          _ModernCard(
            surfaceColor: surfaceColor,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ...entry.value.asMap().entries.map((item) {
                  final r = item.value;
                  final index = item.key;
                  final isLast = index == entry.value.length - 1;
                  final daysUntilNext = r.date.difference(DateTime.now()).inDays;
                  
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.receipt_long, color: Colors.black),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.description ?? 'Subscription',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    daysUntilNext <= 0 ? 'Due Today' : 'Due in $daysUntilNext days',
                                    style: TextStyle(
                                      fontSize: 13, 
                                      color: daysUntilNext <= 3 ? Colors.orange : colorScheme.onSurface.withValues(alpha: 0.5)
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatCurrency(r.amount, currency),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) 
                        Padding(
                          padding: const EdgeInsets.only(left: 80),
                          child: Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.1)),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  // ============================================================================
  // TOP EXPENSES DETAILS
  // ============================================================================
  Widget _buildTopExpensesDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
    Color surfaceColor,
  ) {
    final analyticsData = ref.watch(analyticsProvider);
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final expenses = analyticsData.allExpenses.where((e) =>
        e.currency == currency &&
        e.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
        e.type != 'income').toList();

    if (expenses.isEmpty) {
      return _EmptyState(
        colorScheme: colorScheme,
        surfaceColor: surfaceColor,
        title: 'No Expenses',
        description: 'Transactions for this month will appear here.',
      );
    }

    final sortedExpenses = List<ExpenseEntry>.from(expenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final topExpenses = sortedExpenses.take(10).toList();
    final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final topTotal = topExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final topPercentage = totalExpenses > 0 ? (topTotal / totalExpenses * 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsightCard(
          colorScheme: colorScheme,
          surfaceColor: surfaceColor,
          icon: Icons.pie_chart,
          title: 'Spending Concentration',
          content: 'Your top 10 purchases account for ${topPercentage.toInt()}% of your total spending this month.',
        ),
        
        const SizedBox(height: 24),
        
        _SectionHeader(title: 'Largest Transactions', colorScheme: colorScheme),
        const SizedBox(height: 12),

        _ModernCard(
          surfaceColor: surfaceColor,
          padding: EdgeInsets.zero,
          child: Column(
            children: topExpenses.asMap().entries.map((entry) {
              final index = entry.key;
              final expense = entry.value;
              final isLast = index == topExpenses.length - 1;
              final percent = totalExpenses > 0 ? (expense.amount / totalExpenses * 100) : 0;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: index < 3 ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: index < 3 ? Colors.white : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.category ?? 'Uncategorized',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMM d').format(expense.date),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatCurrency(expense.amount, currency),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${percent.toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(left: 68),
                      child: Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.1)),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // INCOME VS EXPENSES DETAILS
  // ============================================================================
  Widget _buildIncomeVsExpensesDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
    Color surfaceColor,
  ) {
    final analyticsData = ref.watch(analyticsProvider);
    final recurringState = ref.watch(recurringTransactionsProvider(null));

    if (recurringState.data.isLoading) return const Center(child: CircularProgressIndicator.adaptive());

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final thisMonthTransactions = analyticsData.allExpenses.where((e) =>
        e.currency == currency &&
        e.date.isAfter(startOfMonth.subtract(const Duration(days: 1)))).toList();
    
    final expenses = thisMonthTransactions.where((e) => e.type != 'income').fold<double>(0, (sum, e) => sum + e.amount);

    final recurringItems = recurringState.data.value ?? [];
    final monthlyIncome = recurringItems.where((r) => r.currency == currency && r.type == 'income').fold<double>(0, (sum, r) {
      final amount = r.amount;
      return sum + switch ((r.recurrenceRule?.frequency ?? 'monthly').toLowerCase()) {
        'daily' => amount * 30,
        'weekly' => amount * 4,
        'monthly' => amount,
        'yearly' => amount / 12,
        _ => amount,
      };
    });

    final netAmount = monthlyIncome - expenses;
    final savingsRate = monthlyIncome > 0 ? (netAmount / monthlyIncome * 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsightCard(
          colorScheme: colorScheme,
          surfaceColor: surfaceColor,
          icon: Icons.savings,
          title: 'Cash Flow',
          content: monthlyIncome > 0
              ? 'You have a ${savingsRate.toStringAsFixed(1)}% savings rate this month. ${netAmount >= 0 ? "You are cash positive." : "You are currently in a deficit."}'
              : 'Add income sources to track cash flow.',
        ),

        const SizedBox(height: 24),

        _ModernCard(
          surfaceColor: surfaceColor,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'NET CASH FLOW',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatCurrency(netAmount.abs(), currency),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: netAmount >= 0 ? AppTheme.success : colorScheme.error,
                  letterSpacing: -1,
                ),
              ),
               Text(
                netAmount >= 0 ? 'Surplus' : 'Deficit',
                style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: _ModernCard(
                surfaceColor: surfaceColor,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_downward, size: 16, color: AppTheme.success),
                        const SizedBox(width: 8),
                        Text('Income', style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatCurrency(monthlyIncome, currency),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ModernCard(
                surfaceColor: surfaceColor,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_upward, size: 16, color: colorScheme.error),
                        const SizedBox(width: 8),
                        Text('Expenses', style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatCurrency(expenses, currency),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // SPENDING RATE DETAILS
  // ============================================================================
  Widget _buildSpendingRateDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
    Color surfaceColor,
  ) {
    final analyticsData = ref.watch(analyticsProvider);
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final expenses = analyticsData.allExpenses.where((e) =>
        e.currency == currency &&
        e.date.isAfter(last30Days.subtract(const Duration(days: 1))) &&
        e.type != 'income').toList();

    if (expenses.isEmpty) {
      return _EmptyState(
        colorScheme: colorScheme,
        surfaceColor: surfaceColor,
        title: 'Need More Data',
        description: 'Spend tracking improves with time.',
      );
    }

    final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final dailyAverage = totalSpent / 30;
    final weeklyAverage = dailyAverage * 7;
    final projectedMonthly = dailyAverage * DateTime(now.year, now.month + 1, 0).day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsightCard(
          colorScheme: colorScheme,
          surfaceColor: surfaceColor,
          icon: Icons.speed,
          title: 'Velocity',
          content: 'You are spending approximately ${formatCurrency(dailyAverage, currency)} every day.',
        ),

        const SizedBox(height: 24),

        _ModernCard(
          surfaceColor: surfaceColor,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'DAILY AVERAGE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatCurrency(dailyAverage, currency),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: _StatCardSimple(
                label: 'Weekly Avg',
                value: formatCurrency(weeklyAverage, currency),
                surfaceColor: surfaceColor,
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCardSimple(
                label: 'Projected Month',
                value: formatCurrency(projectedMonthly, currency),
                surfaceColor: surfaceColor,
                colorScheme: colorScheme,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// MODERN UI HELPERS
// ============================================================================

class _ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color surfaceColor;

  const _ModernCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final Color surfaceColor;
  final IconData icon;
  final String title;
  final String content;

  const _InsightCard({
    required this.colorScheme,
    required this.surfaceColor,
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      surfaceColor: surfaceColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final String title;
  final String content;
  final bool isPositive;
  final bool isWarning;

  const _ActionCard({
    required this.colorScheme,
    required this.title,
    required this.content,
    this.isPositive = true,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPositive 
        ? AppTheme.success 
        : (isWarning ? Colors.orange : colorScheme.error);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.check_circle : (isWarning ? Icons.warning_amber : Icons.error_outline),
                color: color,
                size: 20
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(fontSize: 15, height: 1.4, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isFirst;
  final bool isLast;
  final ColorScheme colorScheme;

  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isFirst = false,
    this.isLast = false,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: !isLast ? Border(bottom: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.05))) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor ?? colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernCategoryCard extends StatelessWidget {
  final String name;
  final String amount;
  final double percentage;
  final Color color;
  final Color surfaceColor;
  final ColorScheme colorScheme;

  const _ModernCategoryCard({
    required this.name,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.surfaceColor,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      surfaceColor: surfaceColor,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text(amount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  final Color surfaceColor;
  final ColorScheme colorScheme;

  const _StatusCard({
    required this.count,
    required this.label,
    required this.color,
    required this.surfaceColor,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      surfaceColor: surfaceColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _StatCardSimple extends StatelessWidget {
  final String label;
  final String value;
  final Color surfaceColor;
  final ColorScheme colorScheme;

  const _StatCardSimple({
    required this.label,
    required this.value,
    required this.surfaceColor,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      surfaceColor: surfaceColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme colorScheme;

  const _SectionHeader({required this.title, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  final Color surfaceColor;
  final String title;
  final String description;

  const _EmptyState({
    required this.colorScheme,
    required this.surfaceColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return _ModernCard(
      surfaceColor: surfaceColor,
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyStateSimple extends StatelessWidget {
  final String message;
  final ColorScheme colorScheme;

  const _EmptyStateSimple({required this.message, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}