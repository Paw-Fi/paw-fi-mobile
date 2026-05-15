import 'dart:math' as math;

import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/l10n/app_localizations_en.dart';

enum MonthlyReportStatus {
  onTrack,
  spendingFast,
  overBudget,
  safeToSpend,
  needsAttention,
  unusualSpending,
}

enum MonthlySubscriptionStatus {
  active,
  upcoming,
  priceIncrease,
  duplicatePossible,
}

class MonthlyReportInput {
  const MonthlyReportInput({
    required this.monthStart,
    required this.now,
    required this.currencyCode,
    required this.currentBalance,
    required this.currentMonthTransactions,
    required this.previousMonthTransactions,
    required this.budgetItems,
    required this.futureTransactions,
    required this.recurringItems,
    required this.goals,
    this.periodStart,
    this.periodEnd,
    this.compareMonthToDate = true,
    this.historicalTransactions = const [],
    this.previousNetWorth,
    this.goalsDataAvailable = true,
  });

  final DateTime monthStart;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final bool compareMonthToDate;
  final DateTime now;
  final String currencyCode;
  final double currentBalance;
  final List<MonthlyReportTransactionInput> currentMonthTransactions;
  final List<MonthlyReportTransactionInput> previousMonthTransactions;
  final List<MonthlyReportTransactionInput> historicalTransactions;
  final List<MonthlyReportBudgetInput> budgetItems;
  final List<MonthlyReportTransactionInput> futureTransactions;
  final List<MonthlyReportRecurringInput> recurringItems;
  final List<MonthlyReportGoalInput> goals;
  final double? previousNetWorth;
  final bool goalsDataAvailable;
}

class MonthlyReportTransactionInput {
  const MonthlyReportTransactionInput({
    required this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.category,
    required this.currencyCode,
    this.merchant,
  });

  final String id;
  final DateTime date;
  final double amount;
  final String type;
  final String category;
  final String currencyCode;
  final String? merchant;
}

class MonthlyReportBudgetInput {
  const MonthlyReportBudgetInput({
    required this.name,
    required this.budgetAmount,
    required this.spent,
  });

  final String name;
  final double budgetAmount;
  final double spent;
}

class MonthlyReportRecurringInput {
  const MonthlyReportRecurringInput({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.currencyCode,
    required this.nextDate,
    this.previousAmount,
  });

  final String id;
  final String name;
  final double amount;
  final String type;
  final String currencyCode;
  final DateTime nextDate;
  final double? previousAmount;
}

class MonthlyReportGoalInput {
  const MonthlyReportGoalInput({
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.currencyCode,
    required this.targetDate,
    required this.isOnTrack,
    this.id = '',
  });

  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String currencyCode;
  final String targetDate;
  final bool isOnTrack;
}

class MonthlyFinancialReport {
  const MonthlyFinancialReport({
    required this.monthStart,
    required this.currencyCode,
    required this.overview,
    required this.safeToSpend,
    required this.spendingPace,
    required this.budgetHealth,
    required this.anomalies,
    required this.subscriptions,
    required this.upcomingObligations,
    required this.cashFlowForecast,
    required this.goals,
    required this.trendSummary,
    required this.budgetPlan,
    required this.categoryTrends,
    required this.merchantConcentration,
    required this.recurringCommitment,
    required this.cashFlowHealth,
    required this.netWorthTrend,
    required this.goalsDataAvailable,
    required this.summary,
  });

  final DateTime monthStart;
  final String currencyCode;
  final MonthlyOverview overview;
  final MonthlySafeToSpend safeToSpend;
  final List<MonthlySpendingPaceItem> spendingPace;
  final List<MonthlyBudgetHealthItem> budgetHealth;
  final List<MonthlyInsightItem> anomalies;
  final MonthlySubscriptionReport subscriptions;
  final List<MonthlyCashFlowItem> upcomingObligations;
  final List<MonthlyCashFlowPoint> cashFlowForecast;
  final List<MonthlyGoalReportItem> goals;
  final MonthlyTrendSummary trendSummary;
  final MonthlyBudgetPlanSummary budgetPlan;
  final List<MonthlyCategoryTrendItem> categoryTrends;
  final List<MonthlyMerchantSpendItem> merchantConcentration;
  final MonthlyRecurringCommitmentSummary recurringCommitment;
  final MonthlyCashFlowHealth cashFlowHealth;
  final MonthlyNetWorthTrend? netWorthTrend;
  final bool goalsDataAvailable;
  final String summary;
}

class MonthlyOverview {
  const MonthlyOverview({
    required this.income,
    required this.spending,
    required this.savings,
    required this.currentBalance,
    required this.forecastedBalance,
    required this.status,
  });

  final double income;
  final double spending;
  final double savings;
  final double currentBalance;
  final double forecastedBalance;
  final MonthlyReportStatus status;
}

class MonthlySafeToSpend {
  const MonthlySafeToSpend({
    required this.dailyAmount,
    required this.daysRemaining,
    required this.budgetRemaining,
    required this.futureIncome,
    required this.futureObligations,
  });

  final double dailyAmount;
  final int daysRemaining;
  final double budgetRemaining;
  final double futureIncome;
  final double futureObligations;
}

class MonthlySpendingPaceItem {
  const MonthlySpendingPaceItem({
    required this.label,
    required this.spentProgress,
    required this.timeProgress,
    required this.status,
    required this.insight,
    this.sourceTransactionIds = const <String>[],
  });

  final String label;
  final double spentProgress;
  final double timeProgress;
  final MonthlyReportStatus status;
  final String insight;
  final List<String> sourceTransactionIds;
}

class MonthlyBudgetHealthItem {
  const MonthlyBudgetHealthItem({
    required this.name,
    required this.status,
    required this.budgetAmount,
    required this.spent,
    required this.remaining,
    this.sourceTransactionIds = const <String>[],
  });

  final String name;
  final MonthlyReportStatus status;
  final double budgetAmount;
  final double spent;
  final double remaining;
  final List<String> sourceTransactionIds;
}

