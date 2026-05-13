import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/insights/domain/monthly_financial_report.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';
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
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
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
                _buildPageHeader(context, colorScheme, report),
                const SizedBox(height: 16),
                _buildOverallHealthStatus(context, colorScheme, report),
                const SizedBox(height: 16),
                _buildTopSummaryCards(context, colorScheme, report),
                const SizedBox(height: 16),
                _buildSafeToSpend(context, colorScheme, report),
                const SizedBox(height: 16),
                _buildBudgetHealthRows(context, colorScheme, report),
                const SizedBox(height: 16),
                _buildSpendingPaceTracking(context, colorScheme, report),
                const SizedBox(height: 16),
                _buildAnomalies(context, colorScheme, report),
                const SizedBox(height: 16),
                _buildSubscriptions(context, colorScheme, report),
                const SizedBox(height: 16),
                _buildBillCalendar(context, colorScheme, report),
                const SizedBox(height: 16),
                _buildCashFlowForecast(context, colorScheme, report),
                const SizedBox(height: 36),
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
    MonthlyFinancialReport report,
  ) {
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
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colorScheme.mutedForeground,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Monthly Financial Health Report',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
              height: 1.05,
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
      padding: const EdgeInsets.all(22),
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
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.foreground,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      report.summary,
                      style: TextStyle(
                        fontSize: 14,
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
                size: 78,
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

  Widget _buildSummaryCard(ColorScheme colorScheme, _SummaryItem item) {
    return _ReportCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _StandaloneIllustration(
                kind: item.kind,
                colorScheme: colorScheme,
                accent: item.accent,
                size: 64,
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
                  fontSize: 22,
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
      padding: const EdgeInsets.all(22),
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
                        fontSize: 14,
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
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.foreground,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'for the next ${report.safeToSpend.daysRemaining} days after bills, goals, and remaining budgets.',
                      style: TextStyle(
                        fontSize: 14,
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
                size: 86,
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
      padding: const EdgeInsets.all(20),
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
                          fontSize: 16,
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
      padding: const EdgeInsets.all(20),
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
      padding: const EdgeInsets.all(20),
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
                padding: const EdgeInsets.only(bottom: 12),
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
      padding: const EdgeInsets.all(20),
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
                    padding: const EdgeInsets.only(bottom: 12),
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
      padding: const EdgeInsets.all(20),
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
                  padding: const EdgeInsets.only(bottom: 12),
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
                              fontSize: 15,
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
                            fontSize: 15,
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
      padding: const EdgeInsets.all(20),
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

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      key: const ValueKey('monthly_report_loading'),
      child: SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(
          color: colorScheme.primary,
          strokeWidth: 3,
        ),
      ),
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
                  fontSize: 13,
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
                        fontSize: 14,
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
