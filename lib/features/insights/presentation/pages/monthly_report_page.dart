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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, colorScheme, report),
            const SizedBox(height: 20),
            _buildOverallHealthStatus(context, colorScheme, report),
            const SizedBox(height: 28),
            _buildSectionLabel(colorScheme, 'Today'),
            const SizedBox(height: 12),
            _buildTopSummaryCards(context, colorScheme, report),
            const SizedBox(height: 28),
            _buildSectionLabel(colorScheme, 'Daily allowance'),
            const SizedBox(height: 12),
            _buildSafeToSpend(context, colorScheme, report),
            const SizedBox(height: 28),
            _buildSectionLabel(colorScheme, 'Budget health'),
            const SizedBox(height: 12),
            _buildBudgetHealthRows(context, colorScheme, report),
            const SizedBox(height: 28),
            _buildSectionLabel(colorScheme, 'Unusual activity'),
            const SizedBox(height: 12),
            _buildAnomalies(context, colorScheme, report),
            const SizedBox(height: 28),
            _buildSectionLabel(colorScheme, 'Recurring'),
            const SizedBox(height: 12),
            _buildSubscriptions(context, colorScheme, report),
            const SizedBox(height: 28),
            _buildSectionLabel(colorScheme, 'Coming up'),
            const SizedBox(height: 12),
            _buildBillCalendar(context, colorScheme, report),
            const SizedBox(height: 28),
            _buildSectionLabel(colorScheme, 'Cash flow forecast'),
            const SizedBox(height: 12),
            _buildCashFlowForecast(context, colorScheme, report),
            const SizedBox(height: 28),
            _buildSectionLabel(colorScheme, 'Goals & sinking funds'),
            const SizedBox(height: 12),
            _buildGoals(context, colorScheme, report),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    final monthLabel = _formatMonthYear(report.monthStart);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthLabel.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Monthly Report',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: colorScheme.foreground,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(ColorScheme colorScheme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: colorScheme.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildOverallHealthStatus(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    final statusColor = _statusColor(report.overview.status, colorScheme);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                monthlyReportStatusLabel(report.overview.status).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            report.summary,
            style: TextStyle(
              fontSize: 17,
              color: colorScheme.foreground,
              height: 1.45,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
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
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.92,
      children: [
        _buildGridCard(
          colorScheme: colorScheme,
          illustration: _Illustration.wallet,
          accent: colorScheme.success,
          label: 'Safe to spend',
          value:
              '${formatCurrency(report.safeToSpend.dailyAmount, report.currencyCode)}/day',
          status: monthlyReportStatusLabel(report.overview.status),
        ),
        _buildGridCard(
          colorScheme: colorScheme,
          illustration: _Illustration.pulse,
          accent: colorScheme.primary,
          label: 'Spending pace',
          value: formatCurrency(
              report.overview.spending, report.currencyCode),
          status: 'Total spent',
        ),
        _buildGridCard(
          colorScheme: colorScheme,
          illustration: _Illustration.coins,
          accent: AppTheme.insightsRunning,
          label: 'Savings progress',
          value: formatCurrency(
              report.overview.savings, report.currencyCode),
          status: 'Saved so far',
        ),
        _buildGridCard(
          colorScheme: colorScheme,
          illustration: _Illustration.calendar,
          accent: colorScheme.warning,
          label: 'Upcoming bills',
          value: formatCurrency(
              report.subscriptions.totalMonthlyAmount, report.currencyCode),
          status: 'This month',
        ),
      ],
    );
  }

  Widget _buildGridCard({
    required ColorScheme colorScheme,
    required _Illustration illustration,
    required Color accent,
    required String label,
    required String value,
    required String status,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 28,
            offset: const Offset(0, 6),
            spreadRadius: -8,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            height: 52,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _MonekoIllustration(
                variant: illustration,
                accent: accent,
                muted: colorScheme.mutedForeground,
                size: 52,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                  letterSpacing: 0.1,
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
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
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
    final daily = formatCurrency(
        report.safeToSpend.dailyAmount, report.currencyCode);
    final budgetRemaining = formatCurrency(
        report.safeToSpend.budgetRemaining, report.currencyCode);
    final futureIncome = formatCurrency(
        report.safeToSpend.futureIncome, report.currencyCode);
    final futureObligations = formatCurrency(
        report.safeToSpend.futureObligations, report.currencyCode);
    return InsightsSectionCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safe to spend daily',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.mutedForeground,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$daily/day',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          color: colorScheme.foreground,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'for the next ${report.safeToSpend.daysRemaining} days',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _MonekoIllustration(
                variant: _Illustration.pulse,
                accent: colorScheme.primary,
                muted: colorScheme.mutedForeground,
                size: 84,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            height: 1,
            color: colorScheme.border.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 18),
          _buildSafeRow(colorScheme, 'Budget remaining', budgetRemaining,
              colorScheme.foreground),
          const SizedBox(height: 12),
          _buildSafeRow(colorScheme, 'Expected income left', '+$futureIncome',
              colorScheme.success),
          const SizedBox(height: 12),
          _buildSafeRow(colorScheme, 'Bills still due', '−$futureObligations',
              colorScheme.warning),
        ],
      ),
    );
  }

  Widget _buildSafeRow(
    ColorScheme colorScheme,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
            letterSpacing: -0.2,
          ),
        ),
      ],
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
            final isLast = paceItem == report.spendingPace.last;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
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
          if (report.anomalies.isEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _MonekoIllustration(
                  variant: _Illustration.magnifier,
                  accent: colorScheme.success,
                  muted: colorScheme.mutedForeground,
                  size: 56,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'No unusual spending this month. Nice and steady.',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            )
          else
            ...report.anomalies.asMap().entries.map((entry) {
              final item = entry.value;
              final isLast = entry.key == report.anomalies.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _MonekoIllustration(
                        variant: _Illustration.magnifier,
                        accent: _statusColor(item.status, colorScheme),
                        muted: colorScheme.mutedForeground,
                        size: 44,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.foreground,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.mutedForeground,
                              height: 1.45,
                            ),
                          ),
                        ],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly recurring',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${formatCurrency(report.subscriptions.totalMonthlyAmount, report.currencyCode)}/mo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.foreground,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              _MonekoIllustration(
                variant: _Illustration.receipt,
                accent: colorScheme.primary,
                muted: colorScheme.mutedForeground,
                size: 64,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: colorScheme.border.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          if (report.subscriptions.items.isEmpty)
            _emptyText(colorScheme, 'No recurring expenses detected yet.')
          else
            ...report.subscriptions.items.take(6).toList().asMap().entries.map(
              (entry) {
                final item = entry.value;
                final isLast = entry.key ==
                    report.subscriptions.items.take(6).length - 1;
                final accent = _subscriptionColor(item.status, colorScheme);
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 4,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.foreground,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.note,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: accent,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatCurrency(item.amount, report.currencyCode),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.foreground,
                          letterSpacing: -0.3,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Bill calendar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _MonekoIllustration(
                variant: _Illustration.calendar,
                accent: colorScheme.warning,
                muted: colorScheme.mutedForeground,
                size: 56,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (report.upcomingObligations.isEmpty)
            _emptyText(colorScheme,
                'No upcoming bills or income detected this month.')
          else
            ...report.upcomingObligations.take(8).toList().asMap().entries.map(
              (entry) {
                final item = entry.value;
                final isIncome = item.type == 'income';
                final isLast = entry.key ==
                    report.upcomingObligations.take(8).length - 1;
                final accent = isIncome
                    ? colorScheme.success
                    : colorScheme.mutedForeground;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _formatDayNumber(item.date),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: accent,
                                height: 1.0,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatMonthAbbrev(item.date).toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: accent.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        isIncome
                            ? '+${formatCurrency(item.amount, report.currencyCode)}'
                            : formatCurrency(
                                -item.amount, report.currencyCode),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isIncome
                              ? colorScheme.success
                              : colorScheme.foreground,
                          letterSpacing: -0.3,
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'End of month forecast',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatCurrency(report.overview.forecastedBalance,
                          report.currencyCode),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.foreground,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              _MonekoIllustration(
                variant: _Illustration.coins,
                accent: colorScheme.success,
                muted: colorScheme.mutedForeground,
                size: 64,
              ),
            ],
          ),
          const SizedBox(height: 22),
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
          if (report.goals.isEmpty)
            Row(
              children: [
                _MonekoIllustration(
                  variant: _Illustration.target,
                  accent: colorScheme.primary,
                  muted: colorScheme.mutedForeground,
                  size: 56,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'No active goals found for this currency.',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.mutedForeground,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            )
          else
            ...report.goals.take(5).toList().asMap().entries.map((entry) {
              final goal = entry.value;
              final isLast = entry.key == report.goals.take(5).length - 1;
              final pct = (goal.progress.clamp(0.0, 1.0) * 100).round();
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.foreground,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _statusColor(goal.status, colorScheme),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: goal.progress,
                        backgroundColor:
                            colorScheme.muted.withValues(alpha: 0.6),
                        valueColor: AlwaysStoppedAnimation(
                            _statusColor(goal.status, colorScheme)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${formatCurrency(goal.currentAmount, report.currencyCode)} of ${formatCurrency(goal.targetAmount, report.currencyCode)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                              letterSpacing: -0.1,
                            ),
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
                          color: colorScheme.warning,
                          height: 1.4,
                        ),
                      ),
                    ]
                  ],
                ),
              );
            }),
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

  String _formatMonthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDayNumber(DateTime date) => date.day.toString();

  String _formatMonthAbbrev(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[date.month - 1];
  }
}