class MonthlyInsightItem {
  const MonthlyInsightItem({
    required this.title,
    required this.description,
    required this.status,
    this.categoryName,
    this.increasePercent,
    this.sourceTransactionIds = const <String>[],
  });

  final String title;
  final String description;
  final MonthlyReportStatus status;
  final String? categoryName;
  final int? increasePercent;
  final List<String> sourceTransactionIds;
}

class MonthlySubscriptionReport {
  const MonthlySubscriptionReport({
    required this.totalMonthlyAmount,
    required this.items,
  });

  final double totalMonthlyAmount;
  final List<MonthlySubscriptionItem> items;
}

class MonthlySubscriptionItem {
  const MonthlySubscriptionItem({
    required this.name,
    required this.amount,
    required this.nextDate,
    required this.status,
    required this.note,
    this.recurringId,
  });

  final String name;
  final double amount;
  final DateTime nextDate;
  final MonthlySubscriptionStatus status;
  final String note;
  final String? recurringId;
}

class MonthlyCashFlowItem {
  const MonthlyCashFlowItem({
    required this.date,
    required this.name,
    required this.amount,
    required this.type,
    this.sourceTransactionId,
    this.recurringId,
  });

  final DateTime date;
  final String name;
  final double amount;
  final String type;
  final String? sourceTransactionId;
  final String? recurringId;
}

class MonthlyCashFlowPoint {
  const MonthlyCashFlowPoint({
    required this.label,
    required this.balance,
    this.sourceTransactionId,
  });

  final String label;
  final double balance;
  final String? sourceTransactionId;
}

class MonthlyGoalReportItem {
  const MonthlyGoalReportItem({
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.progress,
    required this.monthlyNeeded,
    required this.status,
    this.id = '',
  });

  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final double progress;
  final double monthlyNeeded;
  final MonthlyReportStatus status;
}

class MonthlyTrendSummary {
  const MonthlyTrendSummary({
    required this.currentIncome,
    required this.previousIncome,
    required this.incomeChange,
    required this.incomeChangePercent,
    required this.currentSpending,
    required this.previousSpending,
    required this.spendingChange,
    required this.spendingChangePercent,
    required this.currentSavings,
    required this.previousSavings,
    required this.savingsRate,
    required this.previousSavingsRate,
    required this.netCashFlow,
  });

  final double currentIncome;
  final double previousIncome;
  final double incomeChange;
  final double? incomeChangePercent;
  final double currentSpending;
  final double previousSpending;
  final double spendingChange;
  final double? spendingChangePercent;
  final double currentSavings;
  final double previousSavings;
  final double savingsRate;
  final double previousSavingsRate;
  final double netCashFlow;
}

class MonthlyBudgetPlanSummary {
  const MonthlyBudgetPlanSummary({
    required this.totalBudgeted,
    required this.totalSpent,
    required this.totalRemaining,
    required this.overBudgetCount,
    required this.atRiskCount,
    required this.unbudgetedSpent,
    required this.budgetToIncomeRatio,
  });

  final double totalBudgeted;
  final double totalSpent;
  final double totalRemaining;
  final int overBudgetCount;
  final int atRiskCount;
  final double unbudgetedSpent;
  final double? budgetToIncomeRatio;
}

class MonthlyCategoryTrendItem {
  const MonthlyCategoryTrendItem({
    required this.name,
    required this.currentSpent,
    required this.previousSpent,
    required this.baselineAverageSpent,
    required this.previousChange,
    required this.previousChangePercent,
    required this.baselineChange,
    required this.baselineChangePercent,
    required this.status,
    required this.insight,
    this.sourceTransactionIds = const <String>[],
  });

  final String name;
  final double currentSpent;
  final double previousSpent;
  final double baselineAverageSpent;
  final double previousChange;
  final double? previousChangePercent;
  final double baselineChange;
  final double? baselineChangePercent;
  final MonthlyReportStatus status;
  final String insight;
  final List<String> sourceTransactionIds;
}

class MonthlyMerchantSpendItem {
  const MonthlyMerchantSpendItem({
    required this.name,
    required this.amount,
    required this.transactionCount,
    required this.spendingShare,
    this.sourceTransactionIds = const <String>[],
  });

  final String name;
  final double amount;
  final int transactionCount;
  final double spendingShare;
  final List<String> sourceTransactionIds;
}

class MonthlyRecurringCommitmentSummary {
  const MonthlyRecurringCommitmentSummary({
    required this.monthlyAmount,
    required this.incomeShare,
    required this.dueSoonAmount,
    required this.dueSoonCount,
    required this.status,
  });

  final double monthlyAmount;
  final double? incomeShare;
  final double dueSoonAmount;
  final int dueSoonCount;
  final MonthlyReportStatus status;
}

class MonthlyCashFlowHealth {
  const MonthlyCashFlowHealth({
    required this.lowWaterBalance,
    required this.lowWaterDate,
    required this.firstNegativeDate,
    required this.status,
  });

  final double lowWaterBalance;
  final DateTime? lowWaterDate;
  final DateTime? firstNegativeDate;
  final MonthlyReportStatus status;
}

class MonthlyNetWorthTrend {
  const MonthlyNetWorthTrend({
    required this.currentNetWorth,
    required this.previousNetWorth,
    required this.change,
    required this.changePercent,
  });

  final double currentNetWorth;
  final double previousNetWorth;
  final double change;
  final double? changePercent;
}

