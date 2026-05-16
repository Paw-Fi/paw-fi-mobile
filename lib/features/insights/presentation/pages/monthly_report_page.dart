import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/insights/domain/monthly_financial_report.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/shared/widgets/transaction_details_sheet_router.dart';

part '../widgets/monthly_report/monthly_report_metric_card.dart';
part '../widgets/monthly_report/monthly_report_health_ring.dart';
part '../widgets/monthly_report/monthly_report_detail_widgets.dart';

const _monthlyReportPageTitleFontSize = 28.0;
const _monthlyReportSectionTitleFontSize = 20.0;
const _monthlyReportPageHorizontalPadding = 20.0;
const _monthlyReportWidgetPadding = EdgeInsets.all(24);
const _monthlyReportRowPadding = EdgeInsets.symmetric(
  horizontal: 24,
  vertical: 14,
);
const _monthlyReportBalanceRoute = '/insights/monthly-report/balance';
const _monthlyReportSafeSpendRoute = '/insights/monthly-report/safe-spend';
const _monthlyReportSpendingRoute = '/insights/monthly-report/spending';
const _monthlyReportBudgetRoute = '/insights/monthly-report/budget';
const _monthlyReportSavingsRoute = '/insights/monthly-report/savings';
const _monthlyReportCategoriesRoute = '/insights/monthly-report/categories';
const _monthlyReportRecurringRoute = '/insights/monthly-report/recurring';
const _monthlyReportDrillDownRoute = '/insights/monthly-report/drilldown';

enum MonthlyReportDetailKind {
  balance,
  safeSpend,
  spending,
  budget,
  savings,
  categories,
  recurring,
}

MonthlyReportQuery _defaultMonthlyReportQuery() {
  final now = DateTime.now();
  return MonthlyReportQuery(monthStart: DateTime(now.year, now.month));
}

MonthlyReportQuery monthlyReportQueryFromUri(Uri uri) {
  final query = uri.queryParameters;
  return MonthlyReportQuery(
    monthStart: _parseMonthlyReportMonth(query['month']) ??
        _defaultMonthlyReportQuery().monthStart,
    range: MonthlyReportRange.fromKey(query['range']),
  ).normalized();
}

DateTime? _parseMonthlyReportMonth(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parts = value.split('-');
  if (parts.length < 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month);
}

String _monthlyReportRoute(
  String path,
  MonthlyReportQuery query, {
  Map<String, String> extra = const <String, String>{},
}) {
  final parsedPath = Uri.parse(path);
  return Uri(
    path: parsedPath.path,
    queryParameters: {
      ...parsedPath.queryParameters,
      'month': query.monthKey,
      'range': query.range.key,
      ...extra,
    },
  ).toString();
}

String _monthlyReportDrillDownRouteFor({
  required MonthlyReportQuery query,
  required String title,
  required Iterable<String> sourceTransactionIds,
  String? subtitle,
  String? recurringId,
  String? goalId,
}) {
  return _monthlyReportRoute(
    _monthlyReportDrillDownRoute,
    query,
    extra: {
      'title': title,
      if (subtitle != null && subtitle.trim().isNotEmpty) 'subtitle': subtitle,
      'ids': sourceTransactionIds.join(','),
      if (recurringId != null && recurringId.trim().isNotEmpty)
        'recurringId': recurringId,
      if (goalId != null && goalId.trim().isNotEmpty) 'goalId': goalId,
    },
  );
}

class MonthlyReportPage extends HookConsumerWidget {
  const MonthlyReportPage({
    super.key,
    this.initialQuery,
  });

