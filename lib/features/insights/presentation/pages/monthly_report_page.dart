import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/insights/domain/monthly_financial_report.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';
import 'package:moneko/features/insights/presentation/widgets/insights_ui.dart';
import 'package:moneko/features/utils/currency.dart';

class MonthlyReportPage extends ConsumerWidget {
  const MonthlyReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final reportAsync = ref.watch(monthlyFinancialReportProvider);

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: reportAsync.when(
          loading: () => _buildLoadingState(colorScheme),
          error: (error, _) => _buildErrorState(context, colorScheme, error),
          data: (report) =>
              _buildReportContent(context, ref, colorScheme, report),
        ),
      ),
    );
  }

  Widget _buildReportContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(monthlyFinancialReportProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverallHealthStatus(context, colorScheme, report),
            const SizedBox(height: 24),
            _buildTopSummaryCards(context, colorScheme, report),
            const SizedBox(height: 24),
            _buildSafeToSpend(context, colorScheme, report),
            const SizedBox(height: 24),
            _buildBudgetHealthRows(context, colorScheme, report),
            const SizedBox(height: 24),
            _buildAnomalies(context, colorScheme, report),
            const SizedBox(height: 24),
            _buildSubscriptions(context, colorScheme, report),
            const SizedBox(height: 24),
            _buildBillCalendar(context, colorScheme, report),
            const SizedBox(height: 24),
            _buildCashFlowForecast(context, colorScheme, report),
            const SizedBox(height: 24),
            _buildGoals(context, colorScheme, report),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallHealthStatus(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Monthly Health Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              _buildStatusBadge(report.overview.status, colorScheme),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            report.summary,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.foreground,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSummaryCards(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        _buildGridCard(
          colorScheme: colorScheme,
          icon: Icons.account_balance_wallet_rounded,
          iconColor: AppTheme.success,
          label: 'Safe to spend',
          value: '${formatCurrency(report.safeToSpend.dailyAmount, report.currencyCode)}/day',
          status: monthlyReportStatusLabel(report.overview.status),
        ),
        _buildGridCard(
          colorScheme: colorScheme,
          icon: Icons.monitor_heart_rounded,
          iconColor: AppTheme.danger,
          label: 'Spending pace',
          value: formatCurrency(report.overview.spending, report.currencyCode),
          status: 'Total spent',
        ),
        _buildGridCard(
          colorScheme: colorScheme,
          icon: Icons.savings_rounded,
          iconColor: AppTheme.insightsRunning,
          label: 'Savings progress',
          value: formatCurrency(report.overview.savings, report.currencyCode),
          status: 'Saved so far',
        ),
        _buildGridCard(
          colorScheme: colorScheme,
          icon: Icons.calendar_month_rounded,
          iconColor: AppTheme.warning,
          label: 'Upcoming bills',
          value: formatCurrency(report.subscriptions.totalMonthlyAmount, report.currencyCode),
          status: 'This month',
        ),
      ],
    );
  }

  Widget _buildGridCard({
    required ColorScheme colorScheme,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String status,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.homeCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icon,
            size: 44,
            color: iconColor.withValues(alpha: 0.8),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.foreground,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: iconColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafeToSpend(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return InsightsSectionCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Daily Safe-to-Spend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.foreground,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
              children: [
                const TextSpan(text: 'You can safely spend '),
                TextSpan(
                  text: '${formatCurrency(report.safeToSpend.dailyAmount, report.currencyCode)}/day',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
                TextSpan(
                  text: ' for the next ${report.safeToSpend.daysRemaining} days.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Based on remaining income, fixed bills, savings goals, and category budgets. Easy to understand without inspecting every category.',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetHealthRows(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    if (report.spendingPace.isEmpty) return const SizedBox.shrink();

    return InsightsSectionCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Budget Health & Pace', colorScheme),
          const SizedBox(height: 24),
          ...report.spendingPace.map((paceItem) {
            final healthItem = report.budgetHealth.firstWhere(
              (h) => h.name == paceItem.label,
              orElse: () => MonthlyBudgetHealthItem(
                name: paceItem.label,
                status: paceItem.status,
                budgetAmount: 0,
                spent: 0,
                remaining: 0,
              ),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildBudgetRow(context, colorScheme, report.currencyCode, paceItem, healthItem),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBudgetRow(
    BuildContext context, 
    ColorScheme colorScheme, 
    String currencyCode, 
    MonthlySpendingPaceItem paceItem, 
    MonthlyBudgetHealthItem healthItem,
  ) {
    final color = _statusColor(paceItem.status, colorScheme);
    final spentProgress = paceItem.spentProgress.clamp(0.0, 1.0);
    final timeProgress = paceItem.timeProgress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      paceItem.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(paceItem.status, colorScheme),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatCurrency(healthItem.spent, currencyCode)} spent',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
                Text(
                  'of ${formatCurrency(healthItem.budgetAmount, currencyCode)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final indicatorLeft = (constraints.maxWidth * timeProgress).clamp(0.0, constraints.maxWidth);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.muted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: spentProgress,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Positioned(
                  left: indicatorLeft,
                  top: -4,
                  child: Container(
                    height: 16,
                    width: 2,
                    decoration: BoxDecoration(
                      color: colorScheme.foreground,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          paceItem.insight,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.mutedForeground,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildAnomalies(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return InsightsSectionCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Unusual Activity', colorScheme),
          const SizedBox(height: 20),
          if (report.anomalies.isEmpty)
            _emptyText(colorScheme, 'No unusual spending detected from your real data.')
          else
            ...report.anomalies.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.search_rounded, size: 28, color: AppTheme.warning.withValues(alpha: 0.8)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.mutedForeground,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubscriptions(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return InsightsSectionCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('Subscriptions & Recurring', colorScheme),
              Text(
                '${formatCurrency(report.subscriptions.totalMonthlyAmount, report.currencyCode)}/mo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (report.subscriptions.items.isEmpty)
            _emptyText(colorScheme, 'No recurring expenses detected yet.')
          else
            ...report.subscriptions.items.take(6).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 28,
                      color: _subscriptionColor(item.status, colorScheme).withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.note,
                            style: TextStyle(
                              fontSize: 13,
                              color: _subscriptionColor(item.status, colorScheme),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(item.amount, report.currencyCode),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBillCalendar(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return InsightsSectionCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Bill Calendar', colorScheme),
          const SizedBox(height: 24),
          if (report.upcomingObligations.isEmpty)
            _emptyText(colorScheme, 'No upcoming bills or income detected this month.')
          else
            ...report.upcomingObligations.take(8).map(
              (item) {
                final isIncome = item.type == 'income';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          _formatShortDate(context, item.date),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: colorScheme.border.withValues(alpha: 0.5),
                        margin: const EdgeInsets.only(right: 16),
                      ),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                      Text(
                        isIncome
                            ? '+${formatCurrency(item.amount, report.currencyCode)}'
                            : formatCurrency(-item.amount, report.currencyCode),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isIncome ? AppTheme.success : colorScheme.foreground,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCashFlowForecast(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return InsightsSectionCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Cash Flow Forecast', colorScheme),
          const SizedBox(height: 24),
          ...report.cashFlowForecast.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            final isLast = index == report.cashFlowForecast.length - 1;
            return IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isLast ? colorScheme.primary : colorScheme.mutedForeground.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: colorScheme.mutedForeground.withValues(alpha: 0.1),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              index == 0 ? point.label : 'After ${point.label.toLowerCase()}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                                color: isLast ? colorScheme.foreground : colorScheme.mutedForeground,
                              ),
                            ),
                          ),
                          Text(
                            formatCurrency(point.balance, report.currencyCode),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                              color: isLast ? colorScheme.primary : colorScheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGoals(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return InsightsSectionCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Goals & Sinking Funds', colorScheme),
          const SizedBox(height: 24),
          if (report.goals.isEmpty)
            _emptyText(colorScheme, 'No active goals found for this currency.')
          else
            ...report.goals.take(5).map(
              (goal) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.flag_rounded, size: 24, color: colorScheme.primary.withValues(alpha: 0.8)),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  goal.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.foreground,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(goal.status, colorScheme),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: goal.progress,
                        backgroundColor: colorScheme.muted,
                        valueColor: AlwaysStoppedAnimation(colorScheme.primary.withValues(alpha: 0.8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Saved: ${formatCurrency(goal.currentAmount, report.currencyCode)} / ${formatCurrency(goal.targetAmount, report.currencyCode)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.foreground,
                          ),
                        ),
                        Text(
                          '+${formatCurrency(goal.monthlyNeeded, report.currencyCode)}/mo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    if (goal.status != MonthlyReportStatus.onTrack) ...[
                      const SizedBox(height: 10),
                      Text(
                        'You might need to adjust your contributions to stay on track for this goal.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.warning,
                          height: 1.4,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  Widget _buildStatusBadge(
      MonthlyReportStatus status, ColorScheme colorScheme) {
    final color = _statusColor(status, colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        monthlyReportStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      key: const ValueKey('monthly_report_loading'),
      child: CircularProgressIndicator(color: colorScheme.primary),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ColorScheme colorScheme,
    Object error,
  ) {
    return Center(
      key: const ValueKey('monthly_report_error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load monthly financial health: $error',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colorScheme.destructive,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, ColorScheme colorScheme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colorScheme.mutedForeground,
      ),
    );
  }

  Widget _emptyText(ColorScheme colorScheme, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: colorScheme.mutedForeground,
        height: 1.4,
      ),
    );
  }

  Color _statusColor(MonthlyReportStatus status, ColorScheme colorScheme) {
    switch (status) {
      case MonthlyReportStatus.onTrack:
      case MonthlyReportStatus.safeToSpend:
        return AppTheme.success;
      case MonthlyReportStatus.needsAttention:
      case MonthlyReportStatus.spendingFast:
        return AppTheme.warning;
      case MonthlyReportStatus.overBudget:
      case MonthlyReportStatus.unusualSpending:
        return AppTheme.danger;
    }
  }

  Color _subscriptionColor(
    MonthlySubscriptionStatus status,
    ColorScheme colorScheme,
  ) {
    switch (status) {
      case MonthlySubscriptionStatus.active:
      case MonthlySubscriptionStatus.upcoming:
        return colorScheme.mutedForeground;
      case MonthlySubscriptionStatus.priceIncrease:
        return AppTheme.warning;
      case MonthlySubscriptionStatus.duplicatePossible:
        return AppTheme.danger;
    }
  }

  String _formatShortDate(BuildContext context, DateTime date) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatMediumDate(date).split(',').first;
  }

  String _subscriptionInitial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }
}