MonthlyFinancialReport buildMonthlyFinancialReport(
  MonthlyReportInput input, {
  AppLocalizations? l10n,
}) {
  final localizations = l10n ?? AppLocalizationsEn();
  final monthStart = _dateOnly(input.monthStart);
  final periodStart = _dateOnly(input.periodStart ?? monthStart);
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
  final periodEnd = _dateOnly(input.periodEnd ?? monthEnd);
  final today = _dateOnly(input.now);
  final timeProgress = _periodProgress(today, periodStart, periodEnd);
  final currentTransactions = input.currentMonthTransactions
      .where((tx) => _isInRange(tx.date, periodStart, periodEnd))
      .toList(growable: false);
  final previousComparableTransactions = input.compareMonthToDate
      ? _previousMonthToDateTransactions(
          input.previousMonthTransactions,
          today: today,
        )
      : input.previousMonthTransactions;
  final historicalComparableTransactions = input.compareMonthToDate
      ? _historicalMonthToDateTransactions(
          input.historicalTransactions,
          comparableDay: today.day,
        )
      : input.historicalTransactions;
  final income = _sumByType(currentTransactions, income: true);
  final spending = _sumByType(currentTransactions, income: false);
  final future = input.futureTransactions
      .where((tx) => tx.date.isAfter(today) && !tx.date.isAfter(periodEnd))
      .toList(growable: false)
    ..sort((a, b) => a.date.compareTo(b.date));
  final futureIncome = _sumByType(future, income: true);
  final futureObligations = _sumByType(future, income: false);
  final forecastedBalance = _roundMoney(
    input.currentBalance + futureIncome - futureObligations,
  );
  final budgetHealth = _buildBudgetHealth(
    input.budgetItems,
    currentTransactions,
    timeProgress,
  );
  final spendingPace = _buildSpendingPace(
    input.budgetItems,
    currentTransactions,
    timeProgress,
    l10n: localizations,
  );
  final trendSummary = _buildTrendSummary(
    currentTransactions: currentTransactions,
    previousComparableTransactions: previousComparableTransactions,
  );
  final budgetPlan = _buildBudgetPlan(
    budgets: input.budgetItems,
    transactions: currentTransactions,
    income: income,
  );
  final categoryTrends = _buildCategoryTrends(
    currentTransactions: currentTransactions,
    previousComparableTransactions: previousComparableTransactions,
    historicalComparableTransactions: historicalComparableTransactions,
    l10n: localizations,
  );
  final merchantConcentration =
      _buildMerchantConcentration(currentTransactions);
  final goalReports = _buildGoalReports(input.goals, input.now);
  final double budgetRemaining = input.budgetItems.isEmpty
      ? math.max(income - spending - futureObligations, 0)
      : input.budgetItems.fold<double>(
          0,
          (sum, item) => sum + math.max(item.budgetAmount - item.spent, 0),
        );
  final cashSafePool = math.max(forecastedBalance, 0);
  final constrainedPool = input.budgetItems.isEmpty
      ? cashSafePool
      : math.min(cashSafePool, budgetRemaining);
  final daysRemaining = math.max(periodEnd.difference(today).inDays, 1);
  final safeToSpend = MonthlySafeToSpend(
    dailyAmount: _roundMoney(constrainedPool / daysRemaining),
    daysRemaining: daysRemaining,
    budgetRemaining: _roundMoney(budgetRemaining),
    futureIncome: _roundMoney(futureIncome),
    futureObligations: _roundMoney(futureObligations),
  );
  final upcomingObligations = future
      .map(
        (tx) => MonthlyCashFlowItem(
          date: tx.date,
          name: _cashFlowName(tx),
          amount: tx.amount.abs(),
          type: tx.type.toLowerCase() == 'income' ? 'income' : 'expense',
          sourceTransactionId: tx.id,
        ),
      )
      .toList(growable: false);
  final cashFlowForecast = _buildCashFlowForecast(
    currentBalance: input.currentBalance,
    forecastedBalance: forecastedBalance,
    futureTransactions: future,
    l10n: localizations,
  );
  final cashFlowHealth = _buildCashFlowHealth(
    currentBalance: input.currentBalance,
    futureTransactions: future,
    today: today,
  );
  final anomalies = _buildAnomalies(
    currentTransactions: currentTransactions,
    previousTransactions: previousComparableTransactions,
    l10n: localizations,
  );
  final subscriptions = _buildSubscriptions(
    input.recurringItems,
    input.now,
    l10n: localizations,
  );
  final recurringCommitment = _buildRecurringCommitment(
    subscriptions: subscriptions,
    income: income,
    now: input.now,
  );
  final netWorthTrend = _buildNetWorthTrend(
    currentNetWorth: input.currentBalance,
    previousNetWorth: input.previousNetWorth,
  );
  final overviewStatus = _overviewStatus(
    budgetHealth: budgetHealth,
    anomalies: anomalies,
    safeToSpend: safeToSpend.dailyAmount,
    savings: income - spending,
  );

  return MonthlyFinancialReport(
    monthStart: monthStart,
    currencyCode: input.currencyCode,
    overview: MonthlyOverview(
      income: _roundMoney(income),
      spending: _roundMoney(spending),
      savings: _roundMoney(income - spending),
      currentBalance: _roundMoney(input.currentBalance),
      forecastedBalance: forecastedBalance,
      status: overviewStatus,
    ),
    safeToSpend: safeToSpend,
    spendingPace: spendingPace,
    budgetHealth: budgetHealth,
    anomalies: anomalies,
    subscriptions: subscriptions,
    upcomingObligations: upcomingObligations,
    cashFlowForecast: cashFlowForecast,
    goals: goalReports,
    trendSummary: trendSummary,
    budgetPlan: budgetPlan,
    categoryTrends: categoryTrends,
    merchantConcentration: merchantConcentration,
    recurringCommitment: recurringCommitment,
    cashFlowHealth: cashFlowHealth,
    netWorthTrend: netWorthTrend,
    goalsDataAvailable: input.goalsDataAvailable,
    summary: _buildSummary(
      status: overviewStatus,
      safeToSpend: safeToSpend.dailyAmount,
      forecastedBalance: forecastedBalance,
      budgetHealth: budgetHealth,
      anomalies: anomalies,
      currencyCode: input.currencyCode,
      l10n: localizations,
    ),
  );
}