enum _Illustration { wallet, pulse, coins, calendar, target, receipt, magnifier }

class _MonekoIllustration extends StatelessWidget {
  const _MonekoIllustration({
    required this.variant,
    required this.accent,
    required this.muted,
    this.size = 56,
  });

  final _Illustration variant;
  final Color accent;
  final Color muted;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IllustrationPainter(
          variant: variant,
          accent: accent,
          muted: muted,
        ),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter({
    required this.variant,
    required this.accent,
    required this.muted,
  });

  final _Illustration variant;
  final Color accent;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = accent
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final softFill = Paint()
      ..color = accent.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    switch (variant) {
      case _Illustration.wallet:
        _paintWallet(canvas, w, h, fill, softFill, stroke);
        break;
      case _Illustration.pulse:
        _paintPulse(canvas, w, h, softFill, stroke);
        break;
      case _Illustration.coins:
        _paintCoins(canvas, w, h, fill, softFill, stroke);
        break;
      case _Illustration.calendar:
        _paintCalendar(canvas, w, h, fill, softFill, stroke);
        break;
      case _Illustration.target:
        _paintTarget(canvas, w, h, fill, softFill, stroke);
        break;
      case _Illustration.receipt:
        _paintReceipt(canvas, w, h, fill, softFill, stroke);
        break;
      case _Illustration.magnifier:
        _paintMagnifier(canvas, w, h, fill, softFill, stroke);
        break;
    }
  }

  void _paintWallet(
      Canvas canvas, double w, double h, Paint fill, Paint soft, Paint stroke) {
    final body = RRect.fromLTRBR(
      w * 0.10, h * 0.30, w * 0.92, h * 0.82, Radius.circular(w * 0.12));
    canvas.drawRRect(body, soft);
    canvas.drawRRect(body, stroke);
    // Flap
    final flap = Path()
      ..moveTo(w * 0.18, h * 0.30)
      ..lineTo(w * 0.62, h * 0.18)
      ..lineTo(w * 0.78, h * 0.30)
      ..close();
    canvas.drawPath(flap, fill);
    canvas.drawPath(flap, stroke);
    // Clasp dot
    final dot = Paint()..color = stroke.color;
    canvas.drawCircle(Offset(w * 0.74, h * 0.58), w * 0.05, dot);
  }

  void _paintPulse(
      Canvas canvas, double w, double h, Paint soft, Paint stroke) {
    // baseline soft band
    final band = RRect.fromLTRBR(
        w * 0.06, h * 0.46, w * 0.94, h * 0.58, Radius.circular(h));
    canvas.drawRRect(band, soft);
    final path = Path()
      ..moveTo(w * 0.06, h * 0.55)
      ..lineTo(w * 0.26, h * 0.55)
      ..lineTo(w * 0.34, h * 0.30)
      ..lineTo(w * 0.44, h * 0.78)
      ..lineTo(w * 0.54, h * 0.40)
      ..lineTo(w * 0.62, h * 0.62)
      ..lineTo(w * 0.74, h * 0.55)
      ..lineTo(w * 0.94, h * 0.55);
    canvas.drawPath(path, stroke);
  }

  void _paintCoins(
      Canvas canvas, double w, double h, Paint fill, Paint soft, Paint stroke) {
    void coin(Rect r) {
      canvas.drawOval(r, soft);
      canvas.drawOval(r, stroke);
    }
    coin(Rect.fromLTWH(w * 0.20, h * 0.62, w * 0.55, h * 0.18));
    coin(Rect.fromLTWH(w * 0.18, h * 0.46, w * 0.58, h * 0.18));
    coin(Rect.fromLTWH(w * 0.22, h * 0.28, w * 0.52, h * 0.18));
    // shine
    final shine = Paint()
      ..color = stroke.color.withValues(alpha: 0.6)
      ..strokeWidth = stroke.strokeWidth * 0.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.34, h * 0.34),
      Offset(w * 0.48, h * 0.34),
      shine,
    );
  }

  void _paintCalendar(
      Canvas canvas, double w, double h, Paint fill, Paint soft, Paint stroke) {
    final body = RRect.fromLTRBR(
        w * 0.12, h * 0.22, w * 0.88, h * 0.86, Radius.circular(w * 0.10));
    canvas.drawRRect(body, soft);
    canvas.drawRRect(body, stroke);
    // top binder line
    final line = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth * 0.9
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(w * 0.12, h * 0.40), Offset(w * 0.88, h * 0.40), line);
    // rings
    canvas.drawLine(Offset(w * 0.32, h * 0.14), Offset(w * 0.32, h * 0.30), stroke);
    canvas.drawLine(Offset(w * 0.68, h * 0.14), Offset(w * 0.68, h * 0.30), stroke);
    // dot for date
    final dot = Paint()..color = accent;
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.42, h * 0.54, w * 0.58, h * 0.70, Radius.circular(w * 0.04)),
      dot,
    );
  }

  void _paintTarget(
      Canvas canvas, double w, double h, Paint fill, Paint soft, Paint stroke) {
    final center = Offset(w / 2, h / 2);
    canvas.drawCircle(center, w * 0.42, soft);
    canvas.drawCircle(center, w * 0.42, stroke);
    canvas.drawCircle(center, w * 0.28, stroke);
    canvas.drawCircle(center, w * 0.12, Paint()..color = accent);
    // arrow
    final arrow = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.80, h * 0.20),
      center,
      arrow,
    );
  }

  void _paintReceipt(
      Canvas canvas, double w, double h, Paint fill, Paint soft, Paint stroke) {
    final path = Path()
      ..moveTo(w * 0.22, h * 0.16)
      ..lineTo(w * 0.78, h * 0.16)
      ..lineTo(w * 0.78, h * 0.84)
      ..lineTo(w * 0.70, h * 0.78)
      ..lineTo(w * 0.60, h * 0.84)
      ..lineTo(w * 0.50, h * 0.78)
      ..lineTo(w * 0.40, h * 0.84)
      ..lineTo(w * 0.30, h * 0.78)
      ..lineTo(w * 0.22, h * 0.84)
      ..close();
    canvas.drawPath(path, soft);
    canvas.drawPath(path, stroke);
    final line = Paint()
      ..color = stroke.color.withValues(alpha: 0.7)
      ..strokeWidth = stroke.strokeWidth * 0.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.32, h * 0.36), Offset(w * 0.66, h * 0.36), line);
    canvas.drawLine(Offset(w * 0.32, h * 0.50), Offset(w * 0.58, h * 0.50), line);
    canvas.drawLine(Offset(w * 0.32, h * 0.64), Offset(w * 0.62, h * 0.64), line);
  }

  void _paintMagnifier(
      Canvas canvas, double w, double h, Paint fill, Paint soft, Paint stroke) {
    final center = Offset(w * 0.44, h * 0.44);
    final r = w * 0.28;
    canvas.drawCircle(center, r, soft);
    canvas.drawCircle(center, r, stroke);
    final handle = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth * 1.1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx + r * 0.72, center.dy + r * 0.72),
      Offset(w * 0.86, h * 0.86),
      handle,
    );
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter old) =>
      old.variant != variant || old.accent != accent || old.muted != muted;
}
