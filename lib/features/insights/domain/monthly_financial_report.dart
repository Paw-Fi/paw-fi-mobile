import 'dart:math' as math;

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
  });

  final DateTime monthStart;
  final DateTime now;
  final String currencyCode;
  final double currentBalance;
  final List<MonthlyReportTransactionInput> currentMonthTransactions;
  final List<MonthlyReportTransactionInput> previousMonthTransactions;
  final List<MonthlyReportBudgetInput> budgetItems;
  final List<MonthlyReportTransactionInput> futureTransactions;
  final List<MonthlyReportRecurringInput> recurringItems;
  final List<MonthlyReportGoalInput> goals;
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
  });

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
  });

  final String label;
  final double spentProgress;
  final double timeProgress;
  final MonthlyReportStatus status;
  final String insight;
}

class MonthlyBudgetHealthItem {
  const MonthlyBudgetHealthItem({
    required this.name,
    required this.status,
    required this.budgetAmount,
    required this.spent,
    required this.remaining,
  });

  final String name;
  final MonthlyReportStatus status;
  final double budgetAmount;
  final double spent;
  final double remaining;
}

class MonthlyInsightItem {
  const MonthlyInsightItem({
    required this.title,
    required this.description,
    required this.status,
  });

  final String title;
  final String description;
  final MonthlyReportStatus status;
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
  });

  final String name;
  final double amount;
  final DateTime nextDate;
  final MonthlySubscriptionStatus status;
  final String note;
}

class MonthlyCashFlowItem {
  const MonthlyCashFlowItem({
    required this.date,
    required this.name,
    required this.amount,
    required this.type,
  });

  final DateTime date;
  final String name;
  final double amount;
  final String type;
}

class MonthlyCashFlowPoint {
  const MonthlyCashFlowPoint({
    required this.label,
    required this.balance,
  });

  final String label;
  final double balance;
}

class MonthlyGoalReportItem {
  const MonthlyGoalReportItem({
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.progress,
    required this.monthlyNeeded,
    required this.status,
  });

  final String title;
  final double targetAmount;
  final double currentAmount;
  final double progress;
  final double monthlyNeeded;
  final MonthlyReportStatus status;
}

MonthlyFinancialReport buildMonthlyFinancialReport(MonthlyReportInput input) {
  final monthStart = _dateOnly(input.monthStart);
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
  final today = _dateOnly(input.now);
  final timeProgress = _monthProgress(today, monthStart, monthEnd);
  final currentTransactions = input.currentMonthTransactions
      .where((tx) => _isInRange(tx.date, monthStart, monthEnd))
      .toList(growable: false);
  final income = _sumByType(currentTransactions, income: true);
  final spending = _sumByType(currentTransactions, income: false);
  final future = input.futureTransactions
      .where((tx) => tx.date.isAfter(today) && !tx.date.isAfter(monthEnd))
      .toList(growable: false)
    ..sort((a, b) => a.date.compareTo(b.date));
  final futureIncome = _sumByType(future, income: true);
  final futureObligations = _sumByType(future, income: false);
  final forecastedBalance = _roundMoney(
    input.currentBalance + futureIncome - futureObligations,
  );
  final budgetHealth = _buildBudgetHealth(input.budgetItems, timeProgress);
  final spendingPace = _buildSpendingPace(input.budgetItems, timeProgress);
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
  final daysRemaining = math.max(monthEnd.difference(today).inDays, 1);
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
        ),
      )
      .toList(growable: false);
  final cashFlowForecast = _buildCashFlowForecast(
    currentBalance: input.currentBalance,
    forecastedBalance: forecastedBalance,
    futureTransactions: future,
  );
  final anomalies = _buildAnomalies(
    currentTransactions: currentTransactions,
    previousTransactions: input.previousMonthTransactions,
  );
  final subscriptions = _buildSubscriptions(input.recurringItems, input.now);
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
    summary: _buildSummary(
      status: overviewStatus,
      safeToSpend: safeToSpend.dailyAmount,
      forecastedBalance: forecastedBalance,
      budgetHealth: budgetHealth,
      anomalies: anomalies,
      currencyCode: input.currencyCode,
    ),
  );
}

List<MonthlyBudgetHealthItem> _buildBudgetHealth(
  List<MonthlyReportBudgetInput> budgets,
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
  double timeProgress,
) {
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
      insight: _paceInsight(item.name, spentProgress, timeProgress, status),
    );
  }).toList(growable: false)
    ..sort((a, b) => (b.spentProgress - b.timeProgress)
        .compareTo(a.spentProgress - a.timeProgress));
}