List<MonthlyBudgetHealthItem> _buildBudgetHealth(
  List<MonthlyReportBudgetInput> budgets,
  List<MonthlyReportTransactionInput> currentTransactions,
  double timeProgress,
) {
  final items = budgets
      .where((item) => item.budgetAmount > 0 || item.spent > 0)
      .map((item) {
    final progress =
        item.budgetAmount <= 0 ? 1.0 : item.spent / item.budgetAmount;
    final status = _budgetStatus(
      spent: item.spent,
      budget: item.budgetAmount,
      progress: progress,
      timeProgress: timeProgress,
    );
    return MonthlyBudgetHealthItem(
      name: item.name,
      status: status,
      budgetAmount: _roundMoney(item.budgetAmount),
      spent: _roundMoney(item.spent),
      remaining: _roundMoney(item.budgetAmount - item.spent),
      sourceTransactionIds: _transactionIdsForCategory(
        currentTransactions,
        item.name,
      ),
    );
  }).toList(growable: false);

  return items
    ..sort((a, b) {
      final severity =
          _statusSeverity(b.status).compareTo(_statusSeverity(a.status));
      if (severity != 0) return severity;
      return b.spent.compareTo(a.spent);
    });
}

List<MonthlySpendingPaceItem> _buildSpendingPace(
  List<MonthlyReportBudgetInput> budgets,
  List<MonthlyReportTransactionInput> currentTransactions,
  double timeProgress, {
  required AppLocalizations l10n,
}) {
  return budgets.where((item) => item.budgetAmount > 0).map((item) {
    final spentProgress = (item.spent / item.budgetAmount).clamp(0.0, 1.5);
    final status = _budgetStatus(
      spent: item.spent,
      budget: item.budgetAmount,
      progress: spentProgress,
      timeProgress: timeProgress,
    );
    return MonthlySpendingPaceItem(
      label: item.name,
      spentProgress: spentProgress,
      timeProgress: timeProgress,
      status: status,
      insight: _paceInsight(
        item.name,
        spentProgress,
        timeProgress,
        status,
        l10n,
      ),
      sourceTransactionIds: _transactionIdsForCategory(
        currentTransactions,
        item.name,
      ),
    );
  }).toList(growable: false)
    ..sort((a, b) => (b.spentProgress - b.timeProgress)
        .compareTo(a.spentProgress - a.timeProgress));
}

List<MonthlyInsightItem> _buildAnomalies({
  required List<MonthlyReportTransactionInput> currentTransactions,
  required List<MonthlyReportTransactionInput> previousTransactions,
  required AppLocalizations l10n,
}) {
  final currentByCategory = _expenseTotalsByCategory(currentTransactions);
  final previousByCategory = _expenseTotalsByCategory(previousTransactions);
  final anomalies = <MonthlyInsightItem>[];

  for (final entry in currentByCategory.entries) {
    final previous = previousByCategory[entry.key] ?? 0;
    if (previous <= 0 || entry.value < 50) continue;
    final increaseRatio = (entry.value - previous) / previous;
    if (increaseRatio < 0.35) continue;
    final categoryName = _titleCase(entry.key);
    final increasePercent = (increaseRatio * 100).round();
    anomalies.add(
      MonthlyInsightItem(
        title: categoryName,
        description: l10n.categoryPercentChangeThanComparator(
          categoryName,
          l10n.lastMonth,
          l10n.higher,
          increasePercent,
        ),
        status: MonthlyReportStatus.unusualSpending,
        categoryName: categoryName,
        increasePercent: increasePercent,
        sourceTransactionIds: _transactionIdsForCategory(
          currentTransactions,
          categoryName,
        ),
      ),
    );
  }

  anomalies.sort((a, b) => a.title.compareTo(b.title));
  return anomalies.take(5).toList(growable: false);
}

MonthlySubscriptionReport _buildSubscriptions(
  List<MonthlyReportRecurringInput> recurringItems,
  DateTime now, {
  required AppLocalizations l10n,
}) {
  final expenses = recurringItems
      .where((item) => item.type.toLowerCase() != 'income' && item.amount > 0)
      .toList(growable: false)
    ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
  final countByName = <String, int>{};
  for (final item in expenses) {
    final key = _normalizedName(item.name);
    countByName[key] = (countByName[key] ?? 0) + 1;
  }

  final items = expenses.map((item) {
    final duplicate = (countByName[_normalizedName(item.name)] ?? 0) > 1;
    final priceIncreased = item.previousAmount != null &&
        item.previousAmount! > 0 &&
        item.amount > item.previousAmount! * 1.1;
    final daysUntil =
        _dateOnly(item.nextDate).difference(_dateOnly(now)).inDays;
    final status = duplicate
        ? MonthlySubscriptionStatus.duplicatePossible
        : priceIncreased
            ? MonthlySubscriptionStatus.priceIncrease
            : daysUntil <= 14
                ? MonthlySubscriptionStatus.upcoming
                : MonthlySubscriptionStatus.active;
    return MonthlySubscriptionItem(
      name: item.name,
      amount: _roundMoney(item.amount),
      nextDate: item.nextDate,
      status: status,
      note: _subscriptionNote(
        status,
        daysUntil,
        item.previousAmount,
        item.amount,
        l10n,
      ),
      recurringId: item.id,
    );
  }).toList(growable: false)
    ..sort((a, b) {
      final byStatus = _subscriptionSeverity(b.status)
          .compareTo(_subscriptionSeverity(a.status));
      if (byStatus != 0) return byStatus;
      return a.nextDate.compareTo(b.nextDate);
    });

  return MonthlySubscriptionReport(
    totalMonthlyAmount:
        _roundMoney(items.fold<double>(0, (sum, item) => sum + item.amount)),
    items: items,
  );
}

int _subscriptionSeverity(MonthlySubscriptionStatus status) {
  switch (status) {
    case MonthlySubscriptionStatus.duplicatePossible:
      return 3;
    case MonthlySubscriptionStatus.priceIncrease:
      return 2;
    case MonthlySubscriptionStatus.upcoming:
      return 1;
    case MonthlySubscriptionStatus.active:
      return 0;
  }
}

