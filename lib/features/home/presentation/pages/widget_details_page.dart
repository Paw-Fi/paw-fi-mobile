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

/// Unified Widget Details Page - Comprehensive Implementation
/// Each widget type gets a detailed breakdown with real data, charts, and beginner-friendly explanations
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
    final colorScheme = Theme.of(context).colorScheme;
    
    String title;
    String question;
    
    switch (widgetType) {
      case 'budgetRemaining':
        title = context.l10n.budgetRemaining;
        question = 'How much do I have left to spend this month?';
        break;
      case 'pocketHealthScorecard':
        title = context.l10n.pocketHealth;
        question = 'Which categories am I overspending in?';
        break;
      case 'recurringExpensesSummary':
        title = context.l10n.recurringExpenses;
        question = 'What are my recurring costs?';
        break;
      case 'topExpenses':
        title = context.l10n.topExpenses;
        question = 'What are my biggest expenses?';
        break;
      case 'incomeVsExpenses':
        title = context.l10n.incomeVsExpenses;
        question = 'Am I saving money?';
        break;
      case 'spendingRate':
        title = context.l10n.spendingRate;
        question = 'How much am I spending per day/week on average?';
        break;
      default:
        title = 'Details';
        question = '';
    }

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: title,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Question Banner
            if (question.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          question,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Content based on widget type
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildDetailsContent(context, colorScheme, widgetType, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsContent(
    BuildContext context,
    ColorScheme colorScheme,
    String type,
    WidgetRef ref,
  ) {
    switch (type) {
      case 'budgetRemaining':
        return _buildBudgetRemainingDetails(context, colorScheme, ref);
      case 'pocketHealthScorecard':
        return _buildPocketHealthDetails(context, colorScheme, ref);
      case 'recurringExpensesSummary':
        return _buildRecurringExpensesDetails(context, colorScheme, ref);
      case 'topExpenses':
        return _buildTopExpensesDetails(context, colorScheme, ref);
      case 'incomeVsExpenses':
        return _buildIncomeVsExpensesDetails(context, colorScheme, ref);
      case 'spendingRate':
        return _buildSpendingRateDetails(context, colorScheme, ref);
      default:
        return Center(
          child: Text(
            'Details for $type',
            style: TextStyle(color: colorScheme.mutedForeground),
          ),
        );
    }
  }

  // ============================================================================
  // BUDGET REMAINING DETAILS - Comprehensive Implementation
  // ============================================================================
  Widget _buildBudgetRemainingDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) {
    final analyticsData = ref.watch(analyticsProvider);
    final pocketsState = ref.watch(pocketsProvider(PocketsScopeParams(
      scope: PocketsScopeType.personal,
      householdId: null,
    )));
    final recurringState = ref.watch(recurringTransactionsProvider(null));
    
    if (pocketsState.isLoading || recurringState.data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final pockets = pocketsState.saved;
    final totalBudget = pocketsState.totalBudget;
    
    // Calculate spent from expenses (this month only)
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explanation Box
        _buildExplanationBox(
          context,
          colorScheme,
          'What This Means',
          totalBudget > 0
              ? 'You started the month with ${formatCurrency(totalBudget, currency)} to spend. So far you\'ve spent ${formatCurrency(totalSpent, currency)}, and ${formatCurrency(recurringMonthly, currency)} is committed to recurring bills. That leaves you ${formatCurrency(remaining, currency)} to spend for the rest of the month.\n\nWith $daysLeftInMonth days left, you can safely spend about ${formatCurrency(dailyBudget.toDouble(), currency)} per day.'
              : 'Set up your budget by creating pockets and allocating percentages to each category. This will help you track your spending and stay on budget.',
        ),
        
        const SizedBox(height: 16),
        
        // Summary Card
        Card(
          color: colorScheme.cardSurface,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDetailRow(context, colorScheme, 'Total Monthly Budget', formatCurrency(totalBudget, currency), bold: true),
                const Divider(height: 24),
                _buildDetailRow(context, colorScheme, 'Spent So Far', formatCurrency(totalSpent, currency), valueColor: colorScheme.destructive),
                const SizedBox(height: 12),
                _buildDetailRow(context, colorScheme, 'Recurring Committed', formatCurrency(recurringMonthly, currency), valueColor: Colors.orange),
                const Divider(height: 24),
                _buildDetailRow(context, colorScheme, 'Remaining', formatCurrency(remaining, currency), 
                  valueColor: remaining >= 0 ? AppTheme.success : colorScheme.destructive, bold: true),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '$daysLeftInMonth days left • ${formatCurrency(dailyBudget.toDouble(), currency)}/day available',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Action Items
        if (totalBudget > 0)
          _buildActionBox(
            context,
            colorScheme,
            'What To Do Next',
            percentUsed < 80
                ? '✅ You\'re on track! Keep monitoring your daily spending.\n${remaining > 0 ? '• Consider saving the extra ${formatCurrency(remaining, currency)} if possible\n' : ''}• Watch out for upcoming bills'
                : percentUsed < 100
                    ? '⚠️ You\'re using ${percentUsed.toStringAsFixed(0)}% of your budget.\n• Be cautious with discretionary spending\n• Review your upcoming expenses\n• Consider cutting back on non-essentials'
                    : '❌ You\'re over budget by ${formatCurrency(remaining.abs(), currency)}.\n• Stop discretionary spending immediately\n• Review all upcoming expenses\n• Look for ways to reduce costs\n• Consider moving money from savings if needed',
          ),
        
        const SizedBox(height: 24),
        
        // Pocket Breakdown
        _buildSectionTitle(context, colorScheme, 'Budget by Category'),
        const SizedBox(height: 12),
        
        if (pockets.isEmpty)
          _buildEmptyState(context, colorScheme, 'No pockets configured yet', 'Create pockets to track spending by category and see detailed breakdowns here.')
        else
          ...pockets.map((pocket) {
            final pocketSpent = pocket.spent;
            final pocketAllocated = (totalBudget * pocket.percentage / 100);
            final pocketRemaining = pocketAllocated - pocketSpent;
            final percentage = pocketAllocated > 0 ? (pocketSpent / pocketAllocated * 100) : 0;
            
            return Card(
              color: colorScheme.cardSurface,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pocket.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${formatCurrency(pocketSpent, currency)} / ${formatCurrency(pocketAllocated, currency)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: percentage > 100 ? colorScheme.destructive : colorScheme.foreground
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (percentage / 100).clamp(0.0, 1.0),
                        backgroundColor: colorScheme.mutedForeground.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(
                          percentage > 100 ? colorScheme.destructive : 
                          percentage > 80 ? Colors.orange : AppTheme.success
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${percentage.toStringAsFixed(0)}% used',
                          style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground),
                        ),
                        Text(
                          pocketRemaining >= 0 
                              ? '${formatCurrency(pocketRemaining, currency)} remaining' 
                              : '${formatCurrency(pocketRemaining.abs(), currency)} over',
                          style: TextStyle(
                            fontSize: 12,
                            color: pocketRemaining >= 0 ? AppTheme.success : colorScheme.destructive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ============================================================================
  // POCKET HEALTH DETAILS - Comprehensive Implementation
  // ============================================================================
  Widget _buildPocketHealthDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) {
    final pocketsState = ref.watch(pocketsProvider(PocketsScopeParams(
      scope: PocketsScopeType.personal,
      householdId: null,
    )));
    
    if (pocketsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final pockets = pocketsState.saved;
    final totalBudget = pocketsState.totalBudget;
    
    if (pockets.isEmpty) {
      return _buildEmptyState(
        context,
        colorScheme,
        'No pockets configured yet',
        'Create pockets to assign budgets to different spending categories. Each pocket helps you track and limit spending in specific areas like groceries, transportation, or entertainment.',
      );
    }
    
    // Sort pockets: over-budget first, then by percentage used
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explanation
        _buildExplanationBox(
          context,
          colorScheme,
          'What This Means',
          overBudgetPockets.isNotEmpty
              ? 'You have ${overBudgetPockets.length} ${overBudgetPockets.length == 1 ? 'category' : 'categories'} over budget. This means you\'ve spent more than allocated in these areas. Review these pockets and consider moving budget from underused categories or cutting spending.'
              : warningPockets.isNotEmpty
                  ? 'You have ${warningPockets.length} ${warningPockets.length == 1 ? 'category' : 'categories'} nearing the budget limit (>80%). Watch these closely to avoid overspending.'
                  : 'All your spending categories are healthy! You\'re staying within budget across all pockets. Keep up the good work!',
        ),
        
        const SizedBox(height: 16),
        
        // Summary Stats
        Card(
          color: colorScheme.cardSurface,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    context,
                    colorScheme,
                    overBudgetPockets.length.toString(),
                    'Over Budget',
                    colorScheme.destructive,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatBox(
                    context,
                    colorScheme,
                    warningPockets.length.toString(),
                    'At Risk',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatBox(
                    context,
                    colorScheme,
                    healthyPockets.length.toString(),
                    'Healthy',
                    AppTheme.success,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Action Items
        if (overBudgetPockets.isNotEmpty)
          _buildActionBox(
            context,
            colorScheme,
            'What To Do Next',
            '❌ Immediate Actions Needed:\n' +
            overBudgetPockets.take(3).map((p) {
              final allocated = totalBudget * p.percentage / 100;
              final over = p.spent - allocated;
              return '• ${p.name}: Stop spending, over by ${formatCurrency(over, currency)}';
            }).join('\n') +
            '\n\nConsider moving budget from: ${healthyPockets.take(2).map((p) => p.name).join(', ')}',
          )
        else if (warningPockets.isNotEmpty)
          _buildActionBox(
            context,
            colorScheme,
            'What To Do Next',
            '⚠️ Watch These Categories:\n' +
            warningPockets.take(3).map((p) {
              final allocated = totalBudget * p.percentage / 100;
              final remaining = allocated - p.spent;
              return '• ${p.name}: Only ${formatCurrency(remaining, currency)} left';
            }).join('\n') +
            '\n\nBe mindful of discretionary spending in these areas.',
          )
        else
          _buildActionBox(
            context,
            colorScheme,
            'What To Do Next',
            '✅ You\'re doing great!\n• All categories are within budget\n• Keep tracking your expenses\n• Consider saving extra from underused pockets',
          ),
        
        const SizedBox(height: 24),
        
        // All Pockets List
        _buildSectionTitle(context, colorScheme, 'All Categories'),
        const SizedBox(height: 12),
        
        ...sortedPockets.map((pocket) {
          final allocated = totalBudget * pocket.percentage / 100;
          final percent = allocated > 0 ? (pocket.spent / allocated * 100) : 0;
          final remaining = allocated - pocket.spent;
          
          Color statusColor;
          String statusIcon;
          if (percent > 100) {
            statusColor = colorScheme.destructive;
            statusIcon = '❌';
          } else if (percent > 80) {
            statusColor = Colors.orange;
            statusIcon = '⚠️';
          } else {
            statusColor = AppTheme.success;
            statusIcon = '✅';
          }
          
          return Card(
            color: colorScheme.cardSurface,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(statusIcon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pocket.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Spent: ${formatCurrency(pocket.spent, currency)}',
                        style: TextStyle(fontSize: 13, color: colorScheme.mutedForeground),
                      ),
                      Text(
                        'Budget: ${formatCurrency(allocated, currency)}',
                        style: TextStyle(fontSize: 13, color: colorScheme.mutedForeground),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (percent / 100).clamp(0.0, 1.0),
                      backgroundColor: colorScheme.mutedForeground.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(statusColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    remaining >= 0 
                        ? '${formatCurrency(remaining, currency)} remaining (${(100 - percent).toStringAsFixed(0)}% left)'
                        : '${formatCurrency(remaining.abs(), currency)} over budget',
                    style: TextStyle(
                      fontSize: 13,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ============================================================================
  // RECURRING EXPENSES DETAILS - Comprehensive Implementation
  // ============================================================================
  Widget _buildRecurringExpensesDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) {
    final recurringState = ref.watch(recurringTransactionsProvider(null));
    
    if (recurringState.data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final allRecurring = recurringState.data.value ?? [];
    final recurringExpenses = allRecurring.where((r) => 
      r.currency == currency && r.type == 'expense'
    ).toList();
    
    if (recurringExpenses.isEmpty) {
      return _buildEmptyState(
        context,
        colorScheme,
        'No recurring expenses tracked yet',
        'Add your subscriptions, bills, and other recurring expenses to track your fixed monthly costs. This helps you understand your baseline spending and plan your budget better.',
      );
    }
    
    // Calculate monthly equivalent for each
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
    
    // Calculate upcoming (next 7 days)
    final now = DateTime.now();
    final upcomingThisWeek = recurringExpenses.where((r) {
      final next = r.date;
      return next.isAfter(now.subtract(const Duration(days: 1))) && 
             next.isBefore(now.add(const Duration(days: 7)));
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explanation
        _buildExplanationBox(
          context,
          colorScheme,
          'What This Means',
          'You have ${recurringExpenses.length} recurring ${recurringExpenses.length == 1 ? 'expense' : 'expenses'} totaling ${formatCurrency(totalMonthly, currency)} per month. These are your fixed costs that automatically come out regularly. Understanding these helps you plan your budget for variable expenses.',
        ),
        
        const SizedBox(height: 16),
        
        // Summary Card
        Card(
          color: colorScheme.cardSurface,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  formatCurrency(totalMonthly, currency),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total per month',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatBox(context, colorScheme, recurringExpenses.length.toString(), 'Active', colorScheme.primary),
                    _buildStatBox(context, colorScheme, upcomingThisWeek.length.toString(), 'This Week', Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Action Items
        _buildActionBox(
          context,
          colorScheme,
          'What To Do Next',
          upcomingThisWeek.isNotEmpty
              ? '⚠️ Upcoming This Week (${formatCurrency(upcomingThisWeek.fold<double>(0, (sum, r) => sum + r.amount), currency)}):\n' +
                upcomingThisWeek.take(5).map((r) => '• ${(r.description ?? 'Recurring')}: ${formatCurrency(r.amount, currency)} on ${DateFormat('MMM d').format(r.date)}').join('\n')
              : '✅ No recurring expenses due this week\n• Review your subscriptions for ones you don\'t use\n• Consider annual billing for savings\n• Look for better deals on services',
        ),
        
        const SizedBox(height: 24),
        
        // Grouped by Frequency
        for (final entry in byFrequency.entries) ...[
          _buildSectionTitle(context, colorScheme, '${entry.key} (${entry.value.length})'),
          const SizedBox(height: 12),
          ...entry.value.map((r) {
            final monthlyEquiv = monthlyEquivalents.firstWhere((e) => e.key == r).value;
            final daysUntilNext = r.date.difference(now).inDays;
            
            return Card(
              color: colorScheme.cardSurface,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.repeat,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (r.description ?? 'Recurring'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatCurrency(r.amount, currency)} • Next: ${daysUntilNext <= 0 ? 'Today' : daysUntilNext == 1 ? 'Tomorrow' : 'in $daysUntilNext days'}',
                            style: TextStyle(fontSize: 13, color: colorScheme.mutedForeground),
                          ),
                          if ((r.recurrenceRule?.frequency ?? 'monthly').toLowerCase() != 'monthly')
                            Text(
                              '≈ ${formatCurrency(monthlyEquiv, currency)}/month',
                              style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground.withValues(alpha: 0.7)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // ============================================================================
  // TOP EXPENSES DETAILS - Comprehensive Implementation
  // ============================================================================
  Widget _buildTopExpensesDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) {
    final analyticsData = ref.watch(analyticsProvider);
    
    // Get expenses for current month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final expenses = analyticsData.allExpenses.where((e) =>
        e.currency == currency &&
        e.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
        e.type != 'income').toList();
    
    if (expenses.isEmpty) {
      return _buildEmptyState(
        context,
        colorScheme,
        'No expenses recorded yet',
        'Start logging your expenses to see your top spending items here. This helps you identify where your money is going and find opportunities to save.',
      );
    }
    
    // Sort by amount and take top 10
    final sortedExpenses = List<ExpenseEntry>.from(expenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final topExpenses = sortedExpenses.take(10).toList();
    
    final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final topTotal = topExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final topPercentage = totalExpenses > 0 ? (topTotal / totalExpenses * 100) : 0;
    
    // Category distribution in top expenses
    final categoryCount = <String, int>{};
    for (final e in topExpenses) {
      final cat = e.category ?? 'Uncategorized';
      categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
    }
    
    final topCategory = categoryCount.entries.isNotEmpty
        ? categoryCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'None';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explanation
        _buildExplanationBox(
          context,
          colorScheme,
          'What This Means',
          'Your top 10 expenses this month total ${formatCurrency(topTotal, currency)}, which is ${topPercentage.toStringAsFixed(0)}% of all spending. These are your biggest individual purchases. The most common category is "$topCategory".',
        ),
        
        const SizedBox(height: 16),
        
        // Summary Card
        Card(
          color: colorScheme.cardSurface,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDetailRow(context, colorScheme, 'Total All Expenses', formatCurrency(totalExpenses, currency), bold: true),
                const Divider(height: 24),
                _buildDetailRow(context, colorScheme, 'Top 10 Total', formatCurrency(topTotal, currency)),
                const SizedBox(height: 8),
                _buildDetailRow(context, colorScheme, 'Percentage', '${topPercentage.toStringAsFixed(0)}%', valueColor: colorScheme.primary),
                const Divider(height: 24),
                _buildDetailRow(context, colorScheme, 'Total Count', '${expenses.length} expenses'),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Action Items
        _buildActionBox(
          context,
          colorScheme,
          'What To Do Next',
          topPercentage > 70
              ? '⚠️ Your top 10 expenses represent ${topPercentage.toStringAsFixed(0)}% of spending.\n• Review if these are necessary expenses\n• Look for cheaper alternatives\n• Consider if timing can be adjusted'
              : '✅ Your spending is well distributed.\n• Keep tracking all expenses\n• Review if any large purchases can be reduced\n• Consider saving on your biggest categories',
        ),
        
        const SizedBox(height: 24),
        
        // Top 10 List
        _buildSectionTitle(context, colorScheme, 'Top 10 Expenses This Month'),
        const SizedBox(height: 12),
        
        ...topExpenses.asMap().entries.map((entry) {
          final index = entry.key;
          final expense = entry.value;
          final percent = totalExpenses > 0 ? (expense.amount / totalExpenses * 100) : 0;
          
          return Card(
            color: colorScheme.cardSurface,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Rank
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: index < 3 
                          ? colorScheme.primary.withValues(alpha: 0.2)
                          : colorScheme.mutedForeground.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: index < 3 ? colorScheme.primary : colorScheme.foreground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (expense.category ?? 'Expense'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (expense.category != null) ...[
                              Text(
                                expense.category!,
                                style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground),
                              ),
                              Text(' • ', style: TextStyle(color: colorScheme.mutedForeground)),
                            ],
                            Text(
                              DateFormat('MMM d').format(expense.date),
                              style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency(expense.amount, currency),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ============================================================================
  // INCOME VS EXPENSES DETAILS - Comprehensive Implementation
  // ============================================================================
  Widget _buildIncomeVsExpensesDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) {
    final analyticsData = ref.watch(analyticsProvider);
    final recurringState = ref.watch(recurringTransactionsProvider(null));
    
    if (recurringState.data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Get expenses and income for this month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final thisMonthTransactions = analyticsData.allExpenses.where((e) =>
        e.currency == currency &&
        e.date.isAfter(startOfMonth.subtract(const Duration(days: 1)))).toList();
    
    final expenses = thisMonthTransactions.where((e) => e.type != 'income').fold<double>(0, (sum, e) => sum + e.amount);
    
    // Calculate income from recurring
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
    
    // Get last month for comparison
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = startOfMonth.subtract(const Duration(days: 1));
    final lastMonthExpenses = analyticsData.allExpenses.where((e) =>
        e.currency == currency &&
        e.date.isAfter(lastMonthStart.subtract(const Duration(days: 1))) &&
        e.date.isBefore(lastMonthEnd.add(const Duration(days: 1))) &&
        e.type != 'income').fold<double>(0, (sum, e) => sum + e.amount);
    
    final expenseChange = lastMonthExpenses > 0 ? ((expenses - lastMonthExpenses) / lastMonthExpenses * 100) : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explanation
        _buildExplanationBox(
          context,
          colorScheme,
          'What This Means',
          monthlyIncome > 0
              ? netAmount >= 0
                  ? 'You\'re earning ${formatCurrency(monthlyIncome, currency)} per month and spending ${formatCurrency(expenses, currency)}. You\'re saving ${formatCurrency(netAmount, currency)} (${savingsRate.toStringAsFixed(1)}% savings rate). Great job!'
                  : 'You\'re earning ${formatCurrency(monthlyIncome, currency)} per month but spending ${formatCurrency(expenses, currency)}. You\'re ${formatCurrency(netAmount.abs(), currency)} short. You need to either increase income or reduce spending.'
              : 'Set up recurring income to track your monthly earnings and see if you\'re saving money or living beyond your means.',
        ),
        
        const SizedBox(height: 16),
        
        // Summary Card
        Card(
          color: colorScheme.cardSurface,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.arrow_downward, color: AppTheme.success, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Income',
                            style: TextStyle(fontSize: 13, color: colorScheme.mutedForeground),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(monthlyIncome, currency),
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.success),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 80,
                      color: colorScheme.mutedForeground.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.arrow_upward, color: colorScheme.destructive, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Expenses',
                            style: TextStyle(fontSize: 13, color: colorScheme.mutedForeground),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(expenses, currency),
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: colorScheme.destructive),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Column(
                  children: [
                    Text(
                      netAmount >= 0 ? 'Surplus' : 'Deficit',
                      style: TextStyle(fontSize: 13, color: colorScheme.mutedForeground),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(netAmount.abs(), currency),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: netAmount >= 0 ? AppTheme.success : colorScheme.destructive,
                      ),
                    ),
                    if (monthlyIncome > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${savingsRate.toStringAsFixed(1)}% savings rate',
                        style: TextStyle(fontSize: 13, color: colorScheme.mutedForeground),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Comparison to Last Month
        if (lastMonthExpenses > 0)
          Card(
            color: colorScheme.cardSurface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    expenseChange > 0 ? Icons.trending_up : Icons.trending_down,
                    color: expenseChange > 0 ? colorScheme.destructive : AppTheme.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Spending is ${expenseChange.abs().toStringAsFixed(1)}% ${expenseChange > 0 ? 'higher' : 'lower'} than last month',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Action Items
        _buildActionBox(
          context,
          colorScheme,
          'What To Do Next',
          savingsRate >= 20
              ? '✅ Excellent savings rate!\n• Keep up the great work\n• Consider investing your surplus\n• Build an emergency fund if you haven\'t\n• At this rate you\'ll save ${formatCurrency(netAmount * 12, currency)} this year'
              : savingsRate >= 10
                  ? '✅ Good savings rate!\n• Try to increase to 20% if possible\n• Look for small ways to cut expenses\n• You\'re on track to save ${formatCurrency(netAmount * 12, currency)} this year'
                  : savingsRate > 0
                      ? '⚠️ Low savings rate\n• Review your expenses for cuts\n• Consider increasing income\n• Focus on essential spending only\n• Target: Save at least 10-20% of income'
                      : '❌ Spending more than earning\n• Immediate action required\n• Cut non-essential expenses now\n• Look for additional income sources\n• Review all subscriptions and recurring costs',
        ),
        
        const SizedBox(height: 24),
        
        // Income Sources
        if (recurringItems.where((r) => r.type == 'income').isNotEmpty) ...[
          _buildSectionTitle(context, colorScheme, 'Income Sources'),
          const SizedBox(height: 12),
          ...recurringItems.where((r) => r.currency == currency && r.type == 'income').map((income) {
            return Card(
              color: colorScheme.cardSurface,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.payments, color: AppTheme.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(income.description ?? "Recurring Income", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      '${formatCurrency(income.amount, currency)}/${(income.recurrenceRule?.frequency ?? 'monthly')}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.success),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // ============================================================================
  // SPENDING RATE DETAILS - Comprehensive Implementation
  // ============================================================================
  Widget _buildSpendingRateDetails(
    BuildContext context,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) {
    final analyticsData = ref.watch(analyticsProvider);
    
    // Get expenses for last 30 days
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final expenses = analyticsData.allExpenses.where((e) =>
        e.currency == currency &&
        e.date.isAfter(last30Days.subtract(const Duration(days: 1))) &&
        e.type != 'income').toList();
    
    if (expenses.isEmpty) {
      return _buildEmptyState(
        context,
        colorScheme,
        'Not enough data yet',
        'Log expenses for at least a week to see your daily and weekly spending patterns. This helps you understand your spending habits and identify trends.',
      );
    }
    
    final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final dailyAverage = totalSpent / 30;
    final weeklyAverage = dailyAverage * 7;
    
    // Group by day
    final byDay = <DateTime, double>{};
    for (final e in expenses) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      byDay[day] = (byDay[day] ?? 0) + e.amount;
    }
    
    // Find highest and lowest spending days
    final sortedDays = byDay.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final highestDay = sortedDays.isNotEmpty ? sortedDays.first : null;
    final lowestDay = sortedDays.isNotEmpty ? sortedDays.last : null;
    
    // Day of week analysis
    final byDayOfWeek = <int, double>{};
    final countByDayOfWeek = <int, int>{};
    for (final e in expenses) {
      final dow = e.date.weekday;
      byDayOfWeek[dow] = (byDayOfWeek[dow] ?? 0) + e.amount;
      countByDayOfWeek[dow] = (countByDayOfWeek[dow] ?? 0) + 1;
    }
    
    final avgByDayOfWeek = byDayOfWeek.map((k, v) => MapEntry(k, v / (countByDayOfWeek[k] ?? 1)));
    final highestDow = avgByDayOfWeek.entries.isNotEmpty 
        ? avgByDayOfWeek.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;
    
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    // Monthly projection
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final projectedMonthly = dailyAverage * daysInMonth;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explanation
        _buildExplanationBox(
          context,
          colorScheme,
          'What This Means',
          'Over the last 30 days, you\'ve spent ${formatCurrency(totalSpent, currency)}. That\'s an average of ${formatCurrency(dailyAverage, currency)} per day or ${formatCurrency(weeklyAverage, currency)} per week. You tend to spend most on ${highestDow != null ? dayNames[highestDow.key - 1] : 'weekdays'}.',
        ),
        
        const SizedBox(height: 16),
        
        // Summary Card
        Card(
          color: colorScheme.cardSurface,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  formatCurrency(dailyAverage, currency),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'per day on average',
                  style: TextStyle(fontSize: 14, color: colorScheme.mutedForeground),
                ),
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            formatCurrency(weeklyAverage, currency),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.foreground),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'per week',
                            style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: colorScheme.mutedForeground.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            formatCurrency(projectedMonthly, currency),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.foreground),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'projected/month',
                            style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Highest/Lowest Days
        if (highestDay != null && lowestDay != null)
          Card(
            color: colorScheme.cardSurface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Highest Spending Day', style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d').format(highestDay.key),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        formatCurrency(highestDay.value, currency),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.destructive),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lowest Spending Day', style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d').format(lowestDay.key),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        formatCurrency(lowestDay.value, currency),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.success),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Action Items
        _buildActionBox(
          context,
          colorScheme,
          'What To Do Next',
          '📊 Spending Insights:\n' +
          (highestDow != null ? '• You spend most on ${dayNames[highestDow.key - 1]} (${formatCurrency(highestDow.value, currency)} avg)\n' : '') +
          '• At current rate: ${formatCurrency(projectedMonthly, currency)} this month\n' +
          (dailyAverage > 50 ? '• Try to reduce daily spending by 10-20%\n' : '') +
          '• Track expenses daily to stay aware',
        ),
        
        const SizedBox(height: 24),
        
        // Day of Week Chart
        if (avgByDayOfWeek.isNotEmpty) ...[
          _buildSectionTitle(context, colorScheme, 'Average Spending by Day of Week'),
          const SizedBox(height: 12),
          Card(
            color: colorScheme.cardSurface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: dayNames.asMap().entries.map((entry) {
                  final dow = entry.key + 1;
                  final name = entry.value;
                  final amount = avgByDayOfWeek[dow] ?? 0;
                  final maxAmount = avgByDayOfWeek.values.isNotEmpty ? avgByDayOfWeek.values.reduce((a, b) => a > b ? a : b) : 1;
                  final percentage = maxAmount > 0 ? amount / maxAmount : 0;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              formatCurrency(amount, currency),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.mutedForeground),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: percentage.toDouble(),
                            backgroundColor: colorScheme.mutedForeground.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================================
  // HELPER WIDGETS
  // ============================================================================
  
  Widget _buildSectionTitle(
    BuildContext context,
    ColorScheme colorScheme,
    String title,
  ) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colorScheme.foreground,
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    ColorScheme colorScheme,
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.mutedForeground,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? colorScheme.foreground,
          ),
        ),
      ],
    );
  }

  Widget _buildExplanationBox(
    BuildContext context,
    ColorScheme colorScheme,
    String title,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.foreground,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBox(
    BuildContext context,
    ColorScheme colorScheme,
    String title,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.foreground,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(
    BuildContext context,
    ColorScheme colorScheme,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.mutedForeground,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    String title,
    String description,
  ) {
    return Card(
      color: colorScheme.cardSurface,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.mutedForeground.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 40,
                color: colorScheme.mutedForeground.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