  final MonthlyReportQuery? initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final initialMonthStart =
        initialQuery?.monthStart ?? _defaultMonthlyReportQuery().monthStart;
    final query =
        MonthlyReportQuery(monthStart: initialMonthStart).normalized();
    final reportProvider = monthlyFinancialReportProvider(query);
    final reportAsync = ref.watch(reportProvider);
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
            ? _buildReportContent(
                context,
                ref,
                colorScheme,
                snapshot,
                query,
              )
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
    MonthlyReportQuery query,
  ) {
    final report = snapshot.report;
    final month = MaterialLocalizations.of(context).formatMonthYear(
      report.monthStart,
    );

    return RefreshIndicator(
      onRefresh: () => ref
          .read(monthlyFinancialReportProvider(query).notifier)
          .refreshReport(),
      color: colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          _monthlyReportPageHorizontalPadding,
          20,
          _monthlyReportPageHorizontalPadding,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MonthlyReportPageTitle(
                  title: month,
                  colorScheme: colorScheme,
                  trailing: _MonthlyReportSyncStatus(
                    colorScheme: colorScheme,
                    lastSyncedAt: snapshot.lastSyncedAt,
                    isRefreshing: snapshot.isRefreshing,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBalanceSummaryCard(context, colorScheme, report, query),
                const SizedBox(height: 12),
                _buildSummaryMetricGrid(context, colorScheme, report, query),
                const SizedBox(height: 16),
                _MonthlyReportSectionTitle(
                  title: context.l10n.highlights,
                  actionLabel: "",
                  onActionTap: () => context.push(
                    _monthlyReportRoute(_monthlyReportSpendingRoute, query),
                  ),
                  colorScheme: colorScheme,
                ),
                _buildHighlights(context, colorScheme, report, query),
                const SizedBox(height: 15),
                _MonthlyReportSectionTitle(
                  title: context.l10n.categories,
                  actionLabel: "",
                  onActionTap: () => context.push(
                    _monthlyReportRoute(_monthlyReportCategoriesRoute, query),
                  ),
                  colorScheme: colorScheme,
                ),
                _buildCategoryPreview(context, colorScheme, report, query),
                const SizedBox(height: 16),
                _MonthlyReportSectionTitle(
                  title: context.l10n.upcomingBills,
                  actionLabel: "",
                  onActionTap: () => context.push(
                    _monthlyReportRoute(_monthlyReportRecurringRoute, query),
                  ),
                  colorScheme: colorScheme,
                ),
                _buildUpcomingPreview(context, colorScheme, report, query),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSummaryCard(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final rings = _buildHealthRingMetrics(context, colorScheme, report);
    final score = _overallHealthScore(rings);
    final netWorth = report.netWorthTrend;
    final caption = netWorth == null
        ? '${context.l10n.forecast} ${formatCurrency(report.overview.forecastedBalance, report.currencyCode)}'
        : '${_formatSignedCurrency(netWorth.change, report.currencyCode)} ${context.l10n.fromLastSnapshot}';

    return _MonthlyReportHeroCard(
      colorScheme: colorScheme,
      label: context.l10n.financialHealth,
      title: _shortHealthHeadline(context, report.overview.status),
      value: formatCurrency(
        report.overview.currentBalance,
        report.currencyCode,
      ),
      caption: caption,
      accent: _statusColor(report.overview.status, colorScheme),
      onTap: () => context.push(
        _monthlyReportRoute(_monthlyReportBalanceRoute, query),
      ),
      visual: _MonthlyReportHealthRing(
        colorScheme: colorScheme,
        metrics: rings,
        score: score,
        status: _localizedStatusLabel(context, report.overview.status),
        size: 150,
      ),
    );
  }

  Widget _buildSummaryMetricGrid(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final budgetProgress = _budgetUsedProgress(report);
    final spendingCaption = report.trendSummary.spendingChange == 0
        ? _paceStatus(context, report)
        : context.l10n.vsLastMonth(_formatSignedCurrency(
            report.trendSummary.spendingChange, report.currencyCode));

    final items = [
      _MonthlyMetricSpec(
        label: context.l10n.safeToSpend,
        value: context.l10n.perDay(formatCurrency(
            report.safeToSpend.dailyAmount, report.currencyCode)),
        caption: context.l10n.daysLeft(report.safeToSpend.daysRemaining),
        accent: colorScheme.success,
        icon: Icons.wallet_rounded,
        route: _monthlyReportSafeSpendRoute,
        visual: _MonthlyReportMiniBarChart(
          colorScheme: colorScheme,
          values: [
            report.safeToSpend.futureIncome,
            report.safeToSpend.budgetRemaining,
            report.overview.forecastedBalance,
            report.safeToSpend.dailyAmount * report.safeToSpend.daysRemaining,
          ],
          accent: colorScheme.success,
        ),
      ),
      _MonthlyMetricSpec(
        label: context.l10n.spending,
        value: formatCurrency(report.overview.spending, report.currencyCode),
        caption: spendingCaption,
        accent: _statusColor(report.overview.status, colorScheme),
        icon: Icons.show_chart_rounded,
        route: _monthlyReportSpendingRoute,
        visual: _MonthlyReportMiniBarChart(
          colorScheme: colorScheme,
          values: [
            report.trendSummary.previousSpending,
            report.trendSummary.currentSpending,
          ],
          accent: _statusColor(report.overview.status, colorScheme),
        ),
      ),
      _MonthlyMetricSpec(
        label: context.l10n.budget,
        value: _formatPercent(budgetProgress),
        caption:
            '${formatCurrency(report.budgetPlan.totalRemaining, report.currencyCode)} ${context.l10n.remaining}',
        accent: budgetProgress >= 1 ? colorScheme.warning : colorScheme.info,
        icon: Icons.track_changes_rounded,
        route: _monthlyReportBudgetRoute,
        visual: _MonthlyReportProgressRing(
          colorScheme: colorScheme,
          progress: budgetProgress,
          center: '${(budgetProgress * 100).round()}%',
          accent: budgetProgress >= 1 ? colorScheme.warning : colorScheme.info,
          size: 58,
        ),
      ),
      _MonthlyMetricSpec(
        label: context.l10n.savings,
        value: formatCurrency(report.overview.savings, report.currencyCode),
        caption: _formatPercent(report.trendSummary.savingsRate),
        accent: report.overview.savings >= 0
            ? colorScheme.success
            : colorScheme.destructive,
        icon: Icons.savings_rounded,
        route: _monthlyReportSavingsRoute,
        visual: _MonthlyReportMiniBarChart(
          colorScheme: colorScheme,
          values: [
            report.trendSummary.netCashFlow,
            report.overview.savings,
            report.overview.forecastedBalance,
          ],
          accent: report.overview.savings >= 0
              ? colorScheme.success
              : colorScheme.destructive,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
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
                child: _MonthlyReportMetricCard(
                  colorScheme: colorScheme,
                  spec: item,
                  onTap: () => context.push(
                    _monthlyReportRoute(item.route, query),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHighlights(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final highlights =
        _buildHighlightItems(context, colorScheme, report).take(3).toList();

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Column(
        children: [
          for (final item in highlights) ...[
            _MonthlyReportInsightCard(
              colorScheme: colorScheme,
              title: item.title,
              label: item.label,
              accent: _statusColor(item.status, colorScheme),
              icon: item.icon,
              onTap: () => context.push(_monthlyReportRoute(item.route, query)),
              chart: item.chart,
            ),
            if (item != highlights.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryPreview(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final categories = report.categoryTrends.take(3).toList(growable: false);

    if (categories.isEmpty) {
      return _MonthlyReportInsightCard(
        colorScheme: colorScheme,
        title: context.l10n.categories,
        label: context.l10n.comparableSpendingWillAppearHere,
        accent: colorScheme.info,
        icon: Icons.category_rounded,
        onTap: () => context.push(
          _monthlyReportRoute(_monthlyReportCategoriesRoute, query),
        ),
      );
    }

    final maxSpent = categories.fold<double>(
      1,
      (maxValue, item) => math.max(maxValue, item.currentSpent),
    );

    return _MonthlyReportPreviewCard(
      colorScheme: colorScheme,
      children: [
        for (final item in categories)
          _MonthlyReportDisclosureRow(
            colorScheme: colorScheme,
            title: getCategoryTranslation(context, item.name),
            subtitle: _shortCategoryInsight(context, item),
            value: formatCurrency(item.currentSpent, report.currencyCode),
            accent: _statusColor(item.status, colorScheme),
            icon: Icons.category_rounded,
            onTap: () => context.push(
              _monthlyReportRoute(
                _monthlyReportCategoriesRoute,
                query,
                extra: {'name': item.name},
              ),
            ),
            visual: _MonthlyReportProgressBar(
              colorScheme: colorScheme,
              progress: item.currentSpent / maxSpent,
              accent: _statusColor(item.status, colorScheme),
              compact: true,
            ),
          ),
      ],
    );
  }

  Widget _buildUpcomingPreview(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final upcoming = report.upcomingObligations.take(3).toList(growable: false);
    final subscriptions =
        report.subscriptions.items.take(math.max(0, 3 - upcoming.length));

    final rows = <Widget>[
      for (final item in upcoming)
        _MonthlyReportDisclosureRow(
          colorScheme: colorScheme,
          title: item.name,
          subtitle: _formatShortDate(context, item.date),
          value: item.type == 'income'
              ? '+${formatCurrency(item.amount, report.currencyCode)}'
              : formatCurrency(-item.amount, report.currencyCode),
          accent:
              item.type == 'income' ? colorScheme.success : colorScheme.warning,
          icon: item.type == 'income'
              ? Icons.arrow_downward_rounded
              : Icons.event_note_rounded,
          onTap: () => context.push(_monthlyReportDrillDownRouteFor(
            query: query,
            title: item.name,
            subtitle: _formatShortDate(context, item.date),
            sourceTransactionIds: [
              if (item.sourceTransactionId != null) item.sourceTransactionId!,
            ],
            recurringId: item.recurringId,
          )),
        ),
      for (final item in subscriptions)
        item.recurringId == null || item.recurringId!.trim().isEmpty
            ? _MonthlyReportStaticRow(
                colorScheme: colorScheme,
                title: item.name,
                value: formatCurrency(item.amount, report.currencyCode),
                subtitle: _formatShortDate(context, item.nextDate),
                accent: _subscriptionColor(item.status, colorScheme),
              )
            : _MonthlyReportDisclosureRow(
                colorScheme: colorScheme,
                title: item.name,
                subtitle: _formatShortDate(context, item.nextDate),
                value: formatCurrency(item.amount, report.currencyCode),
                accent: _subscriptionColor(item.status, colorScheme),
                icon: Icons.receipt_long_rounded,
                onTap: () => context.push(_monthlyReportDrillDownRouteFor(
                  query: query,
                  title: item.name,
                  subtitle: _formatShortDate(context, item.nextDate),
                  sourceTransactionIds: const <String>[],
                  recurringId: item.recurringId,
                )),
              ),
    ];

    if (rows.isEmpty) {
      return _MonthlyReportInsightCard(
        colorScheme: colorScheme,
        title: context.l10n.noUpcomingBills,
        label: context.l10n.recurringExpensesWillAppearHere,
        accent: colorScheme.success,
        icon: Icons.event_available_rounded,
        onTap: () => context.push(
          _monthlyReportRoute(_monthlyReportRecurringRoute, query),
        ),
      );
    }

    return _MonthlyReportPreviewCard(
      colorScheme: colorScheme,
      children: rows,
    );
  }

  List<_MonthlyHighlightItem> _buildHighlightItems(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
  ) {
    final items = <_MonthlyHighlightItem>[];

    if (report.anomalies.isNotEmpty) {
      for (final anomaly in report.anomalies.take(2)) {
        items.add(
          _MonthlyHighlightItem(
            title: _localizedAnomalyTitle(context, anomaly),
            label: _shortInsightCopy(
              _localizedAnomalyDescription(context, anomaly),
            ),
            status: anomaly.status,
            icon: Icons.manage_search_rounded,
            route: _monthlyReportSpendingRoute,
          ),
        );
      }
    }

    if (report.categoryTrends.isNotEmpty) {
      final mover = report.categoryTrends.first;
      items.add(
        _MonthlyHighlightItem(
          title: context.l10n.categoryMovement,
          label: _shortCategoryInsight(context, mover),
          status: mover.status,
          icon: Icons.category_rounded,
          route:
              '$_monthlyReportCategoriesRoute?name=${Uri.encodeComponent(mover.name)}',
          chart: _MonthlyReportMiniBarChart(
            colorScheme: colorScheme,
            values: [mover.previousSpent, mover.currentSpent],
            accent: _statusColor(mover.status, colorScheme),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        _MonthlyHighlightItem(
          title: _shortHealthHeadline(context, report.overview.status),
          label: _paceStatus(context, report),
          status: report.overview.status,
          icon: Icons.favorite_rounded,
          route: _monthlyReportBalanceRoute,
          chart: _MonthlyReportSparkline(
            colorScheme: colorScheme,
            values: report.cashFlowForecast
                .map((point) => point.balance)
                .toList(growable: false),
            accent: _statusColor(report.overview.status, colorScheme),
          ),
        ),
      );
    }

    return items;
  }

  String _shortHealthHeadline(
    BuildContext context,
    MonthlyReportStatus status,
  ) {
    switch (status) {
      case MonthlyReportStatus.onTrack:
      case MonthlyReportStatus.safeToSpend:
        return context.l10n.onTrack;
      case MonthlyReportStatus.spendingFast:
        return context.l10n.spendingIsMovingFast;
      case MonthlyReportStatus.needsAttention:
        return context.l10n.aSmallAdjustmentHelps;
      case MonthlyReportStatus.overBudget:
        return context.l10n.budgetsNeedAttention;
      case MonthlyReportStatus.unusualSpending:
        return context.l10n.patternsChanged;
    }
  }

  String _shortInsightCopy(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 72) return trimmed;
    final boundary = trimmed.lastIndexOf(' ', 72);
    final end = boundary < 40 ? 72 : boundary;
    return '${trimmed.substring(0, end)}...';
  }

  String _shortCategoryInsight(
      BuildContext context, MonthlyCategoryTrendItem item) {
    final change = item.previousChangePercent ?? item.baselineChangePercent;
    if (change == null) return _localizedCategoryTrendInsight(context, item);
    final direction = change >= 0 ? context.l10n.higher : context.l10n.lower;
    return context.l10n.categoryIsPercentDirection(
        getCategoryTranslation(context, item.name),
        _formatPercent(change.abs()),
        direction);
  }

  double _budgetUsedProgress(MonthlyFinancialReport report) {
    final totalBudgeted = report.budgetPlan.totalBudgeted;
    if (totalBudgeted <= 0) {
      return report.overview.spending <= 0 ? 0 : 1;
    }
    return (report.budgetPlan.totalSpent / totalBudgeted).clamp(0.0, 1.4);
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

  String _formatSignedCurrency(double value, String currencyCode) {
    if (value == 0) return formatCurrency(0, currencyCode);
    final sign = value > 0 ? '+' : '';
    return '$sign${formatCurrency(value, currencyCode)}';
  }

  String _paceStatus(BuildContext context, MonthlyFinancialReport report) {
    if (report.spendingPace.isEmpty) return context.l10n.noBudgetsYet;
    final fastCount = report.spendingPace
        .where(
          (item) =>
              item.status == MonthlyReportStatus.spendingFast ||
              item.status == MonthlyReportStatus.overBudget ||
              item.status == MonthlyReportStatus.needsAttention,
        )
        .length;
    if (fastCount == 0) return context.l10n.onExpectedPace;
    if (fastCount == 1) return context.l10n.oneBudgetToWatch;
    return '$fastCount ${context.l10n.budgetsToWatch}';
  }

  List<_HealthRingMetric> _buildHealthRingMetrics(
    BuildContext context,
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
        label: context.l10n.safeSpend,
        value: context.l10n.perDay(formatCurrency(
            report.safeToSpend.dailyAmount, report.currencyCode)),
        status: report.safeToSpend.dailyAmount > 0
            ? context.l10n.availableToday
            : context.l10n.holdSpending,
        progress: _safeToSpendProgress(report),
        color: vibrantPalette[0],
        icon: Icons.wallet_rounded,
      ),
      _HealthRingMetric(
        label: context.l10n.budgetPace,
        value: '${(budgetPaceProgress * 100).round()}%',
        status: _paceStatus(context, report),
        progress: budgetPaceProgress,
        color: vibrantPalette[1],
        icon: Icons.speed_rounded,
      ),
      _HealthRingMetric(
        label: context.l10n.billsCovered,
        value: context.l10n.scheduledCount(report.upcomingObligations.length),
        status: billsCoveredProgress >= 1
            ? context.l10n.coveredAhead
            : context.l10n.needsCashFlow,
        progress: billsCoveredProgress,
        color: vibrantPalette[2],
        icon: Icons.event_note_rounded,
      ),
      _HealthRingMetric(
        label: context.l10n.monthEndBuffer,
        value: formatCurrency(
          report.overview.forecastedBalance,
          report.currencyCode,
        ),
        status: forecastIsPositive
            ? context.l10n.positiveForecast
            : context.l10n.negativeForecast,
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
        padding: const EdgeInsets.all(20),
        child: _ReportCard(
          colorScheme: colorScheme,
          child: Text(
            context.l10n.couldNotLoadReport('$error'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.destructive,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

String _localizedPaceInsight(
  BuildContext context,
  MonthlySpendingPaceItem item,
) {
  final name = getCategoryTranslation(context, item.label);
  final spentPct = (item.spentProgress * 100).round();
  final timePct = (item.timeProgress * 100).round();
  switch (item.status) {
    case MonthlyReportStatus.overBudget:
      return context.l10n.budgetPaceOverBudget(name);
    case MonthlyReportStatus.spendingFast:
      return context.l10n.budgetPaceSpendingFast(name, spentPct, timePct);
    case MonthlyReportStatus.needsAttention:
      return context.l10n.budgetPaceNeedsAttention(name);
    default:
      return context.l10n.budgetPaceOnTrack(name);
  }
}

String _localizedCategoryTrendInsight(
  BuildContext context,
  MonthlyCategoryTrendItem item,
) {
  final useBaseline = (item.baselineChangePercent?.abs() ?? 0) >
      (item.previousChangePercent?.abs() ?? 0);
  final percent =
      useBaseline ? item.baselineChangePercent : item.previousChangePercent;
  final change = useBaseline ? item.baselineChange : item.previousChange;
  final comparator = useBaseline
      ? context.l10n.recentAverage
      : context.l10n.samePointLastMonth;
  final direction =
      (percent ?? change) >= 0 ? context.l10n.higher : context.l10n.lower;
  final category = getCategoryTranslation(context, item.name);
  if (percent == null) {
    return context.l10n.categoryChangeThanComparator(
      category,
      change.abs().toStringAsFixed(2),
      comparator,
      direction,
    );
  }
  return context.l10n.categoryPercentChangeThanComparator(
    category,
    comparator,
    direction,
    (percent.abs() * 100).round(),
  );
}

String _localizedAnomalyTitle(BuildContext context, MonthlyInsightItem item) {
  final categoryName = item.categoryName;
  if (categoryName == null || categoryName.trim().isEmpty) return item.title;
  return getCategoryTranslation(context, categoryName);
}

String _localizedAnomalyDescription(
  BuildContext context,
  MonthlyInsightItem item,
) {
  final categoryName = item.categoryName;
  final increasePercent = item.increasePercent;
  if (categoryName == null ||
      categoryName.trim().isEmpty ||
      increasePercent == null) {
    return item.description;
  }
  return context.l10n.categoryPercentChangeThanComparator(
    getCategoryTranslation(context, categoryName),
    context.l10n.lastMonth,
    context.l10n.higher,
    increasePercent,
  );
}

class MonthlyReportDetailPage extends HookConsumerWidget {
  const MonthlyReportDetailPage({
    super.key,
    required this.kind,
    this.query,
    this.selectedCategoryName,
  });

  final MonthlyReportDetailKind kind;
  final MonthlyReportQuery? query;
  final String? selectedCategoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveQuery = (query ?? _defaultMonthlyReportQuery()).normalized();
    final reportAsync =
        ref.watch(monthlyFinancialReportProvider(effectiveQuery));
    final snapshot = reportAsync.valueOrNull;

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: snapshot == null
              ? reportAsync.hasError
                  ? _MonthlyReportDetailShell(
                      colorScheme: colorScheme,
                      title: _detailTitle(context, kind),
                      child: _ReportCard(
                        colorScheme: colorScheme,
                        child: Text(
                          context.l10n
                              .couldNotLoadReport('${reportAsync.error}'),
                          style: TextStyle(
                            color: colorScheme.destructive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : _MonthlyReportDetailShell(
                      colorScheme: colorScheme,
                      title: _detailTitle(context, kind),
                      child: _ReportCard(
                        colorScheme: colorScheme,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    )
              : _MonthlyReportDetailShell(
                  colorScheme: colorScheme,
                  title: _detailTitle(context, kind),
                  child: _buildDetailContent(
                    context,
                    colorScheme,
                    snapshot.report,
                    effectiveQuery,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDetailContent(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    switch (kind) {
      case MonthlyReportDetailKind.balance:
        return _buildBalanceDetail(context, colorScheme, report, query);
      case MonthlyReportDetailKind.safeSpend:
        return _buildSafeSpendDetail(context, colorScheme, report, query);
      case MonthlyReportDetailKind.spending:
        return _buildSpendingDetail(
          context,
          colorScheme,
          report,
          query,
        );
      case MonthlyReportDetailKind.budget:
        return _buildBudgetDetail(context, colorScheme, report, query);
      case MonthlyReportDetailKind.savings:
        return _buildSavingsDetail(context, colorScheme, report, query);
      case MonthlyReportDetailKind.categories:
        return _buildCategoryDetail(context, colorScheme, report, query);
      case MonthlyReportDetailKind.recurring:
        return _buildRecurringDetail(context, colorScheme, report, query);
    }
  }

  Widget _buildBalanceDetail(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final rings = _buildDetailHealthRingMetrics(context, colorScheme, report);
    final score = _overallHealthScore(rings);
    final statusColor = _detailStatusColor(report.overview.status, colorScheme);
    final watchFirst = [...rings]
      ..sort((a, b) => a.progress.compareTo(b.progress));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyReportDetailHeader(
          colorScheme: colorScheme,
          status: context.l10n.financialHealth,
          title: _detailHealthHeadline(context, report.overview.status),
          value: '$score',
          caption: _localizedStatusLabel(context, report.overview.status),
          accent: statusColor,
          visual: _MonthlyReportHealthRing(
            colorScheme: colorScheme,
            metrics: rings,
            score: score,
            status: _localizedStatusLabel(context, report.overview.status),
            size: 184,
          ),
        ),
        const SizedBox(height: 12),
        _MonthlyReportHealthRingLegend(
          colorScheme: colorScheme,
          metrics: rings,
        ),
        const SizedBox(height: 12),
        _MonthlyReportAdviceCard(
          colorScheme: colorScheme,
          label: context.l10n.monthlyHealth,
          title: _detailHealthHeadline(context, report.overview.status),
          body: report.summary,
          accent: statusColor,
          icon: Icons.favorite_rounded,
        ),
        const SizedBox(height: 12),
        _MonthlyReportSectionTitle(
          title: context.l10n.monthVsLastMonth,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.incomeChange,
              value: _detailSignedCurrency(
                report.trendSummary.incomeChange,
                report.currencyCode,
              ),
              accent: report.trendSummary.incomeChange >= 0
                  ? colorScheme.success
                  : colorScheme.warning,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.spendingChange,
              value: _detailSignedCurrency(
                report.trendSummary.spendingChange,
                report.currencyCode,
              ),
              accent: report.trendSummary.spendingChange <= 0
                  ? colorScheme.success
                  : colorScheme.warning,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.savingsRate,
              value: _detailPercent(report.trendSummary.savingsRate),
              accent: report.trendSummary.savingsRate >= 0
                  ? colorScheme.success
                  : colorScheme.destructive,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.netCashFlow,
              value: _detailSignedCurrency(
                report.trendSummary.netCashFlow,
                report.currencyCode,
              ),
              accent: report.trendSummary.netCashFlow >= 0
                  ? colorScheme.success
                  : colorScheme.destructive,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MonthlyReportSectionTitle(
          title: context.l10n.watchFirst,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            for (final metric in watchFirst.take(3))
              _MonthlyReportStaticRow(
                colorScheme: colorScheme,
                title: metric.label,
                value: metric.value,
                subtitle: metric.status,
                accent: metric.color,
                visual: _MonthlyReportProgressBar(
                  colorScheme: colorScheme,
                  progress: metric.progress.clamp(0.0, 1.0),
                  accent: metric.color,
                  compact: true,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _MonthlyReportSectionTitle(
          title: context.l10n.cashFlow,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.currentBalance,
              value: formatCurrency(
                report.overview.currentBalance,
                report.currencyCode,
              ),
              subtitle: context.l10n.forecastAmount(
                formatCurrency(
                  report.overview.forecastedBalance,
                  report.currencyCode,
                ),
              ),
              accent: statusColor,
              visual: _MonthlyReportSparkline(
                colorScheme: colorScheme,
                values: report.cashFlowForecast
                    .map((point) => point.balance)
                    .toList(growable: false),
                accent: statusColor,
                height: 44,
              ),
            ),
            if (report.netWorthTrend != null)
              _MonthlyReportStaticRow(
                colorScheme: colorScheme,
                title: context.l10n.netWorth,
                value: formatCurrency(
                  report.netWorthTrend!.currentNetWorth,
                  report.currencyCode,
                ),
                subtitle: context.l10n.amountFromLastSnapshot(
                  _detailSignedCurrency(
                    report.netWorthTrend!.change,
                    report.currencyCode,
                  ),
                ),
                accent: report.netWorthTrend!.change >= 0
                    ? colorScheme.success
                    : colorScheme.warning,
              ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.lowWater,
              value: formatCurrency(
                report.cashFlowHealth.lowWaterBalance,
                report.currencyCode,
              ),
              subtitle: report.cashFlowHealth.lowWaterDate == null
                  ? context.l10n.noProjectedLowDate
                  : _detailShortDate(
                      context,
                      report.cashFlowHealth.lowWaterDate!,
                    ),
              accent: report.cashFlowHealth.lowWaterBalance < 0
                  ? colorScheme.destructive
                  : colorScheme.success,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.firstShortfall,
              value: report.cashFlowHealth.firstNegativeDate == null
                  ? context.l10n.none
                  : _detailShortDate(
                      context,
                      report.cashFlowHealth.firstNegativeDate!,
                    ),
              subtitle: report.cashFlowHealth.firstNegativeDate == null
                  ? context.l10n.billsAppearCovered
                  : context.l10n.balanceMayGoNegative,
              accent: report.cashFlowHealth.firstNegativeDate == null
                  ? colorScheme.success
                  : colorScheme.destructive,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildForecastTimeline(context, colorScheme, report, query),
        const SizedBox(height: 12),
        _MonthlyReportAboutCard(
          colorScheme: colorScheme,
          title: context.l10n.aboutFinancialHealth,
          body: context.l10n.financialHealthBody,
        ),
      ],
    );
  }

  Widget _buildSafeSpendDetail(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final progress = _detailSafeToSpendProgress(report);
    final accent = report.safeToSpend.dailyAmount > 0
        ? colorScheme.success
        : colorScheme.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyReportDetailHeader(
          colorScheme: colorScheme,
          status: context.l10n.safeToSpend,
          title: context.l10n.safeToSpend,
          value: context.l10n.perDay(formatCurrency(
              report.safeToSpend.dailyAmount, report.currencyCode)),
          caption: context.l10n.daysRemaining(report.safeToSpend.daysRemaining),
          accent: accent,
          visual: _MonthlyReportProgressRing(
            colorScheme: colorScheme,
            progress: progress,
            center: '${(progress * 100).round()}%',
            accent: accent,
            size: 104,
          ),
        ),
        const SizedBox(height: 12),
        _MonthlyReportAdviceCard(
          colorScheme: colorScheme,
          label: context.l10n.allowance,
          title: context.l10n.youCanSafelySpendPerDay(formatCurrency(
              report.safeToSpend.dailyAmount, report.currencyCode)),
          body: context.l10n
              .coversNextDaysAfterBills(report.safeToSpend.daysRemaining),
          accent: accent,
          icon: Icons.wallet_rounded,
        ),
        const SizedBox(height: 12),
        _MonthlyReportSectionTitle(
          title: context.l10n.allowance,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.budgetLeft,
              value: formatCurrency(
                report.safeToSpend.budgetRemaining,
                report.currencyCode,
              ),
              subtitle: context.l10n.availableAfterMonthToDateSpending,
              accent: report.safeToSpend.budgetRemaining >= 0
                  ? colorScheme.success
                  : colorScheme.destructive,
              visual: _MonthlyReportProgressBar(
                colorScheme: colorScheme,
                progress: progress,
                accent: accent,
                compact: true,
              ),
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.billsAhead,
              value: formatCurrency(
                report.safeToSpend.futureObligations,
                report.currencyCode,
              ),
              subtitle: context.l10n
                  .scheduledCount(report.upcomingObligations.length),
              accent: report.safeToSpend.futureObligations <=
                      report.safeToSpend.futureIncome +
                          math.max(0, report.overview.currentBalance)
                  ? colorScheme.success
                  : colorScheme.warning,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.expectedIncome,
              value: formatCurrency(
                report.safeToSpend.futureIncome,
                report.currencyCode,
              ),
              subtitle: context.l10n.beforeMonthEnd,
              accent: colorScheme.info,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildForecastTimeline(context, colorScheme, report, query),
        const SizedBox(height: 12),
        _MonthlyReportAboutCard(
          colorScheme: colorScheme,
          title: context.l10n.aboutSafeToSpend,
          body: context.l10n.safeToSpendBody,
        ),
      ],
    );
  }

  Widget _buildSpendingDetail(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final statusColor = _detailStatusColor(report.overview.status, colorScheme);
    final fastCategories = report.spendingPace
        .where(
          (item) =>
              item.status != MonthlyReportStatus.onTrack &&
              item.status != MonthlyReportStatus.safeToSpend,
        )
        .take(3)
        .toList(growable: false);
    final watchCategories = fastCategories.isEmpty
        ? report.spendingPace.take(3).toList(growable: false)
        : fastCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyReportRangeSelector(
          colorScheme: colorScheme,
          selected: query.range.key,
          onChanged: (value) {
            context.go(_monthlyReportRoute(
              _monthlyReportSpendingRoute,
              MonthlyReportQuery(
                monthStart: query.monthStart,
                range: MonthlyReportRange.fromKey(value),
              ),
            ));
          },
        ),
        const SizedBox(height: 12),
        _MonthlyReportDetailHeader(
          colorScheme: colorScheme,
          status: context.l10n.spending,
          title: context.l10n.spending,
          value: formatCurrency(report.overview.spending, report.currencyCode),
          caption: context.l10n.vsLastMonth(_detailSignedCurrency(
              report.trendSummary.spendingChange, report.currencyCode)),
          accent: statusColor,
          visual: _MonthlyReportMiniBarChart(
            colorScheme: colorScheme,
            values: [
              report.trendSummary.previousSpending,
              report.trendSummary.currentSpending,
            ],
            accent: statusColor,
            height: 74,
          ),
        ),
        const SizedBox(height: 12),
        _MonthlyReportSectionTitle(
          title: context.l10n.watchFirst,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            for (final item in watchCategories)
              _MonthlyReportDisclosureRow(
                colorScheme: colorScheme,
                title: getCategoryTranslation(context, item.label),
                value: '${(item.spentProgress * 100).round()}%',
                subtitle: _localizedStatusLabel(context, item.status),
                accent: _detailStatusColor(item.status, colorScheme),
                icon: Icons.speed_rounded,
                onTap: () => context.push(_monthlyReportDrillDownRouteFor(
                  query: query,
                  title: getCategoryTranslation(context, item.label),
                  subtitle: item.insight,
                  sourceTransactionIds: item.sourceTransactionIds,
                )),
                visual: _MonthlyReportPaceComparisonBar(
                  colorScheme: colorScheme,
                  accent: _detailStatusColor(item.status, colorScheme),
                  spentProgress: item.spentProgress.clamp(0.0, 1.0),
                  timeProgress: item.timeProgress.clamp(0.0, 1.0),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (report.anomalies.isNotEmpty) ...[
          _MonthlyReportSectionTitle(
            title: context.l10n.unusualActivity,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
          for (final item in report.anomalies.take(3)) ...[
            _MonthlyReportAdviceCard(
              colorScheme: colorScheme,
              label: context.l10n.patternCheck,
              title: _localizedAnomalyTitle(context, item),
              body: _localizedAnomalyDescription(context, item),
              accent: _detailStatusColor(item.status, colorScheme),
              icon: Icons.manage_search_rounded,
              onTap: item.sourceTransactionIds.isEmpty
                  ? null
                  : () => context.push(_monthlyReportDrillDownRouteFor(
                        query: query,
                        title: _localizedAnomalyTitle(context, item),
                        subtitle: _localizedAnomalyDescription(context, item),
                        sourceTransactionIds: item.sourceTransactionIds,
                      )),
            ),
            const SizedBox(height: 12),
          ],
        ],
        _MonthlyReportSectionTitle(
          title: context.l10n.categoryPace,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            for (final item in report.spendingPace.take(6))
              _MonthlyReportDisclosureRow(
                colorScheme: colorScheme,
                title: getCategoryTranslation(context, item.label),
                value: '${(item.spentProgress * 100).round()}%',
                subtitle: _localizedStatusLabel(context, item.status),
                accent: _detailStatusColor(item.status, colorScheme),
                icon: Icons.speed_rounded,
                onTap: () => context.push(_monthlyReportDrillDownRouteFor(
                  query: query,
                  title: getCategoryTranslation(context, item.label),
                  subtitle: item.insight,
                  sourceTransactionIds: item.sourceTransactionIds,
                )),
                visual: _MonthlyReportPaceComparisonBar(
                  colorScheme: colorScheme,
                  accent: _detailStatusColor(item.status, colorScheme),
                  spentProgress: item.spentProgress.clamp(0.0, 1.0),
                  timeProgress: item.timeProgress.clamp(0.0, 1.0),
                ),
              ),
          ],
        ),
        if (report.spendingPace.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MonthlyReportAboutCard(
            colorScheme: colorScheme,
            title: context.l10n.aboutSpendingPace,
            body: context.l10n.spendingPaceBody,
          ),
        ],
        const SizedBox(height: 12),
        _buildMerchantPreview(context, colorScheme, report, query),
      ],
    );
  }

  Widget _buildBudgetDetail(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final progress = _detailBudgetProgress(report);
    final accent = progress >= 1 ? colorScheme.warning : colorScheme.info;
    final stressedCategories = report.budgetHealth
        .where(
          (item) =>
              item.status != MonthlyReportStatus.onTrack &&
              item.status != MonthlyReportStatus.safeToSpend,
        )
        .take(3)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyReportDetailHeader(
          colorScheme: colorScheme,
          status: context.l10n.budgetUsed,
          title: context.l10n.budgetUsed,
          value: '${(progress * 100).round()}%',
          caption:
              '${formatCurrency(report.budgetPlan.totalRemaining, report.currencyCode)} ${context.l10n.remaining}',
          accent: accent,
          visual: _MonthlyReportProgressRing(
            colorScheme: colorScheme,
            progress: progress,
            center: '${(progress * 100).round()}%',
            accent: accent,
            size: 104,
          ),
        ),
        const SizedBox(height: 12),
        _MonthlyReportSectionTitle(
          title: context.l10n.budgetPlan,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            if (stressedCategories.isNotEmpty)
              _MonthlyReportStaticRow(
                colorScheme: colorScheme,
                title: context.l10n.needsAttention,
                value: '${stressedCategories.length}',
                subtitle: stressedCategories
                    .map((item) => getCategoryTranslation(context, item.name))
                    .take(2)
                    .join(', '),
                accent: colorScheme.warning,
              ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.budgeted,
              value: formatCurrency(
                report.budgetPlan.totalBudgeted,
                report.currencyCode,
              ),
              accent: colorScheme.info,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.remaining,
              value: formatCurrency(
                report.budgetPlan.totalRemaining,
                report.currencyCode,
              ),
              accent: report.budgetPlan.totalRemaining >= 0
                  ? colorScheme.success
                  : colorScheme.destructive,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.spent,
              value: formatCurrency(
                report.budgetPlan.totalSpent,
                report.currencyCode,
              ),
              accent: accent,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.unbudgeted,
              value: formatCurrency(
                report.budgetPlan.unbudgetedSpent,
                report.currencyCode,
              ),
              accent: report.budgetPlan.unbudgetedSpent > 0
                  ? colorScheme.warning
                  : colorScheme.success,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.budgetOverIncome,
              value: _detailNullablePercent(
                context,
                report.budgetPlan.budgetToIncomeRatio,
              ),
              subtitle: context.l10n.budgetRiskCount(
                report.budgetPlan.overBudgetCount,
                report.budgetPlan.atRiskCount,
              ),
              accent: report.budgetPlan.overBudgetCount > 0 ||
                      report.budgetPlan.atRiskCount > 0
                  ? colorScheme.warning
                  : colorScheme.success,
            ),
          ],
        ),
        if (stressedCategories.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MonthlyReportAdviceCard(
            colorScheme: colorScheme,
            label: context.l10n.budgetHealth,
            title: stressedCategories.length == 1
                ? context.l10n.categoryNeedsAttention(getCategoryTranslation(
                    context, stressedCategories.first.name))
                : context.l10n
                    .categoriesNeedAttention(stressedCategories.length),
            body: context.l10n.budgetHealthBody,
            accent: colorScheme.warning,
            icon: Icons.track_changes_rounded,
          ),
        ],
        const SizedBox(height: 12),
        _MonthlyReportSectionTitle(
          title: context.l10n.categories,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            for (final item in report.budgetHealth.take(8))
              _MonthlyReportDisclosureRow(
                colorScheme: colorScheme,
                title: getCategoryTranslation(context, item.name),
                value: formatCurrency(item.remaining, report.currencyCode),
                subtitle: _detailBudgetSubtitle(context, report, item),
                accent: _detailStatusColor(item.status, colorScheme),
                icon: Icons.track_changes_rounded,
                onTap: () => context.push(_monthlyReportDrillDownRouteFor(
                  query: query,
                  title: getCategoryTranslation(context, item.name),
                  subtitle: _detailBudgetSubtitle(context, report, item),
                  sourceTransactionIds: item.sourceTransactionIds,
                )),
                visual: _detailBudgetPaceVisual(colorScheme, report, item),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _MonthlyReportSectionTitle(
          title: context.l10n.budgetNotes,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        for (final item in report.spendingPace.take(3)) ...[
          _MonthlyReportAdviceCard(
            colorScheme: colorScheme,
            label: _localizedStatusLabel(context, item.status),
            title: getCategoryTranslation(context, item.label),
            body: _localizedPaceInsight(context, item),
            accent: _detailStatusColor(item.status, colorScheme),
            icon: Icons.speed_rounded,
            onTap: item.sourceTransactionIds.isEmpty
                ? null
                : () => context.push(_monthlyReportDrillDownRouteFor(
                      query: query,
                      title: getCategoryTranslation(context, item.label),
                      subtitle: _localizedPaceInsight(context, item),
                      sourceTransactionIds: item.sourceTransactionIds,
                    )),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        _MonthlyReportAboutCard(
          colorScheme: colorScheme,
          title: context.l10n.aboutBudgetHealth,
          body: context.l10n.budgetHealthNotesBody,
        ),
      ],
    );
  }

  Widget _buildSavingsDetail(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final goalProgress = report.goals.isEmpty
        ? _detailSavingsRateProgress(report)
        : report.goals.first.progress.clamp(0.0, 1.0);
    final accent = report.overview.savings >= 0
        ? colorScheme.success
        : colorScheme.destructive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyReportDetailHeader(
          colorScheme: colorScheme,
          status: context.l10n.savings,
          title: context.l10n.savings,
          value: formatCurrency(report.overview.savings, report.currencyCode),
          caption: context.l10n.savingsRatePercent(
              _detailPercent(report.trendSummary.savingsRate)),
          accent: accent,
          visual: _MonthlyReportProgressRing(
            colorScheme: colorScheme,
            progress: goalProgress,
            center: '${(goalProgress * 100).round()}%',
            accent: accent,
            size: 104,
          ),
        ),
        const SizedBox(height: 12),
        _MonthlyReportAdviceCard(
          colorScheme: colorScheme,
          label: context.l10n.savings,
          title: report.overview.savings >= 0
              ? context.l10n.savedMoneyThisMonth
              : context.l10n.usingYourBufferThisMonth,
          body: report.overview.savings >= 0
              ? context.l10n
                  .positiveCashFlowAddsRoomForBillsGoalsAndUnexpectedSpending
              : context.l10n
                  .negativeSavingsMeansSpendingIsHigherThanIncomeSoFarWatchFlexibleCategoriesAndUpcomingBillsFirst,
          accent: accent,
          icon: Icons.savings_rounded,
          visual: _MonthlyReportMiniBarChart(
            colorScheme: colorScheme,
            values: [
              report.trendSummary.previousSavings,
              report.trendSummary.currentSavings,
            ],
            accent: accent,
            height: 58,
          ),
        ),
        const SizedBox(height: 12),
        _MonthlyReportSectionTitle(
          title: context.l10n.categoryBuffer,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.netCashFlow,
              value: _detailSignedCurrency(
                report.trendSummary.netCashFlow,
                report.currencyCode,
              ),
              subtitle: context.l10n.incomeMinusSpending,
              accent: report.trendSummary.netCashFlow >= 0
                  ? colorScheme.success
                  : colorScheme.destructive,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.monthEndBuffer,
              value: formatCurrency(
                report.overview.forecastedBalance,
                report.currencyCode,
              ),
              subtitle: report.overview.forecastedBalance >= 0
                  ? context.l10n.positiveForecast
                  : context.l10n.negativeForecast,
              accent: report.overview.forecastedBalance >= 0
                  ? colorScheme.success
                  : colorScheme.destructive,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.savedThisMonth,
              value:
                  formatCurrency(report.overview.savings, report.currencyCode),
              subtitle: report.overview.savings >= 0
                  ? context.l10n.buildingRoom
                  : context.l10n.usingBuffer,
              accent: accent,
              visual: _MonthlyReportProgressBar(
                colorScheme: colorScheme,
                progress: goalProgress,
                accent: accent,
                compact: true,
              ),
            ),
          ],
        ),
        if (report.goals.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MonthlyReportSectionTitle(
            title: context.l10n.goals,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
          _MonthlyReportPreviewCard(
            colorScheme: colorScheme,
            children: [
              for (final goal in report.goals.take(5))
                _MonthlyReportDisclosureRow(
                  colorScheme: colorScheme,
                  title: goal.title,
                  value: '${(goal.progress * 100).round()}%',
                  subtitle: context.l10n.goalProgressNeeded(
                    formatCurrency(goal.currentAmount, report.currencyCode),
                    formatCurrency(goal.targetAmount, report.currencyCode),
                    formatCurrency(goal.monthlyNeeded, report.currencyCode),
                  ),
                  accent: goal.progress >= 1
                      ? colorScheme.success
                      : colorScheme.info,
                  icon: Icons.savings_rounded,
                  onTap: () => context.push(_monthlyReportDrillDownRouteFor(
                    query: query,
                    title: goal.title,
                    subtitle: context.l10n.goalProgressNeeded(
                      formatCurrency(goal.currentAmount, report.currencyCode),
                      formatCurrency(goal.targetAmount, report.currencyCode),
                      formatCurrency(goal.monthlyNeeded, report.currencyCode),
                    ),
                    sourceTransactionIds: const <String>[],
                    goalId: goal.id,
                  )),
                  visual: _MonthlyReportProgressBar(
                    colorScheme: colorScheme,
                    progress: goal.progress.clamp(0.0, 1.0),
                    accent: goal.progress >= 1
                        ? colorScheme.success
                        : colorScheme.info,
                    compact: true,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _MonthlyReportAboutCard(
          colorScheme: colorScheme,
          title: context.l10n.aboutSavings,
          body: context.l10n.savingsBody,
        ),
      ],
    );
  }

  Widget _buildCategoryDetail(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final selected = selectedCategoryName == null
        ? null
        : report.categoryTrends.where(
            (item) => item.name == selectedCategoryName,
          );
    final categories = selected != null && selected.isNotEmpty
        ? selected.toList(growable: false)
        : report.categoryTrends;
    final first = categories.isEmpty ? null : categories.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyReportDetailHeader(
          colorScheme: colorScheme,
          status: first == null
              ? context.l10n.categories
              : getCategoryTranslation(context, first.name),
          title: first == null
              ? context.l10n.noMovers
              : getCategoryTranslation(context, first.name),
          value: first == null
              ? context.l10n.noMovers
              : formatCurrency(first.currentSpent, report.currencyCode),
          caption: first == null
              ? context.l10n.moreHistoryNeeded
              : _detailCategoryCopy(context, first),
          accent: first == null
              ? colorScheme.info
              : _detailStatusColor(first.status, colorScheme),
          visual: _MonthlyReportMiniBarChart(
            colorScheme: colorScheme,
            values: first == null
                ? const []
                : [
                    first.previousSpent,
                    first.baselineAverageSpent,
                    first.currentSpent,
                  ],
            accent: first == null
                ? colorScheme.info
                : _detailStatusColor(first.status, colorScheme),
            height: 78,
          ),
        ),
        const SizedBox(height: 12),
        if (categories.isNotEmpty) ...[
          _MonthlyReportSectionTitle(
            title: context.l10n.categoryMovement,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),
          for (final item in categories.take(3)) ...[
            _MonthlyReportAdviceCard(
              colorScheme: colorScheme,
              label: context.l10n.categoryMovement,
              title: getCategoryTranslation(context, item.name),
              body:
                  '${_localizedCategoryTrendInsight(context, item)} ${context.l10n.currentSpendIs} ${formatCurrency(item.currentSpent, report.currencyCode)}.',
              accent: _detailStatusColor(item.status, colorScheme),
              icon: Icons.category_rounded,
              onTap: item.sourceTransactionIds.isEmpty
                  ? null
                  : () => context.push(_monthlyReportDrillDownRouteFor(
                        query: query,
                        title: getCategoryTranslation(context, item.name),
                        subtitle: _localizedCategoryTrendInsight(context, item),
                        sourceTransactionIds: item.sourceTransactionIds,
                      )),
              visual: _MonthlyReportMiniBarChart(
                colorScheme: colorScheme,
                values: [
                  item.previousSpent,
                  item.baselineAverageSpent,
                  item.currentSpent,
                ],
                accent: _detailStatusColor(item.status, colorScheme),
                height: 58,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
        _MonthlyReportSectionTitle(
          title: context.l10n.movers,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            if (categories.isEmpty)
              _MonthlyReportStaticRow(
                colorScheme: colorScheme,
                title: context.l10n.noCategoryTrends,
                value: context.l10n.waiting,
                subtitle: context.l10n.comparableSpendingWillAppearHere,
                accent: colorScheme.info,
              )
            else
              for (final item in categories.take(8))
                _MonthlyReportDisclosureRow(
                  colorScheme: colorScheme,
                  title: getCategoryTranslation(context, item.name),
                  value: formatCurrency(item.currentSpent, report.currencyCode),
                  subtitle: _detailCategoryCopy(context, item),
                  accent: _detailStatusColor(item.status, colorScheme),
                  icon: Icons.category_rounded,
                  onTap: () => context.push(_monthlyReportDrillDownRouteFor(
                    query: query,
                    title: getCategoryTranslation(context, item.name),
                    subtitle: _detailCategoryCopy(context, item),
                    sourceTransactionIds: item.sourceTransactionIds,
                  )),
                  visual: _MonthlyReportMiniBarChart(
                    colorScheme: colorScheme,
                    values: [item.previousSpent, item.currentSpent],
                    accent: _detailStatusColor(item.status, colorScheme),
                    height: 34,
                  ),
                ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMerchantPreview(context, colorScheme, report, query),
        const SizedBox(height: 12),
        _MonthlyReportAboutCard(
          colorScheme: colorScheme,
          title: context.l10n.aboutCategoryMovement,
          body: context.l10n.categoryMovementBody,
        ),
      ],
    );
  }

  Widget _buildRecurringDetail(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    final commitment = report.recurringCommitment;
    final accent = _detailStatusColor(commitment.status, colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyReportDetailHeader(
          colorScheme: colorScheme,
          status: context.l10n.recurring,
          title: context.l10n.recurring,
          value: formatCurrency(
            report.subscriptions.totalMonthlyAmount,
            report.currencyCode,
          ),
          caption: context.l10n.dueSoonCount(commitment.dueSoonCount),
          accent: accent,
          visual: _MonthlyReportProgressRing(
            colorScheme: colorScheme,
            progress: (commitment.incomeShare ?? 0).clamp(0.0, 1.0),
            center: _detailNullablePercent(context, commitment.incomeShare),
            accent: accent,
            size: 104,
          ),
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.monthlyRecurring,
              value: formatCurrency(
                commitment.monthlyAmount,
                report.currencyCode,
              ),
              accent: accent,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.dueIn14Days,
              value: formatCurrency(
                commitment.dueSoonAmount,
                report.currencyCode,
              ),
              accent: colorScheme.warning,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.incomeShare,
              value: _detailNullablePercent(context, commitment.incomeShare),
              accent: accent,
            ),
            _MonthlyReportStaticRow(
              colorScheme: colorScheme,
              title: context.l10n.dueSoonCountLabel,
              value: '${commitment.dueSoonCount}',
              accent: commitment.dueSoonCount > 0
                  ? colorScheme.warning
                  : colorScheme.success,
            ),
          ],
        ),
        if (commitment.monthlyAmount > 0) ...[
          const SizedBox(height: 12),
          _MonthlyReportAdviceCard(
            colorScheme: colorScheme,
            label: context.l10n.recurringCommitment,
            title: context.l10n.committedEachMonth(
                formatCurrency(commitment.monthlyAmount, report.currencyCode)),
            body: context.l10n.recurringCommitmentBody,
            accent: accent,
            icon: Icons.event_note_rounded,
          ),
        ],
        const SizedBox(height: 12),
        _MonthlyReportSectionTitle(
          title: context.l10n.subscriptions,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            if (report.subscriptions.items.isEmpty)
              _MonthlyReportStaticRow(
                colorScheme: colorScheme,
                title: context.l10n.noSubscriptions,
                value: context.l10n.clear,
                subtitle: context.l10n.recurringExpensesWillAppearHere,
                accent: colorScheme.success,
              )
            else
              for (final item in report.subscriptions.items.take(8))
                item.recurringId == null || item.recurringId!.trim().isEmpty
                    ? _MonthlyReportStaticRow(
                        colorScheme: colorScheme,
                        title: item.name,
                        value: formatCurrency(item.amount, report.currencyCode),
                        subtitle:
                            '${_detailShortDate(context, item.nextDate)} · ${item.note}',
                        accent: _detailSubscriptionColor(
                          item.status,
                          colorScheme,
                        ),
                      )
                    : _MonthlyReportDisclosureRow(
                        colorScheme: colorScheme,
                        title: item.name,
                        value: formatCurrency(item.amount, report.currencyCode),
                        subtitle:
                            '${_detailShortDate(context, item.nextDate)} · ${item.note}',
                        accent: _detailSubscriptionColor(
                          item.status,
                          colorScheme,
                        ),
                        icon: Icons.event_repeat_rounded,
                        onTap: () => context.push(
                          _monthlyReportDrillDownRouteFor(
                            query: query,
                            title: item.name,
                            subtitle:
                                '${_detailShortDate(context, item.nextDate)} · ${item.note}',
                            sourceTransactionIds: const <String>[],
                            recurringId: item.recurringId,
                          ),
                        ),
                      ),
          ],
        ),
        const SizedBox(height: 12),
        _MonthlyReportSectionTitle(
          title: context.l10n.billCalendar,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            if (report.upcomingObligations.isEmpty)
              _MonthlyReportStaticRow(
                colorScheme: colorScheme,
                title: context.l10n.noUpcomingBills,
                value: context.l10n.clear,
                subtitle: context.l10n.noScheduledMoneyMovementRemainsThisMonth,
                accent: colorScheme.success,
              )
            else
              for (final item in report.upcomingObligations.take(8))
                _MonthlyReportDisclosureRow(
                  colorScheme: colorScheme,
                  title: item.name,
                  value: item.type == 'income'
                      ? '+${formatCurrency(item.amount, report.currencyCode)}'
                      : formatCurrency(-item.amount, report.currencyCode),
                  subtitle: _detailShortDate(context, item.date),
                  accent: item.type == 'income'
                      ? colorScheme.success
                      : colorScheme.warning,
                  icon: item.type == 'income'
                      ? Icons.arrow_downward_rounded
                      : Icons.event_note_rounded,
                  onTap: () => context.push(_monthlyReportDrillDownRouteFor(
                    query: query,
                    title: item.name,
                    subtitle: _detailShortDate(context, item.date),
                    sourceTransactionIds: [
                      if (item.sourceTransactionId != null)
                        item.sourceTransactionId!,
                    ],
                    recurringId: item.recurringId,
                  )),
                ),
          ],
        ),
        const SizedBox(height: 12),
        _MonthlyReportAboutCard(
          colorScheme: colorScheme,
          title: context.l10n.aboutRecurringCosts,
          body: context.l10n.recurringCostsBody,
        ),
      ],
    );
  }

  Widget _buildForecastTimeline(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    return _MonthlyReportPreviewCard(
      colorScheme: colorScheme,
      children: [
        for (final entry
            in report.cashFlowForecast.take(6).toList().asMap().entries)
          entry.value.sourceTransactionId == null
              ? _MonthlyReportStaticRow(
                  colorScheme: colorScheme,
                  title: entry.key == 0
                      ? context.l10n.today
                      : entry.key == report.cashFlowForecast.take(6).length - 1
                          ? context.l10n.monthEndBuffer
                          : context.l10n
                              .afterLabel(entry.value.label.toLowerCase()),
                  value:
                      formatCurrency(entry.value.balance, report.currencyCode),
                  accent: entry.value.balance < 0
                      ? colorScheme.destructive
                      : colorScheme.info,
                )
              : _MonthlyReportDisclosureRow(
                  colorScheme: colorScheme,
                  title: context.l10n.afterLabel(
                    entry.value.label.toLowerCase(),
                  ),
                  subtitle: context.l10n.scheduled,
                  value:
                      formatCurrency(entry.value.balance, report.currencyCode),
                  accent: entry.value.balance < 0
                      ? colorScheme.destructive
                      : colorScheme.info,
                  icon: Icons.timeline_rounded,
                  onTap: () => context.push(_monthlyReportDrillDownRouteFor(
                    query: query,
                    title: entry.value.label,
                    subtitle: context.l10n.scheduled,
                    sourceTransactionIds: [entry.value.sourceTransactionId!],
                  )),
                ),
      ],
    );
  }

  Widget _buildMerchantPreview(
    BuildContext context,
    ColorScheme colorScheme,
    MonthlyFinancialReport report,
    MonthlyReportQuery query,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyReportSectionTitle(
          title: context.l10n.topMerchants,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        if (report.merchantConcentration.isNotEmpty) ...[
          _MonthlyReportMerchantShareChart(
            colorScheme: colorScheme,
            merchants: report.merchantConcentration.take(5).toList(),
            currencyCode: report.currencyCode,
          ),
          const SizedBox(height: 12),
        ],
        _MonthlyReportPreviewCard(
          colorScheme: colorScheme,
          children: [
            if (report.merchantConcentration.isEmpty)
              _MonthlyReportStaticRow(
                colorScheme: colorScheme,
                title: context.l10n.noMerchantData,
                value: context.l10n.waiting,
                subtitle: context.l10n.merchantNamesWillAppearWhenAvailable,
                accent: colorScheme.info,
              )
            else
              for (final item in report.merchantConcentration.take(6))
                _MonthlyReportDisclosureRow(
                  colorScheme: colorScheme,
                  title: getCategoryTranslation(context, item.name),
                  value: formatCurrency(item.amount, report.currencyCode),
                  subtitle: context.l10n.ofSpendingLabel,
                  accent: colorScheme.info,
                  icon: Icons.receipt_long_rounded,
                  onTap: () => context.push(_monthlyReportDrillDownRouteFor(
                    query: query,
                    title: getCategoryTranslation(context, item.name),
                    subtitle: context.l10n.ofSpendingLabel,
                    sourceTransactionIds: item.sourceTransactionIds,
                  )),
                  visual: _MonthlyReportProgressBar(
                    colorScheme: colorScheme,
                    progress: item.spendingShare.clamp(0.0, 1.0),
                    accent: colorScheme.info,
                    compact: true,
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class MonthlyReportDrillDownPage extends HookConsumerWidget {
  const MonthlyReportDrillDownPage({
    super.key,
    required this.query,
    this.title,
    this.subtitle,
    this.sourceTransactionIds,
    this.recurringId,
    this.goalId,
  });

  final MonthlyReportQuery query;
  final String? title;
  final String? subtitle;
  final String? sourceTransactionIds;
  final String? recurringId;
  final String? goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final reportAsync = ref.watch(monthlyFinancialReportProvider(query));
    final snapshot = reportAsync.valueOrNull;
    final ids = _decodeSourceTransactionIds(sourceTransactionIds).toSet();
    final householdScope = ref.watch(householdScopeProvider);
    final List<RecurringTransaction> recurringTransactions = ref
            .watch(recurringTransactionsProvider(
                _monthlyReportHouseholdId(householdScope)))
            .data
            .valueOrNull ??
        const <RecurringTransaction>[];
    final recurringTransactionsById = {
      for (final transaction in recurringTransactions)
        transaction.id: transaction,
    };
    final selectedRecurring = recurringTransactionsById[recurringId];
    final List<WalletEntity> scopedWallets =
        ref.watch(scopedWalletsProvider).valueOrNull ?? const <WalletEntity>[];

    final transactions = snapshot == null
        ? <ExpenseEntry>[]
        : snapshot.sourceTransactions
            .where((entry) => ids.contains(entry.id))
            .toList(growable: true);
    transactions.sort((a, b) => b.date.compareTo(a.date));
    MonthlyGoalReportItem? selectedGoal;
    final selectedGoalId = goalId?.trim();
    if (snapshot != null &&
        selectedGoalId != null &&
        selectedGoalId.isNotEmpty) {
      for (final goal in snapshot.report.goals) {
        if (goal.id == selectedGoalId) {
          selectedGoal = goal;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: SafeArea(
        child: _MonthlyReportDetailShell(
          colorScheme: colorScheme,
          title: title?.trim().isNotEmpty == true
              ? title!.trim()
              : context.l10n.details,
          child: snapshot == null
              ? _ReportCard(
                  colorScheme: colorScheme,
                  child: Center(
                    child: reportAsync.hasError
                        ? Text(
                            context.l10n
                                .couldNotLoadReport('${reportAsync.error}'),
                            style: TextStyle(
                              color: colorScheme.destructive,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : CircularProgressIndicator(color: colorScheme.primary),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle?.trim().isNotEmpty == true) ...[
                      _MonthlyReportAboutCard(
                        colorScheme: colorScheme,
                        title: context.l10n.details,
                        body: subtitle!.trim(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (selectedRecurring != null) ...[
                      _MonthlyReportSectionTitle(
                        title: context.l10n.recurring,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 12),
                      _MonthlyReportPreviewCard(
                        colorScheme: colorScheme,
                        children: [
                          _MonthlyReportDisclosureRow(
                            colorScheme: colorScheme,
                            title: selectedRecurring.description
                                        ?.trim()
                                        .isNotEmpty ==
                                    true
                                ? selectedRecurring.description!.trim()
                                : selectedRecurring.merchant
                                            ?.trim()
                                            .isNotEmpty ==
                                        true
                                    ? selectedRecurring.merchant!.trim()
                                    : getCategoryTranslation(
                                        context,
                                        selectedRecurring.category,
                                      ),
                            subtitle: _detailShortDate(
                              context,
                              selectedRecurring.date,
                            ),
                            value: selectedRecurring.type == 'income'
                                ? '+${formatCurrency(selectedRecurring.amount, selectedRecurring.currency)}'
                                : formatCurrency(
                                    -selectedRecurring.amount,
                                    selectedRecurring.currency,
                                  ),
                            accent: selectedRecurring.type == 'income'
                                ? colorScheme.success
                                : colorScheme.warning,
                            icon: Icons.event_repeat_rounded,
                            onTap: () async {
                              await showAddRecurringSheet(
                                context,
                                type: selectedRecurring.type,
                                existingTransaction: selectedRecurring,
                              );
                              if (context.mounted) {
                                await ref
                                    .read(monthlyFinancialReportProvider(query)
                                        .notifier)
                                    .refreshReport();
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (selectedGoal != null) ...[
                      _MonthlyReportSectionTitle(
                        title: context.l10n.goals,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 12),
                      _MonthlyReportPreviewCard(
                        colorScheme: colorScheme,
                        children: [
                          _MonthlyReportStaticRow(
                            colorScheme: colorScheme,
                            title: context.l10n.currentAmount,
                            value: formatCurrency(
                              selectedGoal.currentAmount,
                              snapshot.report.currencyCode,
                            ),
                            accent: colorScheme.info,
                          ),
                          _MonthlyReportStaticRow(
                            colorScheme: colorScheme,
                            title: context.l10n.targetAmount,
                            value: formatCurrency(
                              selectedGoal.targetAmount,
                              snapshot.report.currencyCode,
                            ),
                            accent: colorScheme.success,
                          ),
                          _MonthlyReportStaticRow(
                            colorScheme: colorScheme,
                            title: context.l10n.monthly,
                            value: formatCurrency(
                              selectedGoal.monthlyNeeded,
                              snapshot.report.currencyCode,
                            ),
                            subtitle:
                                '${(selectedGoal.progress * 100).round()}%',
                            accent: selectedGoal.status ==
                                    MonthlyReportStatus.onTrack
                                ? colorScheme.success
                                : colorScheme.warning,
                            visual: _MonthlyReportProgressBar(
                              colorScheme: colorScheme,
                              progress: selectedGoal.progress.clamp(0.0, 1.0),
                              accent: selectedGoal.status ==
                                      MonthlyReportStatus.onTrack
                                  ? colorScheme.success
                                  : colorScheme.warning,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    _MonthlyReportSectionTitle(
                      title: context.l10n.transactions,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 12),
                    _MonthlyReportPreviewCard(
                      colorScheme: colorScheme,
                      children: [
                        if (transactions.isEmpty)
                          _MonthlyReportStaticRow(
                            colorScheme: colorScheme,
                            title: context.l10n.noTransactionsForPeriod,
                            value: context.l10n.clear,
                            accent: colorScheme.info,
                          )
                        else
                          for (final transaction in transactions)
                            _MonthlyReportDisclosureRow(
                              colorScheme: colorScheme,
                              title: transaction.merchant?.trim().isNotEmpty ==
                                      true
                                  ? transaction.merchant!.trim()
                                  : transaction.rawText?.trim().isNotEmpty ==
                                          true
                                      ? transaction.rawText!.trim()
                                      : getCategoryTranslation(
                                          context,
                                          transaction.category ?? '',
                                        ),
                              subtitle: _detailShortDate(
                                context,
                                transaction.date,
                              ),
                              value: transaction.type == 'income'
                                  ? '+${formatCurrency(transaction.amount, transaction.currency ?? snapshot.report.currencyCode)}'
                                  : formatCurrency(
                                      -transaction.amount,
                                      transaction.currency ??
                                          snapshot.report.currencyCode,
                                    ),
                              accent: transaction.type == 'income'
                                  ? colorScheme.success
                                  : colorScheme.warning,
                              icon: transaction.type == 'income'
                                  ? Icons.arrow_downward_rounded
                                  : Icons.receipt_long_rounded,
                              onTap: () async {
                                await showTransactionDetailsSheet(
                                  context,
                                  expense: transaction,
                                  recurringTransactionsById:
                                      recurringTransactionsById,
                                  transferWallets: scopedWallets,
                                );
                                if (context.mounted) {
                                  await ref
                                      .read(
                                          monthlyFinancialReportProvider(query)
                                              .notifier)
                                      .refreshReport();
                                }
                              },
                            ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

List<String> _decodeSourceTransactionIds(String? value) {
  if (value == null || value.trim().isEmpty) return const <String>[];
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _monthlyReportHouseholdId(HouseholdScope scope) {
  switch (scope.activeAccountType) {
    case ActiveWalletType.personal:
      return null;
    case ActiveWalletType.portfolio:
      return scope.activeAccountHouseholdId;
    case ActiveWalletType.household:
      return scope.selectedHouseholdId ?? scope.activeAccountHouseholdId;
  }
}

class _MonthlyReportPageTitle extends StatelessWidget {
  const _MonthlyReportPageTitle({
    required this.title,
    required this.colorScheme,
    this.trailing,
  });

  final String title;
  final ColorScheme colorScheme;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: _monthlyReportPageTitleFontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: colorScheme.foreground,
                height: 1.05,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MonthlyReportSectionTitle extends StatelessWidget {
  const _MonthlyReportSectionTitle({
    required this.title,
    required this.colorScheme,
    this.actionLabel,
    this.onActionTap,
    this.trailing,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final ColorScheme colorScheme;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isInDetailShell =
        context.findAncestorWidgetOfExactType<_MonthlyReportDetailShell>() !=
            null;
    return Padding(
      // Detail pages stack many sections; add separation there without
      // inflating the main monthly report page layout.
      padding: EdgeInsets.only(top: isInDetailShell ? 14 : 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: _monthlyReportSectionTitleFontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: colorScheme.foreground,
                height: 1.05,
              ),
            ),
          ),
          if (actionLabel != null && onActionTap != null)
            InkWell(
              onTap: onActionTap,
              borderRadius: BorderRadius.circular(999),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MonthlyMetricSpec {
  const _MonthlyMetricSpec({
    required this.label,
    required this.value,
    required this.caption,
    required this.accent,
    required this.icon,
    required this.route,
    required this.visual,
  });

  final String label;
  final String value;
  final String caption;
  final Color accent;
  final IconData icon;
  final String route;
  final Widget visual;
}

class _MonthlyHighlightItem {
  const _MonthlyHighlightItem({
    required this.title,
    required this.label,
    required this.status,
    required this.icon,
    required this.route,
    this.chart,
  });

  final String title;
  final String label;
  final MonthlyReportStatus status;
  final IconData icon;
  final String route;
  final Widget? chart;
}

class _MonthlyReportHeroCard extends StatelessWidget {
  const _MonthlyReportHeroCard({
    required this.colorScheme,
    required this.label,
    required this.title,
    required this.value,
    required this.caption,
    required this.accent,
    required this.onTap,
    required this.visual,
  });

  final ColorScheme colorScheme;
  final String label;
  final String title;
  final String value;
  final String caption;
  final Color accent;
  final VoidCallback onTap;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return _MonthlyReportTappableSurface(
      colorScheme: colorScheme,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 520;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MonthlyReportEyebrow(
                colorScheme: colorScheme,
                label: label,
                accent: accent,
                icon: Icons.favorite_rounded,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.foreground,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                caption,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                  height: 1.25,
                ),
              ),
            ],
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 20),
                visual,
                const SizedBox(width: 8),
                _MonthlyReportChevron(colorScheme: colorScheme),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 12),
                  _MonthlyReportChevron(colorScheme: colorScheme),
                ],
              ),
              const SizedBox(height: 18),
              Center(child: visual),
            ],
          );
        },
      ),
    );
  }
}

class _MonthlyReportInsightCard extends StatelessWidget {
  const _MonthlyReportInsightCard({
    required this.colorScheme,
    required this.title,
    required this.label,
    required this.accent,
    required this.icon,
    required this.onTap,
    this.chart,
  });

  final ColorScheme colorScheme;
  final String title;
  final String label;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? chart;

  @override
  Widget build(BuildContext context) {
    return _MonthlyReportTappableSurface(
      colorScheme: colorScheme,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MonthlyReportEyebrow(
                  colorScheme: colorScheme,
                  label: context.l10n.insight,
                  accent: accent,
                  icon: icon,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.foreground,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.mutedForeground,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (chart != null) ...[
            const SizedBox(width: 14),
            SizedBox(width: 84, height: 72, child: chart),
          ],
          const SizedBox(width: 8),
          _MonthlyReportChevron(colorScheme: colorScheme),
        ],
      ),
    );
  }
}

class _MonthlyReportPreviewCard extends StatelessWidget {
  const _MonthlyReportPreviewCard({
    required this.colorScheme,
    required this.children,
  });

  final ColorScheme colorScheme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ReportCard(
      colorScheme: colorScheme,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 1,
                color: isDark
                    ? colorScheme.homeCardBorder.withValues(alpha: 0.3)
                    : colorScheme.homeCardBorder.withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}

class _MonthlyReportDisclosureRow extends StatelessWidget {
  const _MonthlyReportDisclosureRow({
    required this.colorScheme,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.icon,
    required this.onTap,
    this.visual,
  });

  final ColorScheme colorScheme;
  final String title;
  final String subtitle;
  final String value;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? visual;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: _monthlyReportRowPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MonthlyReportIconChip(
                  colorScheme: colorScheme,
                  accent: accent,
                  icon: icon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.foreground,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topRight,
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.foreground,
                          height: 1.15,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _MonthlyReportChevron(colorScheme: colorScheme),
              ],
            ),
            if (visual != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 46, right: 30),
                child: visual!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthlyReportStaticRow extends StatelessWidget {
  const _MonthlyReportStaticRow({
    required this.colorScheme,
    required this.title,
    required this.value,
    required this.accent,
    this.subtitle,
    this.visual,
  });

  final ColorScheme colorScheme;
  final String title;
  final String value;
  final String? subtitle;
  final Color accent;
  final Widget? visual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _monthlyReportRowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.foreground,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.topRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topRight,
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        height: 1.15,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (visual != null) ...[
            const SizedBox(height: 12),
            visual!,
          ],
        ],
      ),
    );
  }
}

class _MonthlyReportDetailShell extends StatelessWidget {
  const _MonthlyReportDetailShell({
    required this.colorScheme,
    required this.title,
    required this.child,
  });

  final ColorScheme colorScheme;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        _monthlyReportPageHorizontalPadding,
        20,
        _monthlyReportPageHorizontalPadding,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/dashboard');
                      }
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.homeCardSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.homeCardBorder),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 32,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _monthlyReportSectionTitleFontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: colorScheme.foreground,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 62),
                ],
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyReportDetailHeader extends StatelessWidget {
  const _MonthlyReportDetailHeader({
    required this.colorScheme,
    required this.status,
    required this.title,
    required this.value,
    required this.caption,
    required this.accent,
    required this.visual,
  });

  final ColorScheme colorScheme;
  final String status;
  final String title;
  final String value;
  final String caption;
  final Color accent;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      colorScheme: colorScheme,
      padding: _monthlyReportWidgetPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 540;
          final visualWidth = math.min(220.0, constraints.maxWidth);
          final constrainedVisual = SizedBox(
            width: visualWidth,
            child: Center(child: visual),
          );
          final metric = SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MonthlyReportEyebrow(
                  colorScheme: colorScheme,
                  label: status,
                  accent: accent,
                  icon: Icons.insights_rounded,
                ),
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 33,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.foreground,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.mutedForeground,
                    height: 1.25,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: metric),
                const SizedBox(width: 22),
                constrainedVisual,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              metric,
              const SizedBox(height: 20),
              Center(child: constrainedVisual),
            ],
          );
        },
      ),
    );
  }
}

class _MonthlyReportRangeSelector extends StatelessWidget {
  const _MonthlyReportRangeSelector({
    required this.colorScheme,
    required this.selected,
    required this.onChanged,
  });

  final ColorScheme colorScheme;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('week', context.l10n.week),
      ('month', context.l10n.month),
      ('6m', context.l10n.sixMonths),
      ('year', context.l10n.year),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final (key, label) in entries)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(key),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(minHeight: 38),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == key
                        ? colorScheme.tabThumb
                        : colorScheme.surface.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected == key
                          ? colorScheme.tabSelectedForeground
                          : colorScheme.tabUnselectedForeground,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthlyReportTappableSurface extends StatelessWidget {
  const _MonthlyReportTappableSurface({
    required this.colorScheme,
    required this.onTap,
    required this.child,
    this.padding = _monthlyReportWidgetPadding,
  });

  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colorScheme.homeCardShadow,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: colorScheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colorScheme.surfaceBorder, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthlyReportEyebrow extends StatelessWidget {
  const _MonthlyReportEyebrow({
    required this.colorScheme,
    required this.label,
    required this.accent,
    required this.icon,
  });

  final ColorScheme colorScheme;
  final String label;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MonthlyReportChevron extends StatelessWidget {
  const _MonthlyReportChevron({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      size: 26,
      color: colorScheme.mutedForeground.withValues(alpha: 0.46),
    );
  }
}

class _MonthlyReportIconChip extends StatelessWidget {
  const _MonthlyReportIconChip({
    required this.colorScheme,
    required this.accent,
    required this.icon,
  });

  final ColorScheme colorScheme;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 18, color: accent),
    );
  }
}

class _MonthlyReportProgressBar extends StatelessWidget {
  const _MonthlyReportProgressBar({
    required this.colorScheme,
    required this.progress,
    required this.accent,
    this.compact = false,
  });

  final ColorScheme colorScheme;
  final double progress;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: compact ? 6 : 8,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: colorScheme.border.withValues(alpha: 0.22),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyReportProgressRing extends StatelessWidget {
  const _MonthlyReportProgressRing({
    required this.colorScheme,
    required this.progress,
    required this.center,
    required this.accent,
    required this.size,
  });

  final ColorScheme colorScheme;
  final double progress;
  final String center;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return CustomPaint(
          painter: _MonthlyReportRingPainter(
            colorScheme: colorScheme,
            progress: value,
            accent: accent,
          ),
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  center,
                  style: TextStyle(
                    fontSize: size < 70 ? 12 : 22,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.foreground,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MonthlyReportRingPainter extends CustomPainter {
  const _MonthlyReportRingPainter({
    required this.colorScheme,
    required this.progress,
    required this.accent,
  });

  final ColorScheme colorScheme;
  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = (side * 0.11).clamp(6.0, 14.0);
    final radius = side / 2 - stroke / 2;
    final trackPaint = Paint()
      ..color = colorScheme.border.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    final progressPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MonthlyReportRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class _MonthlyReportMiniBarChart extends StatelessWidget {
  const _MonthlyReportMiniBarChart({
    required this.colorScheme,
    required this.values,
    required this.accent,
    this.height = 54,
  });

  final ColorScheme colorScheme;
  final List<double> values;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visibleValues = values.isEmpty ? const [0.0] : values;
    final maxValue = visibleValues.fold<double>(
      1,
      (maxValue, value) => math.max(maxValue, value.abs()),
    );

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < visibleValues.length; index++) ...[
            Expanded(
              child: FractionallySizedBox(
                heightFactor:
                    (visibleValues[index].abs() / maxValue).clamp(0.08, 1.0),
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: index == visibleValues.length - 1
                        ? accent
                        : colorScheme.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            if (index != visibleValues.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _MonthlyReportSparkline extends StatelessWidget {
  const _MonthlyReportSparkline({
    required this.colorScheme,
    required this.values,
    required this.accent,
    this.height = 54,
  });

  final ColorScheme colorScheme;
  final List<double> values;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final chartValues = values.length < 2 ? [0.0, ...values, 0.0] : values;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _MonthlyReportSparklinePainter(
          colorScheme: colorScheme,
          values: chartValues,
          accent: accent,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MonthlyReportSparklinePainter extends CustomPainter {
  const _MonthlyReportSparklinePainter({
    required this.colorScheme,
    required this.values,
    required this.accent,
  });

  final ColorScheme colorScheme;
  final List<double> values;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(maxValue - minValue, 1);
    final path = Path();
    final fillPath = Path();

    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y = size.height -
          ((values[index] - minValue) / range).clamp(0.0, 1.0) * size.height;

      if (index == 0) {
        path.moveTo(x, y);
        fillPath
          ..moveTo(x, size.height)
          ..lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = accent.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()
        ..color = colorScheme.border.withValues(alpha: 0.28)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _MonthlyReportSparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.accent != accent ||
        oldDelegate.colorScheme != colorScheme;
  }
}

String _localizedStatusLabel(BuildContext context, MonthlyReportStatus status) {
  switch (status) {
    case MonthlyReportStatus.onTrack:
      return context.l10n.onTrack;
    case MonthlyReportStatus.spendingFast:
      return context.l10n.spending;
    case MonthlyReportStatus.overBudget:
      return context.l10n.overBudget;
    case MonthlyReportStatus.safeToSpend:
      return context.l10n.safeToSpend;
    case MonthlyReportStatus.needsAttention:
      return context.l10n.needsAttention;
    case MonthlyReportStatus.unusualSpending:
      return context.l10n.unusualActivity;
  }
}

String _detailTitle(BuildContext context, MonthlyReportDetailKind kind) {
  switch (kind) {
    case MonthlyReportDetailKind.balance:
      return context.l10n.balance;
    case MonthlyReportDetailKind.safeSpend:
      return context.l10n.safeToSpend;
    case MonthlyReportDetailKind.spending:
      return context.l10n.spending;
    case MonthlyReportDetailKind.budget:
      return context.l10n.budget;
    case MonthlyReportDetailKind.savings:
      return context.l10n.savings;
    case MonthlyReportDetailKind.categories:
      return context.l10n.categories;
    case MonthlyReportDetailKind.recurring:
      return context.l10n.recurring;
  }
}

Color _detailStatusColor(MonthlyReportStatus status, ColorScheme colorScheme) {
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

Color _detailSubscriptionColor(
  MonthlySubscriptionStatus status,
  ColorScheme colorScheme,
) {
  switch (status) {
    case MonthlySubscriptionStatus.active:
    case MonthlySubscriptionStatus.upcoming:
      return colorScheme.info;
    case MonthlySubscriptionStatus.priceIncrease:
      return colorScheme.warning;
    case MonthlySubscriptionStatus.duplicatePossible:
      return colorScheme.destructive;
  }
}

double _detailBudgetProgress(MonthlyFinancialReport report) {
  final budgeted = report.budgetPlan.totalBudgeted;
  if (budgeted <= 0) return report.budgetPlan.totalSpent <= 0 ? 0 : 1;
  return (report.budgetPlan.totalSpent / budgeted).clamp(0.0, 1.4);
}

String _detailPercent(double value) => '${(value * 100).round()}%';

String _detailNullablePercent(BuildContext context, double? value) {
  if (value == null) return context.l10n.noBaseline;
  return _detailPercent(value);
}

String _detailSignedCurrency(double value, String currencyCode) {
  if (value == 0) return formatCurrency(0, currencyCode);
  final sign = value > 0 ? '+' : '';
  return '$sign${formatCurrency(value, currencyCode)}';
}

String _detailShortDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context)
      .formatMediumDate(date)
      .split(',')
      .first;
}

String _detailCategoryCopy(
    BuildContext context, MonthlyCategoryTrendItem item) {
  final change = item.previousChangePercent ?? item.baselineChangePercent;
  if (change == null) return _localizedCategoryTrendInsight(context, item);
  final direction = change >= 0 ? context.l10n.higher : context.l10n.lower;
  return context.l10n
      .percentDirectionThanComparison(_detailPercent(change.abs()), direction);
}

String _detailHealthHeadline(BuildContext context, MonthlyReportStatus status) {
  switch (status) {
    case MonthlyReportStatus.onTrack:
    case MonthlyReportStatus.safeToSpend:
      return context.l10n.yourMonthMostlyOnTrack;
    case MonthlyReportStatus.spendingFast:
      return context.l10n.spendingMovingLittleFast;
    case MonthlyReportStatus.needsAttention:
      return context.l10n.monthNeedsSmallAdjustment;
    case MonthlyReportStatus.overBudget:
      return context.l10n.budgetsNeedAttentionDetail;
    case MonthlyReportStatus.unusualSpending:
      return context.l10n.spendingPatternsToReview;
  }
}

String _detailBudgetSubtitle(
  BuildContext context,
  MonthlyFinancialReport report,
  MonthlyBudgetHealthItem item,
) {
  final paceItem = _detailFindPaceItem(report, item.name);
  final spent = formatCurrency(item.spent, report.currencyCode);
  if (paceItem == null) return '$spent ${context.l10n.spent.toLowerCase()}';

  final spentPercent = (paceItem.spentProgress * 100).round();
  final timePercent = (paceItem.timeProgress * 100).round();
  return context.l10n.spentUsedVsMonth(spent, spentPercent, timePercent);
}

Widget _detailBudgetPaceVisual(
  ColorScheme colorScheme,
  MonthlyFinancialReport report,
  MonthlyBudgetHealthItem item,
) {
  final accent = _detailStatusColor(item.status, colorScheme);
  final paceItem = _detailFindPaceItem(report, item.name);
  if (paceItem == null) {
    return _MonthlyReportProgressBar(
      colorScheme: colorScheme,
      progress: item.budgetAmount <= 0
          ? 1
          : (item.spent / item.budgetAmount).clamp(0.0, 1.0),
      accent: accent,
      compact: true,
    );
  }

  return _MonthlyReportPaceComparisonBar(
    colorScheme: colorScheme,
    accent: accent,
    spentProgress: paceItem.spentProgress.clamp(0.0, 1.0),
    timeProgress: paceItem.timeProgress.clamp(0.0, 1.0),
  );
}

MonthlySpendingPaceItem? _detailFindPaceItem(
  MonthlyFinancialReport report,
  String name,
) {
  for (final item in report.spendingPace) {
    if (item.label == name) return item;
  }
  return null;
}

List<_HealthRingMetric> _buildDetailHealthRingMetrics(
  BuildContext context,
  ColorScheme colorScheme,
  MonthlyFinancialReport report,
) {
  final budgetPaceProgress = _detailBudgetPaceProgress(report);
  final billsCoveredProgress = _detailBillsCoveredProgress(report);
  final savingsBufferProgress = _detailSavingsBufferProgress(report);
  final forecastIsPositive = report.overview.forecastedBalance >= 0;
  final vibrantPalette = _detailVibrantRingPalette(colorScheme);

  return [
    _HealthRingMetric(
      label: context.l10n.safeSpend,
      value: context.l10n.perDay(
          formatCurrency(report.safeToSpend.dailyAmount, report.currencyCode)),
      status: report.safeToSpend.dailyAmount > 0
          ? context.l10n.availableToday
          : context.l10n.holdSpending,
      progress: _detailSafeToSpendProgress(report),
      color: vibrantPalette[1],
      icon: Icons.wallet_rounded,
    ),
    _HealthRingMetric(
      label: context.l10n.budgetPace,
      value: '${(budgetPaceProgress * 100).round()}%',
      status: _detailPaceStatus(context, report),
      progress: budgetPaceProgress,
      color: vibrantPalette[0],
      icon: Icons.speed_rounded,
    ),
    _HealthRingMetric(
      label: context.l10n.billsCovered,
      value: context.l10n.scheduledCount(report.upcomingObligations.length),
      status: billsCoveredProgress >= 1
          ? context.l10n.coveredAhead
          : context.l10n.needsCashFlow,
      progress: billsCoveredProgress,
      color: vibrantPalette[2],
      icon: Icons.event_note_rounded,
    ),
    _HealthRingMetric(
      label: context.l10n.monthEndBuffer,
      value: formatCurrency(
        report.overview.forecastedBalance,
        report.currencyCode,
      ),
      status: forecastIsPositive
          ? context.l10n.positiveForecast
          : context.l10n.negativeForecast,
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

double _detailSafeToSpendProgress(MonthlyFinancialReport report) {
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

double _detailBudgetPaceProgress(MonthlyFinancialReport report) {
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

double _detailBillsCoveredProgress(MonthlyFinancialReport report) {
  final obligations = report.safeToSpend.futureObligations;
  if (obligations <= 0) return 1;

  final available = math.max(0, report.overview.currentBalance) +
      report.safeToSpend.futureIncome;
  return (available / obligations).clamp(0.08, 2.4);
}

double _detailSavingsBufferProgress(MonthlyFinancialReport report) {
  final forecast = report.overview.forecastedBalance;
  if (forecast <= 0) return 0.08;

  final monthlyReference = math.max(
    report.safeToSpend.futureObligations,
    math.max(report.overview.spending * 0.35, 1),
  );
  return (forecast / monthlyReference).clamp(0.12, 2.6);
}

double _detailSavingsRateProgress(MonthlyFinancialReport report) {
  final rate = report.trendSummary.savingsRate;
  if (rate <= 0) return 0.08;
  return (rate / 0.25).clamp(0.08, 1.0);
}

List<Color> _detailVibrantRingPalette(ColorScheme colorScheme) {
  return [
    _detailVibrantColor(colorScheme.success),
    _detailVibrantColor(colorScheme.warning, hueShift: 6),
    _detailVibrantColor(colorScheme.info, hueShift: -18),
    _detailVibrantColor(colorScheme.primary, hueShift: 26),
  ];
}

Color _detailVibrantColor(Color color, {double hueShift = 0}) {
  final hsl = HSLColor.fromColor(color);
  final shiftedHue = (hsl.hue + hueShift + 360) % 360;

  return hsl
      .withHue(shiftedHue)
      .withSaturation((hsl.saturation + 0.2).clamp(0.48, 1.0))
      .withLightness((hsl.lightness - 0.02).clamp(0.34, 0.62))
      .toColor();
}

String _detailPaceStatus(BuildContext context, MonthlyFinancialReport report) {
  final fastCount = report.spendingPace
      .where(
        (item) =>
            item.status == MonthlyReportStatus.spendingFast ||
            item.status == MonthlyReportStatus.overBudget ||
            item.status == MonthlyReportStatus.needsAttention,
      )
      .length;
  if (fastCount == 0) return context.l10n.onExpectedPace;
  if (fastCount == 1) return context.l10n.oneBudgetToWatch;
  return '$fastCount ${context.l10n.budgetsToWatch}';
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
    final didNotifyComplete = useRef(false);

    useEffect(() {
      if (!isComplete || didNotifyComplete.value) return null;
      didNotifyComplete.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        didNotifyComplete.value = true;
        onComplete();
      });
      return null;
    }, [isComplete, onComplete]);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _ReportCard(
            colorScheme: colorScheme,
            padding: _monthlyReportWidgetPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.buildingMonthlyReport,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isComplete
                      ? context.l10n.reportReady
                      : context.l10n.checkingBudgetsTrends,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.mutedForeground,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    backgroundColor:
                        colorScheme.mutedForeground.withValues(alpha: 0.15),
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthlyReportSyncStatus extends StatefulWidget {
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
  State<_MonthlyReportSyncStatus> createState() =>
      _MonthlyReportSyncStatusState();
}

class _MonthlyReportSyncStatusState extends State<_MonthlyReportSyncStatus>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_MonthlyReportSyncStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.isRefreshing
        ? widget.colorScheme.primary
        : widget.colorScheme.mutedForeground;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isRefreshing)
          RotationTransition(
            turns: _animation,
            child: Icon(
              Icons.sync_rounded,
              size: 14,
              color: foreground,
            ),
          )
        else
          Icon(
            Icons.cloud_done_rounded,
            size: 14,
            color: foreground,
          ),
        const SizedBox(width: 6),
        Text(
          widget.isRefreshing
              ? context.l10n.refreshingReport
              : '${context.l10n.lastSynced} ${_formatLastSyncedAt(context, widget.lastSyncedAt)}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: foreground,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

String _formatLastSyncedAt(BuildContext context, DateTime? value) {
  if (value == null) return context.l10n.never;

  final localValue = value.toLocal();
  final now = DateTime.now();
  final elapsed = now.difference(localValue);
  if (elapsed.inSeconds < 45) return context.l10n.justNow;
  if (elapsed.inMinutes < 60) {
    final minutes = elapsed.inMinutes;
    return minutes == 1
        ? context.l10n.minuteAgo
        : context.l10n.minutesAgo(minutes, 's');
  }
  if (elapsed.inHours < 12) {
    final hours = elapsed.inHours;
    return hours == 1
        ? context.l10n.hourAgo
        : context.l10n.hoursAgoCount(hours);
  }

  final localizations = MaterialLocalizations.of(context);
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(localValue),
  );
  final sameDay = now.year == localValue.year &&
      now.month == localValue.month &&
      now.day == localValue.day;
  if (sameDay) return '${context.l10n.todayAt} $time';

  return '${localizations.formatShortDate(localValue)} ${context.l10n.at} $time';
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.colorScheme,
    required this.child,
    this.padding = _monthlyReportWidgetPadding,
  });

  final ColorScheme colorScheme;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.homeCardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: colorScheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.surfaceBorder, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
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