List<MonthlyCashFlowPoint> _buildCashFlowForecast({
  required double currentBalance,
  required double forecastedBalance,
  required List<MonthlyReportTransactionInput> futureTransactions,
  required AppLocalizations l10n,
}) {
  var running = currentBalance;
  final points = <MonthlyCashFlowPoint>[
    MonthlyCashFlowPoint(label: l10n.today, balance: _roundMoney(running)),
  ];
  for (final tx in futureTransactions.take(6)) {
    running +=
        tx.type.toLowerCase() == 'income' ? tx.amount.abs() : -tx.amount.abs();
    points.add(
      MonthlyCashFlowPoint(
        label: _cashFlowName(tx),
        balance: _roundMoney(running),
        sourceTransactionId: tx.id,
      ),
    );
  }
  points.add(
    MonthlyCashFlowPoint(label: l10n.monthEndBuffer, balance: forecastedBalance),
  );
  return points;
}

List<MonthlyGoalReportItem> _buildGoalReports(
  List<MonthlyReportGoalInput> goals,
  DateTime now,
) {
  return goals.map((goal) {
    final progress = goal.targetAmount <= 0
        ? 0.0
        : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final targetDate = DateTime.tryParse(goal.targetDate);
    final monthsRemaining = targetDate == null
        ? 1
        : math.max(
            ((targetDate.year - now.year) * 12) + targetDate.month - now.month,
            1,
          );
    final double monthlyNeeded = math.max(
      (goal.targetAmount - goal.currentAmount) / monthsRemaining,
      0,
    );
    return MonthlyGoalReportItem(
      id: goal.id,
      title: goal.title,
      targetAmount: _roundMoney(goal.targetAmount),
      currentAmount: _roundMoney(goal.currentAmount),
      progress: progress,
      monthlyNeeded: _roundMoney(monthlyNeeded),
      status: goal.isOnTrack
          ? MonthlyReportStatus.onTrack
          : MonthlyReportStatus.needsAttention,
    );
  }).toList(growable: false)
    ..sort((a, b) => a.progress.compareTo(b.progress));
}

MonthlyTrendSummary _buildTrendSummary({
  required List<MonthlyReportTransactionInput> currentTransactions,
  required List<MonthlyReportTransactionInput> previousComparableTransactions,
}) {
  final currentIncome = _sumByType(currentTransactions, income: true);
  final previousIncome =
      _sumByType(previousComparableTransactions, income: true);
  final currentSpending = _sumByType(currentTransactions, income: false);
  final previousSpending =
      _sumByType(previousComparableTransactions, income: false);
  final currentSavings = currentIncome - currentSpending;
  final previousSavings = previousIncome - previousSpending;

  return MonthlyTrendSummary(
    currentIncome: _roundMoney(currentIncome),
    previousIncome: _roundMoney(previousIncome),
    incomeChange: _roundMoney(currentIncome - previousIncome),
    incomeChangePercent: _percentChange(currentIncome, previousIncome),
    currentSpending: _roundMoney(currentSpending),
    previousSpending: _roundMoney(previousSpending),
    spendingChange: _roundMoney(currentSpending - previousSpending),
    spendingChangePercent: _percentChange(currentSpending, previousSpending),
    currentSavings: _roundMoney(currentSavings),
    previousSavings: _roundMoney(previousSavings),
    savingsRate: _savingsRate(currentIncome, currentSpending),
    previousSavingsRate: _savingsRate(previousIncome, previousSpending),
    netCashFlow: _roundMoney(currentSavings),
  );
}

MonthlyBudgetPlanSummary _buildBudgetPlan({
  required List<MonthlyReportBudgetInput> budgets,
  required List<MonthlyReportTransactionInput> transactions,
  required double income,
}) {
  final expenseTransactions = transactions.where(_isExpenseTransaction);
  final totalBudgeted =
      budgets.fold<double>(0, (sum, item) => sum + item.budgetAmount);
  final totalSpent =
      expenseTransactions.fold<double>(0, (sum, tx) => sum + tx.amount.abs());
  final budgetNames = budgets.map((item) => _normalizedName(item.name)).toSet();
  final unbudgetedSpent = expenseTransactions.where((tx) {
    return !budgetNames.contains(_normalizedName(tx.category));
  }).fold<double>(0, (sum, tx) => sum + tx.amount.abs());
  var overBudgetCount = 0;
  var atRiskCount = 0;
  for (final item in budgets) {
    if (item.budgetAmount <= 0 && item.spent <= 0) continue;
    if (item.budgetAmount > 0 && item.spent > item.budgetAmount) {
      overBudgetCount++;
    } else if (item.budgetAmount > 0 &&
        item.spent >= item.budgetAmount * 0.85) {
      atRiskCount++;
    }
  }

  return MonthlyBudgetPlanSummary(
    totalBudgeted: _roundMoney(totalBudgeted),
    totalSpent: _roundMoney(totalSpent),
    totalRemaining: _roundMoney(totalBudgeted - totalSpent),
    overBudgetCount: overBudgetCount,
    atRiskCount: atRiskCount,
    unbudgetedSpent: _roundMoney(unbudgetedSpent),
    budgetToIncomeRatio:
        income <= 0 ? null : _roundRatio(totalBudgeted / income),
  );
}

