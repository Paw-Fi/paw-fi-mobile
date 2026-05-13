import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/insights/domain/monthly_financial_report.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/shimmering_text.dart';

const _monthlyReportFakeProgressCap = 0.965;
const _monthlyReportFakeProgressTimeConstantSeconds = 10.0;
const _monthlyReportCompletionDuration = Duration(milliseconds: 260);

class MonthlyReportPage extends HookConsumerWidget {
  const MonthlyReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final reportAsync = ref.watch(monthlyFinancialReportProvider);
    final loadedSnapshot = reportAsync.valueOrNull;
    final visibleSnapshot = useState<MonthlyFinancialReportSnapshot?>(null);
    final isCompletingInitialLoad = useState(false);

    useEffect(() {
      if (loadedSnapshot == null) {
        if (visibleSnapshot.value == null) {
          isCompletingInitialLoad.value = false;
        }
        return null;
      }

      if (visibleSnapshot.value == null) {
        isCompletingInitialLoad.value = true;
        return null;
      }

      if (!identical(visibleSnapshot.value, loadedSnapshot)) {
        visibleSnapshot.value = loadedSnapshot;
      }

      return null;
    }, [loadedSnapshot]);

    final snapshot = visibleSnapshot.value;

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: snapshot != null && !isCompletingInitialLoad.value
            ? _buildReportContent(context, ref, colorScheme, snapshot)
            : reportAsync.hasError && loadedSnapshot == null
                ? _buildErrorState(context, colorScheme, reportAsync.error!)
                : _buildLoadingState(
                    colorScheme,
                    isComplete: isCompletingInitialLoad.value,
                    onComplete: () {
                      final completedSnapshot = loadedSnapshot;
                      if (!context.mounted || completedSnapshot == null) return;
                      visibleSnapshot.value = completedSnapshot;
                      isCompletingInitialLoad.value = false;
                    },
                  ),
      ),
    );
  }

  Widget _buildReportContent(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    MonthlyFinancialReportSnapshot snapshot,
  ) {
    final report = snapshot.report;

    return RefreshIndicator(
      onRefresh: () => ref
          .read(monthlyFinancialReportProvider.notifier)
          .refreshReport(),
      color: colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeader(context, colorScheme, snapshot),
                const SizedBox(height: 12),
                _buildHealthRingsSummary(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildOverallHealthStatus(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildTopSummaryCards(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildMonthTrend(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildBudgetPlanSummary(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildSafeToSpend(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildCategoryTrends(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildMerchantConcentration(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildBudgetHealthRows(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildSpendingPaceTracking(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildAnomalies(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildRecurringCommitment(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildSubscriptions(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildBillCalendar(context, colorScheme, report),
                const SizedBox(height: 12),
                _buildCashFlowForecast(context, colorScheme, report),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReportSnapshot snapshot,
  ) {
    final report = snapshot.report;
    final month = MaterialLocalizations.of(context).formatMonthYear(
      report.monthStart,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            month,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.mutedForeground,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _MonthlyReportSyncStatus(
              key: ValueKey(
                '${snapshot.lastSyncedAt?.toIso8601String()}_${snapshot.isRefreshing}',
              ),
              colorScheme: colorScheme,
              lastSyncedAt: snapshot.lastSyncedAt,
              isRefreshing: snapshot.isRefreshing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallHealthStatus(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(18),
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
                      _healthHeadline(report.overview.status),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.foreground,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      report.summary,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _StandaloneIllustration(
                kind: _ReportIllustrationKind.pulse,
                colorScheme: colorScheme,
                accent: _statusColor(report.overview.status, colorScheme),
                size: 56,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusBadge(report.overview.status, colorScheme),
              _buildQuietMetric(
                colorScheme,
                'Forecast',
                formatCurrency(
                  report.overview.forecastedBalance,
                  report.currencyCode,
                ),
              ),
              _buildQuietMetric(
                colorScheme,
                'Saved',
                formatCurrency(report.overview.savings, report.currencyCode),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRingsSummary(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    final rings = _buildHealthRingMetrics(colorScheme, report);
    final overallScore = _overallHealthScore(rings);
    final watchCount = report.spendingPace
        .where(
          (item) =>
              item.status == MonthlyReportStatus.spendingFast ||
              item.status == MonthlyReportStatus.overBudget ||
              item.status == MonthlyReportStatus.needsAttention ||
              item.status == MonthlyReportStatus.unusualSpending,
        )
        .length;

    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 680;
          final ringSize = isWide ? 160.0 : 150.0;
          final legend = Column(
            children: [
              for (final metric in rings) ...[
                _HealthRingLegendRow(
                  colorScheme: colorScheme,
                  metric: metric,
                ),
                if (metric != rings.last) const SizedBox(height: 12),
              ],
            ],
          );
          final ring = Center(
            child: _MultiRingProgressIndicator(
              colorScheme: colorScheme,
              metrics: rings,
              size: ringSize,
              score: overallScore,
              status: monthlyReportStatusLabel(report.overview.status),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Financial Health Report',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.foreground,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                watchCount == 0
                    ? 'All core signals are moving within a healthy range.'
                    : '$watchCount signal${watchCount == 1 ? '' : 's'} need a closer look this month.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              if (isWide)
                Row(
                  children: [
                    SizedBox(width: ringSize, child: ring),
                    const SizedBox(width: 26),
                    Expanded(child: legend),
                  ],
                )
              else ...[
                ring,
                const SizedBox(height: 22),
                legend,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopSummaryCards(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    final items = [
      _SummaryItem(
        kind: _ReportIllustrationKind.wallet,
        label: 'Safe to spend today',
        value:
            '${formatCurrency(report.safeToSpend.dailyAmount, report.currencyCode)}/day',
        status: monthlyReportStatusLabel(report.overview.status),
        accent: colorScheme.success,
      ),
      _SummaryItem(
        kind: _ReportIllustrationKind.pulse,
        label: 'Monthly spending pace',
        value: formatCurrency(report.overview.spending, report.currencyCode),
        status: _paceStatus(report),
        accent: _statusColor(report.overview.status, colorScheme),
      ),
      _SummaryItem(
        kind: _ReportIllustrationKind.coins,
        label: 'Savings progress',
        value: formatCurrency(report.overview.savings, report.currencyCode),
        status:
            report.overview.savings >= 0 ? 'Building buffer' : 'Behind plan',
        accent: colorScheme.info,
      ),
      _SummaryItem(
        kind: _ReportIllustrationKind.calendar,
        label: 'Upcoming bills',
        value: formatCurrency(
          report.safeToSpend.futureObligations,
          report.currencyCode,
        ),
        status: '${report.upcomingObligations.length} scheduled',
        accent: colorScheme.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780 ? 4 : 2;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _buildSummaryCard(colorScheme, item),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMonthTrend(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    final trend = report.trendSummary;
    final hasAnyData = trend.currentIncome > 0 ||
        trend.currentSpending > 0 ||
        trend.previousIncome > 0 ||
        trend.previousSpending > 0;

    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            colorScheme: colorScheme,
            title: 'Month vs Last Month',
            subtitle: 'Compared with the same point in the previous month',
            kind: _ReportIllustrationKind.pulse,
            accent: colorScheme.info,
          ),
          const SizedBox(height: 16),
          if (!hasAnyData)
            _emptyText(
              colorScheme,
              'No income or spending has been recorded for this month yet.',
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildCalculationPill(
                  colorScheme,
                  'Income change',
                  _formatSignedCurrency(
                    trend.incomeChange,
                    report.currencyCode,
                  ),
                ),
                _buildCalculationPill(
                  colorScheme,
                  'Spending change',
                  _formatSignedCurrency(
                    trend.spendingChange,
                    report.currencyCode,
                  ),
                ),
                _buildCalculationPill(
                  colorScheme,
                  'Savings rate',
                  _formatPercent(trend.savingsRate),
                ),
                _buildCalculationPill(
                  colorScheme,
                  'Net cash flow',
                  _formatSignedCurrency(
                    trend.netCashFlow,
                    report.currencyCode,
                  ),
                ),
              ],
            ),
            if (report.netWorthTrend != null) ...[
              const SizedBox(height: 10),
              _InsightTile(
                colorScheme: colorScheme,
                title: 'Net worth',
                description:
                    '${formatCurrency(report.netWorthTrend!.currentNetWorth, report.currencyCode)} now, ${_formatSignedCurrency(report.netWorthTrend!.change, report.currencyCode)} from the previous wallet snapshot.',
                status: _formatNullablePercent(
                  report.netWorthTrend!.changePercent,
                ),
                accent: report.netWorthTrend!.change >= 0
                    ? colorScheme.success
                    : colorScheme.warning,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetPlanSummary(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    final plan = report.budgetPlan;
    final hasBudgetData = plan.totalBudgeted > 0 || plan.totalSpent > 0;

    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            colorScheme: colorScheme,
            title: 'Budget Plan',
            subtitle: 'Budgeted, spent, remaining, and unbudgeted money',
            kind: _ReportIllustrationKind.target,
            accent: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          if (!hasBudgetData)
            _emptyText(
              colorScheme,
              'No budgets or spending have been recorded for this month yet.',
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildCalculationPill(
                  colorScheme,
                  'Budgeted',
                  formatCurrency(plan.totalBudgeted, report.currencyCode),
                ),
                _buildCalculationPill(
                  colorScheme,
                  'Spent',
                  formatCurrency(plan.totalSpent, report.currencyCode),
                ),
                _buildCalculationPill(
                  colorScheme,
                  'Remaining',
                  formatCurrency(plan.totalRemaining, report.currencyCode),
                ),
                _buildCalculationPill(
                  colorScheme,
                  'Budget / income',
                  _formatNullablePercent(plan.budgetToIncomeRatio),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuietMetric(
                  colorScheme,
                  'Over',
                  '${plan.overBudgetCount}',
                ),
                _buildQuietMetric(
                  colorScheme,
                  'At risk',
                  '${plan.atRiskCount}',
                ),
                _buildQuietMetric(
                  colorScheme,
                  'Unbudgeted',
                  formatCurrency(plan.unbudgetedSpent, report.currencyCode),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTrends(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            colorScheme: colorScheme,
            title: 'Spending Movers',
            subtitle: 'Categories with meaningful movement from real history',
            kind: _ReportIllustrationKind.magnifier,
            accent: colorScheme.warning,
          ),
          const SizedBox(height: 16),
          if (report.categoryTrends.isEmpty)
            _emptyText(
              colorScheme,
              'Not enough comparable category history yet. This will appear once a category has real prior spending to compare.',
            )
          else
            ...report.categoryTrends.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InsightTile(
                  colorScheme: colorScheme,
                  title: item.name,
                  description:
                      '${item.insight} Current spend is ${formatCurrency(item.currentSpent, report.currencyCode)}.',
                  status: monthlyReportStatusLabel(item.status),
                  accent: _statusColor(item.status, colorScheme),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMerchantConcentration(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    final merchants = report.merchantConcentration;
    if (merchants.isEmpty) {
      return _ReportCard(
        colorScheme: colorScheme,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(
              colorScheme: colorScheme,
              title: 'Top Merchants',
              subtitle: 'Where the largest share of spending went this month',
              kind: _ReportIllustrationKind.receipt,
              accent: colorScheme.info,
            ),
            const SizedBox(height: 16),
            _emptyText(
              colorScheme,
              'No merchant or payee names are available in this month\'s spending yet.',
            ),
          ],
        ),
      );
    }

    final colors = [
      colorScheme.primary,
      colorScheme.info,
      colorScheme.success,
      colorScheme.warning,
      colorScheme.error,
    ];

    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            colorScheme: colorScheme,
            title: 'Top Merchants',
            subtitle: 'Where the largest share of spending went this month',
            kind: _ReportIllustrationKind.receipt,
            accent: colorScheme.info,
          ),
          const SizedBox(height: 16),
          Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: merchants.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final color = colors[index % colors.length];
                return Expanded(
                  flex: (item.spendingShare * 100).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: index == 0
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              bottomLeft: Radius.circular(6),
                            )
                          : index == merchants.length - 1
                              ? const BorderRadius.only(
                                  topRight: Radius.circular(6),
                                  bottomRight: Radius.circular(6),
                                )
                              : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: merchants.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final color = colors[index % colors.length];
              return _merchantLegendItem(
                colorScheme: colorScheme,
                color: color,
                name: item.name,
                percentage: item.spendingShare,
                amount: item.amount,
                currencyCode: report.currencyCode,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringCommitment(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    final commitment = report.recurringCommitment;
    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            colorScheme: colorScheme,
            title: 'Recurring Commitment',
            subtitle: 'How much income is already committed to recurring costs',
            kind: _ReportIllustrationKind.calendar,
            accent: colorScheme.warning,
          ),
          const SizedBox(height: 16),
          if (commitment.monthlyAmount <= 0)
            _emptyText(
                colorScheme, 'No active recurring expenses detected yet.')
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildCalculationPill(
                  colorScheme,
                  'Monthly recurring',
                  formatCurrency(commitment.monthlyAmount, report.currencyCode),
                ),
                _buildCalculationPill(
                  colorScheme,
                  'Income share',
                  _formatNullablePercent(commitment.incomeShare),
                ),
                _buildCalculationPill(
                  colorScheme,
                  'Due in 14 days',
                  formatCurrency(commitment.dueSoonAmount, report.currencyCode),
                ),
                _buildCalculationPill(
                  colorScheme,
                  'Due-soon count',
                  '${commitment.dueSoonCount}',
                ),
              ],
            ),
        ],
      ),
    );
  }


  Widget _buildSummaryCard(ColorScheme colorScheme, _SummaryItem item) {
    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _StandaloneIllustration(
                kind: item.kind,
                colorScheme: colorScheme,
                accent: item.accent,
                size: 48,
              ),
            ),
            const Spacer(),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorScheme.mutedForeground,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                item.value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: item.accent,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafeToSpend(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(18),
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
                    _sectionTitle('Daily Safe-to-Spend', colorScheme),
                    const SizedBox(height: 12),
                    Text(
                      'You can safely spend',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${formatCurrency(report.safeToSpend.dailyAmount, report.currencyCode)}/day',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.foreground,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'for the next ${report.safeToSpend.daysRemaining} days after bills and remaining budgets.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.mutedForeground,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _StandaloneIllustration(
                kind: _ReportIllustrationKind.wallet,
                colorScheme: colorScheme,
                accent: colorScheme.success,
                size: 64,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildCalculationPill(
                colorScheme,
                'Budget left',
                formatCurrency(
                  report.safeToSpend.budgetRemaining,
                  report.currencyCode,
                ),
              ),
              _buildCalculationPill(
                colorScheme,
                'Fixed bills',
                formatCurrency(
                  report.safeToSpend.futureObligations,
                  report.currencyCode,
                ),
              ),
              _buildCalculationPill(
                colorScheme,
                'Income ahead',
                formatCurrency(
                  report.safeToSpend.futureIncome,
                  report.currencyCode,
                ),
              ),
            ],
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

    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            colorScheme: colorScheme,
            title: 'Budget Health',
            subtitle: 'Category pace compared with this point in the month',
            kind: _ReportIllustrationKind.target,
            accent: colorScheme.primary,
          ),
          const SizedBox(height: 18),
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
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildBudgetRow(
                context,
                colorScheme,
                report.currencyCode,
                paceItem,
                healthItem,
              ),
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
    final pacePercent = (paceItem.spentProgress * 100).round();

    return Semantics(
      label:
          '${paceItem.label}, ${monthlyReportStatusLabel(paceItem.status)}, $pacePercent percent of budget used.',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.muted.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(20),
        ),
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
                        paceItem.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.foreground,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildStatusBadge(paceItem.status, colorScheme),
                          _buildQuietMetric(
                            colorScheme,
                            'Pace',
                            '$pacePercent%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrency(healthItem.remaining, currencyCode),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: healthItem.remaining < 0
                            ? colorScheme.destructive
                            : colorScheme.foreground,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'remaining',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PaceProgressBar(
              colorScheme: colorScheme,
              accent: color,
              spentProgress: spentProgress,
              timeProgress: timeProgress,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatCurrency(healthItem.spent, currencyCode)} spent',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'of ${formatCurrency(healthItem.budgetAmount, currencyCode)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              paceItem.insight,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.mutedForeground,
                height: 1.42,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingPaceTracking(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    if (report.spendingPace.isEmpty) return const SizedBox.shrink();

    final watched = report.spendingPace.take(3).toList(growable: false);
    final monthProgress = watched.first.timeProgress.clamp(0.0, 1.0);

    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            colorScheme: colorScheme,
            title: 'Spending Pace',
            subtitle: 'The month is ${(monthProgress * 100).round()}% complete',
            kind: _ReportIllustrationKind.pulse,
            accent: colorScheme.info,
          ),
          const SizedBox(height: 18),
          for (final item in watched) ...[
            _buildPaceComparisonRow(colorScheme, item),
            if (item != watched.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildPaceComparisonRow(
    ColorScheme colorScheme,
    MonthlySpendingPaceItem item,
  ) {
    final accent = _statusColor(item.status, colorScheme);
    final spentPercent = (item.spentProgress * 100).round();
    final timePercent = (item.timeProgress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                ),
              ),
            ),
            Text(
              '$spentPercent% used',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PaceProgressBar(
          colorScheme: colorScheme,
          accent: accent,
          spentProgress: item.spentProgress.clamp(0.0, 1.0),
          timeProgress: item.timeProgress.clamp(0.0, 1.0),
        ),
        const SizedBox(height: 6),
        Text(
          'Budget used: $spentPercent% · Month elapsed: $timePercent%',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.mutedForeground,
            fontWeight: FontWeight.w600,
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
    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            colorScheme: colorScheme,
            title: 'Unusual Activity',
            subtitle: 'Helpful pattern checks, not alarms',
            kind: _ReportIllustrationKind.magnifier,
            accent: colorScheme.warning,
          ),
          const SizedBox(height: 16),
          if (report.anomalies.isEmpty)
            _emptyText(
              colorScheme,
              'No unusual spending detected from your real data.',
            )
          else
            ...report.anomalies.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InsightTile(
                  colorScheme: colorScheme,
                  title: item.title,
                  description: item.description,
                  status: monthlyReportStatusLabel(item.status),
                  accent: _statusColor(item.status, colorScheme),
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
    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            colorScheme: colorScheme,
            title: 'Subscriptions & Recurring',
            subtitle:
                '${formatCurrency(report.subscriptions.totalMonthlyAmount, report.currencyCode)}/mo committed',
            kind: _ReportIllustrationKind.receipt,
            accent: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          if (report.subscriptions.items.isEmpty)
            _emptyText(colorScheme, 'No recurring expenses detected yet.')
          else
            ...report.subscriptions.items.take(6).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildSubscriptionRow(colorScheme, report, item),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionRow(
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlySubscriptionItem item,
  ) {
    final accent = _subscriptionColor(item.status, colorScheme);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.foreground,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.note,
                  style: TextStyle(
                    fontSize: 12,
                    color: accent,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(item.amount, report.currencyCode),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _formatShortDate(null, item.nextDate),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            colorScheme: colorScheme,
            title: 'Bill Calendar',
            subtitle: 'Upcoming obligations for the rest of the month',
            kind: _ReportIllustrationKind.calendar,
            accent: colorScheme.warning,
          ),
          const SizedBox(height: 16),
          if (report.upcomingObligations.isEmpty)
            _emptyText(
              colorScheme,
              'No upcoming bills or income detected this month.',
            )
          else
            ...report.upcomingObligations.take(8).map(
              (item) {
                final isIncome = item.type == 'income';
                final accent =
                    isIncome ? colorScheme.success : colorScheme.foreground;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 62,
                          child: Text(
                            _formatShortDate(context, item.date),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.mutedForeground,
                              height: 1.25,
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: colorScheme.border.withValues(alpha: 0.38),
                          margin: const EdgeInsets.only(right: 14),
                        ),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.foreground,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isIncome
                              ? '+${formatCurrency(item.amount, report.currencyCode)}'
                              : formatCurrency(
                                  -item.amount,
                                  report.currencyCode,
                                ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
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
    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            colorScheme: colorScheme,
            title: 'Cash Flow Forecast',
            subtitle: 'Expected balance after scheduled money movement',
            kind: _ReportIllustrationKind.wallet,
            accent: colorScheme.success,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildCalculationPill(
                colorScheme,
                'Lowest projected balance',
                formatCurrency(
                  report.cashFlowHealth.lowWaterBalance,
                  report.currencyCode,
                ),
              ),
              _buildCalculationPill(
                colorScheme,
                'Lowest date',
                report.cashFlowHealth.lowWaterDate == null
                    ? 'No projection'
                    : _formatShortDate(
                        context,
                        report.cashFlowHealth.lowWaterDate!,
                      ),
              ),
              _buildCalculationPill(
                colorScheme,
                'Negative balance',
                report.cashFlowHealth.firstNegativeDate == null
                    ? 'Not projected'
                    : _formatShortDate(
                        context,
                        report.cashFlowHealth.firstNegativeDate!,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...report.cashFlowForecast.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            final isLast = index == report.cashFlowForecast.length - 1;
            return _ForecastStep(
              colorScheme: colorScheme,
              label: index == 0
                  ? point.label
                  : isLast
                      ? point.label
                      : 'After ${point.label.toLowerCase()}',
              value: formatCurrency(point.balance, report.currencyCode),
              isLast: isLast,
              isFirst: index == 0,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    MonthlyReportStatus status,
    ColorScheme colorScheme,
  ) {
    final color = _statusColor(status, colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        monthlyReportStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildQuietMetric(
    ColorScheme colorScheme,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colorScheme.mutedForeground,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildCalculationPill(
    ColorScheme colorScheme,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.mutedForeground,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.foreground,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _merchantLegendItem({
    required ColorScheme colorScheme,
    required Color color,
    required String name,
    required double percentage,
    required double amount,
    required String currencyCode,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 4),
        Text(
          '(${_formatPercent(percentage)})',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.mutedForeground,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalRow(
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyGoalReportItem goal,
  ) {
    final accent = _statusColor(goal.status, colorScheme);
    final progress = goal.progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.foreground,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusBadge(goal.status, colorScheme),
            ],
          ),
          const SizedBox(height: 12),
          _PaceProgressBar(
            colorScheme: colorScheme,
            accent: accent,
            spentProgress: progress,
            timeProgress: 1,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_formatPercent(progress)} funded',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              Text(
                '${formatCurrency(goal.currentAmount, report.currencyCode)} / ${formatCurrency(goal.targetAmount, report.currencyCode)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          if (goal.monthlyNeeded > 0) ...[
            const SizedBox(height: 7),
            Text(
              '${formatCurrency(goal.monthlyNeeded, report.currencyCode)}/mo needed to hit the target date',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.mutedForeground,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(
    ColorScheme colorScheme, {
    required bool isComplete,
    required VoidCallback onComplete,
  }) {
    return _MonthlyReportLoadingState(
      key: const ValueKey('monthly_report_loading'),
      colorScheme: colorScheme,
      isComplete: isComplete,
      onComplete: onComplete,
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
        padding: const EdgeInsets.all(16),
        child: _ReportCard(
          colorScheme: colorScheme,
          child: Text(
            'Could not load monthly financial health: $error',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.destructive,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, ColorScheme colorScheme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: colorScheme.mutedForeground,
        height: 1.2,
      ),
    );
  }

  Widget _emptyText(ColorScheme colorScheme, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: colorScheme.mutedForeground,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Color _statusColor(MonthlyReportStatus status, ColorScheme colorScheme) {
    switch (status) {
      case MonthlyReportStatus.onTrack:
      case MonthlyReportStatus.safeToSpend:
        return colorScheme.success;
      case MonthlyReportStatus.needsAttention:
      case MonthlyReportStatus.spendingFast:
        return colorScheme.warning;
      case MonthlyReportStatus.overBudget:
      case MonthlyReportStatus.unusualSpending:
        return colorScheme.destructive;
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
        return colorScheme.warning;
      case MonthlySubscriptionStatus.duplicatePossible:
        return colorScheme.destructive;
    }
  }

  String _formatShortDate(BuildContext? context, DateTime date) {
    if (context == null) return '${date.day}/${date.month}';
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatMediumDate(date).split(',').first;
  }

  String _formatPercent(double value) => '${(value * 100).round()}%';

  String _formatNullablePercent(double? value) {
    if (value == null) return 'No baseline';
    final sign = value > 0 ? '+' : '';
    return '$sign${_formatPercent(value)}';
  }

  String _formatSignedCurrency(double value, String currencyCode) {
    if (value == 0) return formatCurrency(0, currencyCode);
    final sign = value > 0 ? '+' : '';
    return '$sign${formatCurrency(value, currencyCode)}';
  }

  String _healthHeadline(MonthlyReportStatus status) {
    switch (status) {
      case MonthlyReportStatus.onTrack:
      case MonthlyReportStatus.safeToSpend:
        return 'Your month is mostly on track.';
      case MonthlyReportStatus.spendingFast:
        return 'Your spending is moving a little fast.';
      case MonthlyReportStatus.needsAttention:
        return 'Your month needs a small adjustment.';
      case MonthlyReportStatus.overBudget:
        return 'A few budgets need attention.';
      case MonthlyReportStatus.unusualSpending:
        return 'There are spending patterns to review.';
    }
  }

  String _paceStatus(MonthlyFinancialReport report) {
    if (report.spendingPace.isEmpty) return 'No budgets yet';
    final fastCount = report.spendingPace
        .where(
          (item) =>
              item.status == MonthlyReportStatus.spendingFast ||
              item.status == MonthlyReportStatus.overBudget ||
              item.status == MonthlyReportStatus.needsAttention,
        )
        .length;
    if (fastCount == 0) return 'On expected pace';
    if (fastCount == 1) return '1 budget to watch';
    return '$fastCount budgets to watch';
  }

  List<_HealthRingMetric> _buildHealthRingMetrics(
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    final budgetPaceProgress = _budgetPaceProgress(report);
    final billsCoveredProgress = _billsCoveredProgress(report);
    final savingsBufferProgress = _savingsBufferProgress(report);
    final forecastIsPositive = report.overview.forecastedBalance >= 0;
    final vibrantPalette = _vibrantRingPalette(colorScheme);

    return [
      _HealthRingMetric(
        label: 'Safe spend',
        value:
            '${formatCurrency(report.safeToSpend.dailyAmount, report.currencyCode)}/day',
        status: report.safeToSpend.dailyAmount > 0
            ? 'Available today'
            : 'Hold spending',
        progress: _safeToSpendProgress(report),
        color: vibrantPalette[0],
        icon: Icons.wallet_rounded,
      ),
      _HealthRingMetric(
        label: 'Budget pace',
        value: '${(budgetPaceProgress * 100).round()}%',
        status: _paceStatus(report),
        progress: budgetPaceProgress,
        color: vibrantPalette[1],
        icon: Icons.speed_rounded,
      ),
      _HealthRingMetric(
        label: 'Bills covered',
        value: '${report.upcomingObligations.length} scheduled',
        status: billsCoveredProgress >= 1 ? 'Covered ahead' : 'Needs cash flow',
        progress: billsCoveredProgress,
        color: vibrantPalette[2],
        icon: Icons.event_note_rounded,
      ),
      _HealthRingMetric(
        label: 'Month-end buffer',
        value: formatCurrency(
          report.overview.forecastedBalance,
          report.currencyCode,
        ),
        status: forecastIsPositive ? 'Positive forecast' : 'Negative forecast',
        progress: savingsBufferProgress,
        color: forecastIsPositive ? vibrantPalette[3] : vibrantPalette[1],
        icon: Icons.savings_rounded,
      ),
    ];
  }

  int _overallHealthScore(List<_HealthRingMetric> rings) {
    final total = rings.fold<double>(
      0,
      (sum, metric) => sum + metric.progress.clamp(0.0, 1.0),
    );
    return ((total / rings.length) * 100).round();
  }

  double _safeToSpendProgress(MonthlyFinancialReport report) {
    if (report.safeToSpend.dailyAmount <= 0) return 0.08;
    if (report.overview.forecastedBalance <= 0) return 0.36;
    if (report.safeToSpend.budgetRemaining <= 0) return 0.48;

    switch (report.overview.status) {
      case MonthlyReportStatus.onTrack:
      case MonthlyReportStatus.safeToSpend:
        return 0.94;
      case MonthlyReportStatus.spendingFast:
      case MonthlyReportStatus.unusualSpending:
        return 0.72;
      case MonthlyReportStatus.needsAttention:
        return 0.62;
      case MonthlyReportStatus.overBudget:
        return 0.42;
    }
  }

  double _budgetPaceProgress(MonthlyFinancialReport report) {
    if (report.spendingPace.isEmpty) return 1;

    final totalOverspend = report.spendingPace.fold<double>(
      0,
      (sum, item) {
        final spentProgress = item.spentProgress.clamp(0.0, 1.4);
        final timeProgress = item.timeProgress.clamp(0.0, 1.0);
        return sum + math.max(0, spentProgress - timeProgress);
      },
    );
    final averageOverspend = totalOverspend / report.spendingPace.length;
    final baseScore = (1 - averageOverspend * 1.85).clamp(0.08, 1.0);

    final hasOverBudget = report.spendingPace.any(
      (item) => item.status == MonthlyReportStatus.overBudget,
    );
    return hasOverBudget ? math.min(baseScore, 0.52) : baseScore;
  }

  double _billsCoveredProgress(MonthlyFinancialReport report) {
    final obligations = report.safeToSpend.futureObligations;
    if (obligations <= 0) return 1;

    final available = math.max(0, report.overview.currentBalance) +
        report.safeToSpend.futureIncome;
    return (available / obligations).clamp(0.08, 2.4);
  }

  double _savingsBufferProgress(MonthlyFinancialReport report) {
    final forecast = report.overview.forecastedBalance;
    if (forecast <= 0) return 0.08;

    final monthlyReference = math.max(
      report.safeToSpend.futureObligations,
      math.max(report.overview.spending * 0.35, 1),
    );
    return (forecast / monthlyReference).clamp(0.12, 2.6);
  }

  List<Color> _vibrantRingPalette(ColorScheme colorScheme) {
    return [
      _vibrantColor(colorScheme.success),
      _vibrantColor(colorScheme.warning, hueShift: 6),
      _vibrantColor(colorScheme.info, hueShift: -18),
      _vibrantColor(colorScheme.primary, hueShift: 26),
    ];
  }

  Color _vibrantColor(Color color, {double hueShift = 0}) {
    final hsl = HSLColor.fromColor(color);
    final shiftedHue = (hsl.hue + hueShift + 360) % 360;

    return hsl
        .withHue(shiftedHue)
        .withSaturation((hsl.saturation + 0.2).clamp(0.48, 1.0))
        .withLightness((hsl.lightness - 0.02).clamp(0.34, 0.62))
        .toColor();
  }
}

class _MonthlyReportLoadingState extends HookWidget {
  const _MonthlyReportLoadingState({
    super.key,
    required this.colorScheme,
    required this.isComplete,
    required this.onComplete,
  });

  final ColorScheme colorScheme;
  final bool isComplete;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final fakeProgressController = useAnimationController(
      duration: const Duration(days: 1),
    );
    final completionController = useAnimationController(
      duration: _monthlyReportCompletionDuration,
    );
    final completeProgressStart = useRef(0.06);
    final didNotifyComplete = useRef(false);

    useEffect(() {
      fakeProgressController.forward();
      return null;
    }, const []);

    useEffect(() {
      void handleCompletionStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed || didNotifyComplete.value) {
          return;
        }
        didNotifyComplete.value = true;
        onComplete();
      }

      completionController.addStatusListener(handleCompletionStatus);

      if (isComplete) {
        completionController.forward();
      } else {
        didNotifyComplete.value = false;
        completionController.value = 0;
      }

      return () {
        completionController.removeStatusListener(handleCompletionStatus);
      };
    }, [isComplete, onComplete]);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _ReportCard(
            colorScheme: colorScheme,
            padding: const EdgeInsets.all(20),
            child: AnimatedBuilder(
              animation: Listenable.merge([
                fakeProgressController,
                completionController,
              ]),
              builder: (context, _) {
                final elapsed = fakeProgressController.lastElapsedDuration ??
                    Duration.zero;
                final elapsedSeconds = elapsed.inMilliseconds / 1000;
                final fakeProgress = math.max(
                  0.06,
                  _monthlyReportFakeProgressCap *
                      (1 -
                          math.exp(
                            -elapsedSeconds /
                                _monthlyReportFakeProgressTimeConstantSeconds,
                          )),
                );

                if (!isComplete) {
                  completeProgressStart.value = fakeProgress;
                }

                final completionProgress = Curves.easeOutCubic.transform(
                  completionController.value,
                );
                final visibleProgress = isComplete
                    ? completeProgressStart.value +
                        ((1 - completeProgressStart.value) *
                            completionProgress)
                    : fakeProgress;
                final progressPercent = (visibleProgress * 100).floor();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Building monthly report',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.foreground,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Checking budgets, trends, and upcoming commitments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.mutedForeground,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: visibleProgress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: colorScheme.mutedForeground
                            .withValues(alpha: 0.15),
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: ShimmeringText(
                        key: ValueKey(isComplete),
                        text: isComplete
                            ? 'Report ready'
                            : 'Preparing $progressPercent%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.mutedForeground,
                        ),
                        shimmering: !isComplete,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthlyReportSyncStatus extends StatelessWidget {
  const _MonthlyReportSyncStatus({
    super.key,
    required this.colorScheme,
    required this.lastSyncedAt,
    required this.isRefreshing,
  });

  final ColorScheme colorScheme;
  final DateTime? lastSyncedAt;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final foreground =
        isRefreshing ? colorScheme.primary : colorScheme.mutedForeground;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isRefreshing ? Icons.sync_rounded : Icons.cloud_done_rounded,
          size: 14,
          color: foreground,
        ),
        const SizedBox(width: 6),
        Text(
          isRefreshing
              ? 'Refreshing report'
              : 'Last synced ${_formatLastSyncedAt(context, lastSyncedAt)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: foreground,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

String _formatLastSyncedAt(BuildContext context, DateTime? value) {
  if (value == null) return 'never';

  final localValue = value.toLocal();
  final now = DateTime.now();
  final elapsed = now.difference(localValue);
  if (elapsed.inSeconds < 45) return 'just now';
  if (elapsed.inMinutes < 60) {
    final minutes = elapsed.inMinutes;
    return '$minutes min${minutes == 1 ? '' : 's'} ago';
  }
  if (elapsed.inHours < 12) {
    final hours = elapsed.inHours;
    return '$hours hour${hours == 1 ? '' : 's'} ago';
  }

  final localizations = MaterialLocalizations.of(context);
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(localValue),
  );
  final sameDay = now.year == localValue.year &&
      now.month == localValue.month &&
      now.day == localValue.day;
  if (sameDay) return 'today at $time';

  return '${localizations.formatShortDate(localValue)} at $time';
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.colorScheme,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final ColorScheme colorScheme;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.homeCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HealthRingMetric {
  const _HealthRingMetric({
    required this.label,
    required this.value,
    required this.status,
    required this.progress,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String status;
  final double progress;
  final Color color;
  final IconData icon;
}

class _MultiRingProgressIndicator extends StatelessWidget {
  const _MultiRingProgressIndicator({
    required this.colorScheme,
    required this.metrics,
    required this.size,
    required this.score,
    required this.status,
  });

  final ColorScheme colorScheme;
  final List<_HealthRingMetric> metrics;
  final double size;
  final int score;
  final String status;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Financial health summary, $score out of 100, $status.',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 920),
        curve: Curves.easeOutCubic,
        builder: (context, animationValue, _) {
          final centerDiameter = (size * 0.42).clamp(70.0, 88.0);
          final animatedScore = (score * animationValue).round();

          return CustomPaint(
            painter: _MultiRingProgressPainter(
              colorScheme: colorScheme,
              metrics: metrics,
              animationValue: animationValue,
            ),
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: SizedBox(
                  width: centerDiameter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$animatedScore',
                          style: TextStyle(
                            fontSize:animatedScore>99?23: 30,
                            fontWeight: FontWeight.w900,
                            color: colorScheme.foreground,
                            height: 0.95,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MultiRingProgressPainter extends CustomPainter {
  const _MultiRingProgressPainter({
    required this.colorScheme,
    required this.metrics,
    required this.animationValue,
  });

  final ColorScheme colorScheme;
  final List<_HealthRingMetric> metrics;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = (side * 0.048).clamp(8.0, 11.0);
    final gap = strokeWidth * 0.72;
    final outerRadius = side / 2 - strokeWidth / 2;
    final trackPaint = Paint()
      ..color = colorScheme.border.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      final radius = outerRadius - index * (strokeWidth + gap);
      final rect = Rect.fromCircle(center: center, radius: radius);
      final progress = math.max(0, metric.progress) * animationValue;
      final sweep = math.pi * 2 * progress;
      final overflowSweep = sweep % (math.pi * 2);

      canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);
      progressPaint.color = metric.color.withValues(alpha: 0.95);

      if (progress <= 1) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          sweep,
          false,
          progressPaint,
        );
      } else {
        canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, progressPaint);
        if (overflowSweep > 0.001) {
          canvas.drawArc(
            rect,
            -math.pi / 2,
            overflowSweep,
            false,
            progressPaint,
          );
        }
      }

      if (progress > 0.02) {
        _drawRingEndpointMarker(
          canvas,
          center,
          radius,
          -math.pi / 2 + sweep,
          strokeWidth,
          metric,
        );
      }
    }
  }

  void _drawRingEndpointMarker(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    double strokeWidth,
    _HealthRingMetric metric,
  ) {
    final markerRadius = (strokeWidth * 0.72).clamp(6.0, 8.0);
    final markerCenter = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    final markerFillPaint = Paint()
      ..color = metric.color
      ..style = PaintingStyle.fill;
    final markerBorderPaint = Paint()
      ..color = colorScheme.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = markerRadius * 0.34;

    canvas.drawCircle(markerCenter, markerRadius, markerFillPaint);
    canvas.drawCircle(markerCenter, markerRadius, markerBorderPaint);

    final iconSize = markerRadius * 1.08;
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(metric.icon.codePoint),
        style: TextStyle(
          inherit: false,
          fontSize: iconSize,
          fontFamily: metric.icon.fontFamily,
          package: metric.icon.fontPackage,
          color: colorScheme.surface,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      Offset(
        markerCenter.dx - iconPainter.width / 2,
        markerCenter.dy - iconPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MultiRingProgressPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme ||
        oldDelegate.metrics != metrics ||
        oldDelegate.animationValue != animationValue;
  }
}

class _HealthRingLegendRow extends StatelessWidget {
  const _HealthRingLegendRow({
    required this.colorScheme,
    required this.metric,
  });

  final ColorScheme colorScheme;
  final _HealthRingMetric metric;

  @override
  Widget build(BuildContext context) {
    final percent = (math.max(0, metric.progress) * 100).round();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 7,
          decoration: BoxDecoration(
            color: metric.color.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                metric.status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              metric.value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: colorScheme.foreground,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: metric.color,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.colorScheme,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.accent,
  });

  final ColorScheme colorScheme;
  final String title;
  final String subtitle;
  final _ReportIllustrationKind kind;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.foreground,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _StandaloneIllustration(
          kind: kind,
          colorScheme: colorScheme,
          accent: accent,
          size: 58,
        ),
      ],
    );
  }
}

class _PaceProgressBar extends StatelessWidget {
  const _PaceProgressBar({
    required this.colorScheme,
    required this.accent,
    required this.spentProgress,
    required this.timeProgress,
  });

  final ColorScheme colorScheme;
  final Color accent;
  final double spentProgress;
  final double timeProgress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final markerLeft = (constraints.maxWidth * timeProgress)
            .clamp(0.0, constraints.maxWidth);
        return SizedBox(
          height: 18,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.border.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              FractionallySizedBox(
                widthFactor: spentProgress,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Positioned(
                left: markerLeft,
                child: Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colorScheme.foreground.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.colorScheme,
    required this.title,
    required this.description,
    required this.status,
    required this.accent,
  });

  final ColorScheme colorScheme;
  final String title;
  final String description;
  final String status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.foreground,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.mutedForeground,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastStep extends StatelessWidget {
  const _ForecastStep({
    required this.colorScheme,
    required this.label,
    required this.value,
    required this.isLast,
    required this.isFirst,
  });

  final ColorScheme colorScheme;
  final String label;
  final String value;
  final bool isLast;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final accent = isLast ? colorScheme.primary : colorScheme.mutedForeground;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: isLast || isFirst ? 12 : 9,
                height: isLast || isFirst ? 12 : 9,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isLast ? 1 : 0.42),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    color: colorScheme.border.withValues(alpha: 0.28),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isLast ? FontWeight.w900 : FontWeight.w700,
                        color: isLast
                            ? colorScheme.foreground
                            : colorScheme.mutedForeground,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color:
                          isLast ? colorScheme.primary : colorScheme.foreground,
                      height: 1.25,
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
}

class _StandaloneIllustration extends StatelessWidget {
  const _StandaloneIllustration({
    required this.kind,
    required this.colorScheme,
    required this.accent,
    required this.size,
  });

  final _ReportIllustrationKind kind;
  final ColorScheme colorScheme;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _illustrationLabel(kind),
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _ReportIllustrationPainter(
          kind: kind,
          colorScheme: colorScheme,
          accent: accent,
        ),
      ),
    );
  }
}

class _ReportIllustrationPainter extends CustomPainter {
  const _ReportIllustrationPainter({
    required this.kind,
    required this.colorScheme,
    required this.accent,
  });

  final _ReportIllustrationKind kind;
  final ColorScheme colorScheme;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case _ReportIllustrationKind.wallet:
        _paintWallet(canvas, size);
      case _ReportIllustrationKind.calendar:
        _paintCalendar(canvas, size);
      case _ReportIllustrationKind.coins:
        _paintCoins(canvas, size);
      case _ReportIllustrationKind.pulse:
        _paintPulse(canvas, size);
      case _ReportIllustrationKind.target:
        _paintTarget(canvas, size);
      case _ReportIllustrationKind.receipt:
        _paintReceipt(canvas, size);
      case _ReportIllustrationKind.magnifier:
        _paintMagnifier(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _ReportIllustrationPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.accent != accent ||
        oldDelegate.colorScheme != colorScheme;
  }

  Paint _paint(Color color, {PaintingStyle style = PaintingStyle.fill}) {
    return Paint()
      ..color = color
      ..style = style
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  void _paintWallet(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shadow = colorScheme.shadow.withValues(alpha: 0.08);
    final muted = colorScheme.mutedForeground.withValues(alpha: 0.2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.34, w * 0.72, h * 0.42),
        Radius.circular(w * 0.14),
      ),
      _paint(shadow),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.28, w * 0.76, h * 0.42),
        Radius.circular(w * 0.13),
      ),
      _paint(accent.withValues(alpha: 0.18)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.18, w * 0.58, h * 0.34),
        Radius.circular(w * 0.1),
      ),
      _paint(colorScheme.homeCardSurface),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.46, h * 0.38, w * 0.36, h * 0.2),
        Radius.circular(w * 0.1),
      ),
      _paint(accent.withValues(alpha: 0.55)),
    );
    canvas.drawCircle(
      Offset(w * 0.62, h * 0.48),
      w * 0.035,
      _paint(colorScheme.homeCardSurface.withValues(alpha: 0.85)),
    );
    canvas.drawLine(
      Offset(w * 0.26, h * 0.34),
      Offset(w * 0.48, h * 0.34),
      _paint(muted, style: PaintingStyle.stroke)..strokeWidth = w * 0.035,
    );
  }

  void _paintCalendar(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Rect.fromLTWH(w * 0.18, h * 0.18, w * 0.64, h * 0.64);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(w * 0.12)),
      _paint(accent.withValues(alpha: 0.16)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.18, w * 0.64, h * 0.2),
        Radius.circular(w * 0.12),
      ),
      _paint(accent.withValues(alpha: 0.45)),
    );
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 2; j++) {
        canvas.drawCircle(
          Offset(w * (0.34 + i * 0.16), h * (0.52 + j * 0.14)),
          w * 0.028,
          _paint(
            i == 1 && j == 0
                ? accent
                : colorScheme.mutedForeground.withValues(alpha: 0.22),
          ),
        );
      }
    }
    canvas.drawLine(
      Offset(w * 0.34, h * 0.12),
      Offset(w * 0.34, h * 0.26),
      _paint(colorScheme.foreground.withValues(alpha: 0.3),
          style: PaintingStyle.stroke)
        ..strokeWidth = w * 0.04,
    );
    canvas.drawLine(
      Offset(w * 0.66, h * 0.12),
      Offset(w * 0.66, h * 0.26),
      _paint(colorScheme.foreground.withValues(alpha: 0.3),
          style: PaintingStyle.stroke)
        ..strokeWidth = w * 0.04,
    );
  }

  void _paintCoins(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < 4; i++) {
      final top = h * (0.58 - i * 0.11);
      canvas.drawOval(
        Rect.fromLTWH(w * 0.2, top, w * 0.56, h * 0.16),
        _paint(accent.withValues(alpha: i == 3 ? 0.62 : 0.28)),
      );
      canvas.drawArc(
        Rect.fromLTWH(w * 0.2, top, w * 0.56, h * 0.16),
        0,
        math.pi,
        false,
        _paint(colorScheme.homeCardSurface.withValues(alpha: 0.58),
            style: PaintingStyle.stroke)
          ..strokeWidth = w * 0.025,
      );
    }
    canvas.drawCircle(
      Offset(w * 0.68, h * 0.3),
      w * 0.14,
      _paint(colorScheme.info.withValues(alpha: 0.24)),
    );
    canvas.drawCircle(
      Offset(w * 0.68, h * 0.3),
      w * 0.07,
      _paint(colorScheme.info.withValues(alpha: 0.5)),
    );
  }

  void _paintPulse(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Path()
      ..moveTo(w * 0.08, h * 0.56)
      ..lineTo(w * 0.24, h * 0.56)
      ..lineTo(w * 0.34, h * 0.36)
      ..lineTo(w * 0.46, h * 0.7)
      ..lineTo(w * 0.58, h * 0.42)
      ..lineTo(w * 0.7, h * 0.56)
      ..lineTo(w * 0.9, h * 0.56);
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.52),
      w * 0.34,
      _paint(accent.withValues(alpha: 0.1)),
    );
    canvas.drawPath(
      line,
      _paint(accent.withValues(alpha: 0.82), style: PaintingStyle.stroke)
        ..strokeWidth = w * 0.055,
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.52),
      w * 0.17,
      _paint(colorScheme.homeCardSurface.withValues(alpha: 0.68)),
    );
  }

  void _paintTarget(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w * 0.46, size.height * 0.56);
    canvas.drawCircle(center, w * 0.3, _paint(accent.withValues(alpha: 0.12)));
    canvas.drawCircle(
      center,
      w * 0.2,
      _paint(accent.withValues(alpha: 0.28)),
    );
    canvas.drawCircle(center, w * 0.09, _paint(accent.withValues(alpha: 0.75)));
    final flag = Path()
      ..moveTo(w * 0.56, size.height * 0.18)
      ..lineTo(w * 0.56, size.height * 0.48)
      ..moveTo(w * 0.56, size.height * 0.2)
      ..quadraticBezierTo(
          w * 0.76, size.height * 0.18, w * 0.78, size.height * 0.34)
      ..quadraticBezierTo(
          w * 0.66, size.height * 0.3, w * 0.56, size.height * 0.36);
    canvas.drawPath(
      flag,
      _paint(colorScheme.foreground.withValues(alpha: 0.32),
          style: PaintingStyle.stroke)
        ..strokeWidth = w * 0.035,
    );
  }

  void _paintReceipt(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final receipt = Path()
      ..moveTo(w * 0.24, h * 0.14)
      ..lineTo(w * 0.76, h * 0.14)
      ..lineTo(w * 0.76, h * 0.78)
      ..lineTo(w * 0.66, h * 0.72)
      ..lineTo(w * 0.56, h * 0.78)
      ..lineTo(w * 0.46, h * 0.72)
      ..lineTo(w * 0.36, h * 0.78)
      ..lineTo(w * 0.24, h * 0.72)
      ..close();
    canvas.drawPath(receipt, _paint(accent.withValues(alpha: 0.15)));
    for (var i = 0; i < 4; i++) {
      final y = h * (0.3 + i * 0.12);
      canvas.drawLine(
        Offset(w * 0.36, y),
        Offset(w * (i == 1 ? 0.62 : 0.66), y),
        _paint(colorScheme.mutedForeground.withValues(alpha: 0.28),
            style: PaintingStyle.stroke)
          ..strokeWidth = w * 0.035,
      );
    }
    canvas.drawCircle(
      Offset(w * 0.66, h * 0.22),
      w * 0.065,
      _paint(accent.withValues(alpha: 0.55)),
    );
  }

  void _paintMagnifier(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.42, h * 0.42);
    canvas.drawCircle(center, w * 0.22, _paint(accent.withValues(alpha: 0.14)));
    canvas.drawCircle(
      center,
      w * 0.2,
      _paint(accent.withValues(alpha: 0.62), style: PaintingStyle.stroke)
        ..strokeWidth = w * 0.045,
    );
    canvas.drawLine(
      Offset(w * 0.57, h * 0.58),
      Offset(w * 0.78, h * 0.8),
      _paint(colorScheme.foreground.withValues(alpha: 0.36),
          style: PaintingStyle.stroke)
        ..strokeWidth = w * 0.055,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.3, h * 0.44)
        ..quadraticBezierTo(w * 0.4, h * 0.32, w * 0.52, h * 0.44),
      _paint(colorScheme.homeCardSurface.withValues(alpha: 0.82),
          style: PaintingStyle.stroke)
        ..strokeWidth = w * 0.035,
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.kind,
    required this.label,
    required this.value,
    required this.status,
    required this.accent,
  });

  final _ReportIllustrationKind kind;
  final String label;
  final String value;
  final String status;
  final Color accent;
}

enum _ReportIllustrationKind {
  wallet,
  calendar,
  coins,
  pulse,
  target,
  receipt,
  magnifier,
}

String _illustrationLabel(_ReportIllustrationKind kind) {
  switch (kind) {
    case _ReportIllustrationKind.wallet:
      return 'Wallet illustration';
    case _ReportIllustrationKind.calendar:
      return 'Calendar illustration';
    case _ReportIllustrationKind.coins:
      return 'Coin stack illustration';
    case _ReportIllustrationKind.pulse:
      return 'Financial health pulse illustration';
    case _ReportIllustrationKind.target:
      return 'Goal target illustration';
    case _ReportIllustrationKind.receipt:
      return 'Receipt illustration';
    case _ReportIllustrationKind.magnifier:
      return 'Spending pattern illustration';
  }
}