List<MonthlyInsightItem> _buildAnomalies({
  required List<MonthlyReportTransactionInput> currentTransactions,
  required List<MonthlyReportTransactionInput> previousTransactions,
}) {
  final currentByCategory = _expenseTotalsByCategory(currentTransactions);
  final previousByCategory = _expenseTotalsByCategory(previousTransactions);
  final anomalies = <MonthlyInsightItem>[];

  for (final entry in currentByCategory.entries) {
    final previous = previousByCategory[entry.key] ?? 0;
    if (previous <= 0 || entry.value < 50) continue;
    final increaseRatio = (entry.value - previous) / previous;
    if (increaseRatio < 0.35) continue;
    anomalies.add(
      MonthlyInsightItem(
        title: '${_titleCase(entry.key)} spending is higher',
        description:
            '${_titleCase(entry.key)} spending is ${(increaseRatio * 100).round()}% higher than last month.',
        status: MonthlyReportStatus.unusualSpending,
      ),
    );
  }

  anomalies.sort((a, b) => a.title.compareTo(b.title));
  return anomalies.take(5).toList(growable: false);
}

MonthlySubscriptionReport _buildSubscriptions(
  List<MonthlyReportRecurringInput> recurringItems,
  DateTime now,
) {
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
          status, daysUntil, item.previousAmount, item.amount),
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
}) {
  var running = currentBalance;
  final points = <MonthlyCashFlowPoint>[
    MonthlyCashFlowPoint(label: 'Today', balance: _roundMoney(running)),
  ];
  for (final tx in futureTransactions.take(6)) {
    running +=
        tx.type.toLowerCase() == 'income' ? tx.amount.abs() : -tx.amount.abs();
    points.add(
      MonthlyCashFlowPoint(
        label: _cashFlowName(tx),
        balance: _roundMoney(running),
      ),
    );
  }
  points.add(
    MonthlyCashFlowPoint(label: 'End of month', balance: forecastedBalance),
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
}) {
  final watchItems = budgetHealth
      .where((item) => item.status != MonthlyReportStatus.onTrack)
      .map((item) => item.name.toLowerCase())
      .take(2)
      .join(' and ');
  final statusText = monthlyReportStatusLabel(status).toLowerCase();
  final action = watchItems.isNotEmpty
      ? ' Watch $watchItems because it is moving faster than expected.'
      : anomalies.isNotEmpty
          ? ' Review the unusual spending alerts before adding new commitments.'
          : ' Keep current spending pace and scheduled bills unchanged.';
  return 'You are $statusText this month. Safe-to-spend is ${safeToSpend.toStringAsFixed(2)} $currencyCode/day and the end-of-month balance is forecast at ${forecastedBalance.toStringAsFixed(2)} $currencyCode.$action';
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

double _monthProgress(DateTime today, DateTime monthStart, DateTime monthEnd) {
  if (today.isBefore(monthStart)) return 0;
  if (today.isAfter(monthEnd)) return 1;
  return (today.day / monthEnd.day).clamp(0.0, 1.0);
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
) {
  final spentPct = (spentProgress * 100).round();
  final timePct = (timeProgress * 100).round();
  switch (status) {
    case MonthlyReportStatus.overBudget:
      return '$name is over budget. Pause or reduce this category for the rest of the month.';
    case MonthlyReportStatus.spendingFast:
      return 'You have used $spentPct% of $name, but the month is only $timePct% complete.';
    case MonthlyReportStatus.needsAttention:
      return '$name needs attention because spending is slightly ahead of the month pace.';
    default:
      return '$name is on track with the current month pace.';
  }
}

String _subscriptionNote(
  MonthlySubscriptionStatus status,
  int daysUntil,
  double? previousAmount,
  double amount,
) {
  switch (status) {
    case MonthlySubscriptionStatus.duplicatePossible:
      return 'Possible duplicate recurring charge';
    case MonthlySubscriptionStatus.priceIncrease:
      return 'Amount increased from ${previousAmount!.toStringAsFixed(2)} to ${amount.toStringAsFixed(2)}';
    case MonthlySubscriptionStatus.upcoming:
      return daysUntil <= 0 ? 'Due today' : 'Renews in $daysUntil days';
    case MonthlySubscriptionStatus.active:
      return 'Active recurring bill';
  }
}

String _cashFlowName(MonthlyReportTransactionInput tx) {
  final merchant = tx.merchant?.trim();
  if (merchant != null && merchant.isNotEmpty) return merchant;
  final category = tx.category.trim();
  return category.isEmpty ? 'Transaction' : _titleCase(category);
}

String _normalizedName(String value) => value.trim().toLowerCase();

String _titleCase(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

String monthlyReportStatusLabel(MonthlyReportStatus status) {
  switch (status) {
    case MonthlyReportStatus.onTrack:
      return 'On track';
    case MonthlyReportStatus.spendingFast:
      return 'Spending fast';
    case MonthlyReportStatus.overBudget:
      return 'Over budget';
    case MonthlyReportStatus.safeToSpend:
      return 'Safe to spend';
    case MonthlyReportStatus.needsAttention:
      return 'Needs attention';
    case MonthlyReportStatus.unusualSpending:
      return 'Unusual spending';
  }
}

String monthlySubscriptionStatusLabel(MonthlySubscriptionStatus status) {
  switch (status) {
    case MonthlySubscriptionStatus.active:
      return 'Active';
    case MonthlySubscriptionStatus.upcoming:
      return 'Upcoming';
    case MonthlySubscriptionStatus.priceIncrease:
      return 'Price changed';
    case MonthlySubscriptionStatus.duplicatePossible:
      return 'Duplicate?';
  }
}