List<MonthlyCategoryTrendItem> _buildCategoryTrends({
  required List<MonthlyReportTransactionInput> currentTransactions,
  required List<MonthlyReportTransactionInput> previousComparableTransactions,
  required List<MonthlyReportTransactionInput> historicalComparableTransactions,
  required AppLocalizations l10n,
}) {
  final currentByCategory = _expenseTotalsByCategory(currentTransactions);
  final previousByCategory =
      _expenseTotalsByCategory(previousComparableTransactions);
  final historicalAverages =
      _expenseMonthlyAveragesByCategory(historicalComparableTransactions);
  final items = <MonthlyCategoryTrendItem>[];

  for (final entry in currentByCategory.entries) {
    final previous = previousByCategory[entry.key] ?? 0;
    final baseline = historicalAverages[entry.key] ?? 0;
    final previousChange = entry.value - previous;
    final baselineChange = baseline <= 0 ? 0.0 : entry.value - baseline;
    final previousChangePercent = _percentChange(entry.value, previous);
    final baselineChangePercent =
        baseline <= 0 ? null : _percentChange(entry.value, baseline);
    final hasComparison = previous > 0 || baseline > 0;
    final isMeaningful = entry.value >= 50 &&
        (previousChange.abs() >= 50 ||
            baselineChange.abs() >= 50 ||
            (previousChangePercent?.abs() ?? 0) >= 0.25 ||
            (baselineChangePercent?.abs() ?? 0) >= 0.25);
    if (!hasComparison || !isMeaningful) continue;

    final strongestPercent = (baselineChangePercent?.abs() ?? 0) >
            (previousChangePercent?.abs() ?? 0)
        ? baselineChangePercent
        : previousChangePercent;
    final status = (strongestPercent ?? 0) > 0
        ? MonthlyReportStatus.unusualSpending
        : MonthlyReportStatus.onTrack;
    items.add(
      MonthlyCategoryTrendItem(
        name: _titleCase(entry.key),
        currentSpent: _roundMoney(entry.value),
        previousSpent: _roundMoney(previous),
        baselineAverageSpent: _roundMoney(baseline),
        previousChange: _roundMoney(previousChange),
        previousChangePercent: previousChangePercent,
        baselineChange: _roundMoney(baselineChange),
        baselineChangePercent: baselineChangePercent,
        status: status,
        insight: _categoryTrendInsight(
          _titleCase(entry.key),
          previousChangePercent,
          baselineChangePercent,
          previousChange,
          baselineChange,
          l10n,
        ),
        sourceTransactionIds: _transactionIdsForCategory(
          currentTransactions,
          _titleCase(entry.key),
        ),
      ),
    );
  }

  items.sort((a, b) {
    final aMagnitude = math.max(a.previousChange.abs(), a.baselineChange.abs());
    final bMagnitude = math.max(b.previousChange.abs(), b.baselineChange.abs());
    return bMagnitude.compareTo(aMagnitude);
  });
  return items.take(6).toList(growable: false);
}

List<MonthlyMerchantSpendItem> _buildMerchantConcentration(
  List<MonthlyReportTransactionInput> transactions,
) {
  final expenses = transactions.where(_isExpenseTransaction).toList();
  final totalSpending =
      expenses.fold<double>(0, (sum, tx) => sum + tx.amount.abs());
  if (totalSpending <= 0) return const [];

  final totals = <String, double>{};
  final counts = <String, int>{};
  final displayNames = <String, String>{};
  final sourceIds = <String, List<String>>{};
  for (final tx in expenses) {
    final rawName = (tx.merchant ?? '').trim();
    if (rawName.isEmpty) continue;
    final key = _normalizedName(rawName);
    totals[key] = (totals[key] ?? 0) + tx.amount.abs();
    counts[key] = (counts[key] ?? 0) + 1;
    displayNames[key] = rawName;
    sourceIds.putIfAbsent(key, () => <String>[]).add(tx.id);
  }

  final items = totals.entries.map((entry) {
    return MonthlyMerchantSpendItem(
      name: displayNames[entry.key] ?? _titleCase(entry.key),
      amount: _roundMoney(entry.value),
      transactionCount: counts[entry.key] ?? 0,
      spendingShare: _roundRatio(entry.value / totalSpending),
      sourceTransactionIds: sourceIds[entry.key] ?? const <String>[],
    );
  }).toList(growable: false);

  items.sort((a, b) {
    final byAmount = b.amount.compareTo(a.amount);
    if (byAmount != 0) return byAmount;
    return a.name.compareTo(b.name);
  });
  return items.take(5).toList(growable: false);
}

MonthlyRecurringCommitmentSummary _buildRecurringCommitment({
  required MonthlySubscriptionReport subscriptions,
  required double income,
  required DateTime now,
}) {
  final today = _dateOnly(now);
  var dueSoonAmount = 0.0;
  var dueSoonCount = 0;
  for (final item in subscriptions.items) {
    final daysUntil = _dateOnly(item.nextDate).difference(today).inDays;
    if (daysUntil >= 0 && daysUntil <= 14) {
      dueSoonAmount += item.amount;
      dueSoonCount++;
    }
  }
  final incomeShare = income <= 0
      ? null
      : _roundRatio(subscriptions.totalMonthlyAmount / income);
  final status = subscriptions.totalMonthlyAmount <= 0
      ? MonthlyReportStatus.onTrack
      : incomeShare == null
          ? MonthlyReportStatus.needsAttention
          : incomeShare >= 0.5
              ? MonthlyReportStatus.needsAttention
              : incomeShare >= 0.3
                  ? MonthlyReportStatus.spendingFast
                  : MonthlyReportStatus.onTrack;

  return MonthlyRecurringCommitmentSummary(
    monthlyAmount: subscriptions.totalMonthlyAmount,
    incomeShare: incomeShare,
    dueSoonAmount: _roundMoney(dueSoonAmount),
    dueSoonCount: dueSoonCount,
    status: status,
  );
}

MonthlyCashFlowHealth _buildCashFlowHealth({
  required double currentBalance,
  required List<MonthlyReportTransactionInput> futureTransactions,
  required DateTime today,
}) {
  var running = currentBalance;
  var lowWaterBalance = currentBalance;
  DateTime? lowWaterDate = today;
  DateTime? firstNegativeDate;

  for (final tx in futureTransactions) {
    running +=
        tx.type.toLowerCase() == 'income' ? tx.amount.abs() : -tx.amount.abs();
    if (running < lowWaterBalance) {
      lowWaterBalance = running;
      lowWaterDate = _dateOnly(tx.date);
    }
    if (running < 0 && firstNegativeDate == null) {
      firstNegativeDate = _dateOnly(tx.date);
    }
  }

  return MonthlyCashFlowHealth(
    lowWaterBalance: _roundMoney(lowWaterBalance),
    lowWaterDate: lowWaterDate,
    firstNegativeDate: firstNegativeDate,
    status: firstNegativeDate != null
        ? MonthlyReportStatus.needsAttention
        : MonthlyReportStatus.onTrack,
  );
}

MonthlyNetWorthTrend? _buildNetWorthTrend({
  required double currentNetWorth,
  required double? previousNetWorth,
}) {
  if (previousNetWorth == null) return null;
  final change = currentNetWorth - previousNetWorth;
  return MonthlyNetWorthTrend(
    currentNetWorth: _roundMoney(currentNetWorth),
    previousNetWorth: _roundMoney(previousNetWorth),
    change: _roundMoney(change),
    changePercent: previousNetWorth == 0
        ? null
        : _roundRatio(change / previousNetWorth.abs()),
  );
}

List<MonthlyReportTransactionInput> _previousMonthToDateTransactions(
  List<MonthlyReportTransactionInput> transactions, {
  required DateTime today,
}) {
  final previousMonthEnd = DateTime(today.year, today.month, 0);
  final comparableDay = math.min(today.day, previousMonthEnd.day);
  return transactions
      .where((tx) => _dateOnly(tx.date).day <= comparableDay)
      .toList(growable: false);
}

List<MonthlyReportTransactionInput> _historicalMonthToDateTransactions(
  List<MonthlyReportTransactionInput> transactions, {
  required int comparableDay,
}) {
  return transactions
      .where((tx) => _dateOnly(tx.date).day <= comparableDay)
      .toList(growable: false);
}

Map<String, double> _expenseMonthlyAveragesByCategory(
  List<MonthlyReportTransactionInput> transactions,
) {
  final totalsByMonthAndCategory = <String, Map<String, double>>{};
  for (final tx in transactions) {
    if (!_isExpenseTransaction(tx)) continue;
    final monthKey = '${tx.date.year}-${tx.date.month}';
    final category = _normalizedName(
      tx.category.isEmpty ? 'Uncategorized' : tx.category,
    );
    final monthTotals = totalsByMonthAndCategory.putIfAbsent(
        monthKey, () => <String, double>{});
    monthTotals[category] = (monthTotals[category] ?? 0) + tx.amount.abs();
  }
  final categorySums = <String, double>{};
  final categoryMonthCounts = <String, int>{};
  for (final monthTotals in totalsByMonthAndCategory.values) {
    for (final entry in monthTotals.entries) {
      categorySums[entry.key] = (categorySums[entry.key] ?? 0) + entry.value;
      categoryMonthCounts[entry.key] =
          (categoryMonthCounts[entry.key] ?? 0) + 1;
    }
  }
  return <String, double>{
    for (final entry in categorySums.entries)
      entry.key: entry.value / (categoryMonthCounts[entry.key] ?? 1),
  };
}

bool _isExpenseTransaction(MonthlyReportTransactionInput tx) =>
    tx.type.toLowerCase() != 'income';

double _savingsRate(double income, double spending) {
  if (income <= 0) return 0;
  return _roundRatio(((income - spending) / income).clamp(-1.0, 1.0));
}

double? _percentChange(double current, double previous) {
  if (previous <= 0) return null;
  return _roundRatio((current - previous) / previous);
}

double _roundRatio(double value) => (value * 1000).roundToDouble() / 1000;

String _categoryTrendInsight(
  String category,
  double? previousPercent,
  double? baselinePercent,
  double previousChange,
  double baselineChange,
  AppLocalizations l10n,
) {
  final useBaseline =
      (baselinePercent?.abs() ?? 0) > (previousPercent?.abs() ?? 0);
  final percent = useBaseline ? baselinePercent : previousPercent;
  final change = useBaseline ? baselineChange : previousChange;
  final comparator =
      useBaseline ? l10n.recentAverage : l10n.samePointLastMonth;
  if (percent == null) {
    final direction = change >= 0 ? l10n.higher : l10n.lower;
    return l10n.categoryChangeThanComparator(
      category,
      change.abs().toStringAsFixed(2),
      comparator,
      direction,
    );
  }
  final direction = percent >= 0 ? l10n.higher : l10n.lower;
  return l10n.categoryPercentChangeThanComparator(
    category,
    comparator,
    direction,
    (percent.abs() * 100).round(),
  );
}

MonthlyReportStatus _budgetStatus({
  required double spent,
  required double budget,
  required double progress,
  required double timeProgress,
}) {
  if (budget <= 0 && spent > 0) return MonthlyReportStatus.needsAttention;
  if (budget > 0 && spent > budget) return MonthlyReportStatus.overBudget;
  if (progress >= 0.85 || progress > timeProgress + 0.2) {
    return MonthlyReportStatus.spendingFast;
  }
  if (progress <= timeProgress + 0.1) return MonthlyReportStatus.onTrack;
  return MonthlyReportStatus.needsAttention;
}

MonthlyReportStatus _overviewStatus({
  required List<MonthlyBudgetHealthItem> budgetHealth,
  required List<MonthlyInsightItem> anomalies,
  required double safeToSpend,
  required double savings,
}) {
  if (budgetHealth
      .any((item) => item.status == MonthlyReportStatus.overBudget)) {
    return MonthlyReportStatus.overBudget;
  }
  if (anomalies.isNotEmpty) return MonthlyReportStatus.unusualSpending;
  if (safeToSpend <= 0 || savings < 0) {
    return MonthlyReportStatus.needsAttention;
  }
  if (budgetHealth
      .any((item) => item.status == MonthlyReportStatus.spendingFast)) {
    return MonthlyReportStatus.spendingFast;
  }
  return MonthlyReportStatus.onTrack;
}

String _buildSummary({
  required MonthlyReportStatus status,
  required double safeToSpend,
  required double forecastedBalance,
  required List<MonthlyBudgetHealthItem> budgetHealth,
  required List<MonthlyInsightItem> anomalies,
  required String currencyCode,
  required AppLocalizations l10n,
}) {
  final watchItems = budgetHealth
      .where((item) => item.status != MonthlyReportStatus.onTrack)
      .map((item) => item.name.toLowerCase())
      .take(2)
      .join(' ${l10n.and} ');
  final statusText = monthlyReportStatusLabel(status, l10n: l10n).toLowerCase();
  final safeToSpendText = safeToSpend.toStringAsFixed(2);
  final forecastedBalanceText = forecastedBalance.toStringAsFixed(2);
  if (watchItems.isNotEmpty) {
    return l10n.monthlyReportSummaryWatch(
      currencyCode,
      forecastedBalanceText,
      safeToSpendText,
      statusText,
      watchItems,
    );
  }
  if (anomalies.isNotEmpty) {
    return l10n.monthlyReportSummaryReview(
      currencyCode,
      forecastedBalanceText,
      safeToSpendText,
      statusText,
    );
  }
  return l10n.monthlyReportSummaryKeep(
    currencyCode,
    forecastedBalanceText,
    safeToSpendText,
    statusText,
  );
}

Map<String, double> _expenseTotalsByCategory(
  List<MonthlyReportTransactionInput> transactions,
) {
  final totals = <String, double>{};
  for (final tx in transactions) {
    if (tx.type.toLowerCase() == 'income') continue;
    final category =
        _normalizedName(tx.category.isEmpty ? 'Uncategorized' : tx.category);
    totals[category] = (totals[category] ?? 0) + tx.amount.abs();
  }
  return totals;
}

double _sumByType(
  List<MonthlyReportTransactionInput> transactions, {
  required bool income,
}) {
  return transactions.where((tx) {
    final isIncome = tx.type.toLowerCase() == 'income';
    return income ? isIncome : !isIncome;
  }).fold<double>(0, (sum, tx) => sum + tx.amount.abs());
}

double _periodProgress(DateTime today, DateTime start, DateTime end) {
  if (today.isBefore(start)) return 0;
  if (today.isAfter(end)) return 1;
  final totalDays = math.max(end.difference(start).inDays + 1, 1);
  final elapsedDays = math.max(today.difference(start).inDays + 1, 0);
  return (elapsedDays / totalDays).clamp(0.0, 1.0);
}

bool _isInRange(DateTime value, DateTime start, DateTime end) {
  final day = _dateOnly(value);
  return !day.isBefore(start) && !day.isAfter(end);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

double _roundMoney(double value) => (value * 100).roundToDouble() / 100;

int _statusSeverity(MonthlyReportStatus status) {
  switch (status) {
    case MonthlyReportStatus.overBudget:
      return 5;
    case MonthlyReportStatus.unusualSpending:
      return 4;
    case MonthlyReportStatus.spendingFast:
      return 3;
    case MonthlyReportStatus.needsAttention:
      return 2;
    case MonthlyReportStatus.safeToSpend:
      return 1;
    case MonthlyReportStatus.onTrack:
      return 0;
  }
}

String _paceInsight(
  String name,
  double spentProgress,
  double timeProgress,
  MonthlyReportStatus status,
  AppLocalizations l10n,
) {
  final spentPct = (spentProgress * 100).round();
  final timePct = (timeProgress * 100).round();
  switch (status) {
    case MonthlyReportStatus.overBudget:
      return l10n.budgetPaceOverBudget(name);
    case MonthlyReportStatus.spendingFast:
      return l10n.budgetPaceSpendingFast(name, spentPct, timePct);
    case MonthlyReportStatus.needsAttention:
      return l10n.budgetPaceNeedsAttention(name);
    default:
      return l10n.budgetPaceOnTrack(name);
  }
}

String _subscriptionNote(
  MonthlySubscriptionStatus status,
  int daysUntil,
  double? previousAmount,
  double amount,
  AppLocalizations l10n,
) {
  switch (status) {
    case MonthlySubscriptionStatus.duplicatePossible:
      return l10n.duplicates;
    case MonthlySubscriptionStatus.priceIncrease:
      return l10n.amountFromLastSnapshot(
        '${previousAmount!.toStringAsFixed(2)} -> ${amount.toStringAsFixed(2)}',
      );
    case MonthlySubscriptionStatus.upcoming:
      return daysUntil <= 0 ? l10n.today : l10n.renewsInDays(daysUntil);
    case MonthlySubscriptionStatus.active:
      return l10n.active;
  }
}

String _cashFlowName(MonthlyReportTransactionInput tx) {
  final merchant = tx.merchant?.trim();
  if (merchant != null && merchant.isNotEmpty) return merchant;
  final category = tx.category.trim();
  return category.isEmpty ? _titleCase(tx.type) : _titleCase(category);
}

List<String> _transactionIdsForCategory(
  List<MonthlyReportTransactionInput> transactions,
  String category,
) {
  final normalizedCategory = _normalizedName(category);
  return transactions
      .where(_isExpenseTransaction)
      .where((tx) => _normalizedName(tx.category) == normalizedCategory)
      .map((tx) => tx.id)
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
}

String _normalizedName(String value) => value.trim().toLowerCase();

String _titleCase(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

String monthlyReportStatusLabel(
  MonthlyReportStatus status, {
  AppLocalizations? l10n,
}) {
  final localizations = l10n ?? AppLocalizationsEn();
  switch (status) {
    case MonthlyReportStatus.onTrack:
      return localizations.onTrack;
    case MonthlyReportStatus.spendingFast:
      return localizations.spending;
    case MonthlyReportStatus.overBudget:
      return localizations.overBudget;
    case MonthlyReportStatus.safeToSpend:
      return localizations.safeToSpend;
    case MonthlyReportStatus.needsAttention:
      return localizations.needsAttention;
    case MonthlyReportStatus.unusualSpending:
      return localizations.unusualActivity;
  }
}

String monthlySubscriptionStatusLabel(
  MonthlySubscriptionStatus status, {
  AppLocalizations? l10n,
}) {
  final localizations = l10n ?? AppLocalizationsEn();
  switch (status) {
    case MonthlySubscriptionStatus.active:
      return localizations.active;
    case MonthlySubscriptionStatus.upcoming:
      return localizations.scheduled;
    case MonthlySubscriptionStatus.priceIncrease:
      return localizations.patternsChanged;
    case MonthlySubscriptionStatus.duplicatePossible:
      return localizations.duplicates;
  }
}
