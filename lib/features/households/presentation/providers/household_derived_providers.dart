import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/shared_budget.dart';
import 'package:moneko/features/households/domain/utils/settlement_net_calculator.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

// ============================================================================
// SETTLEMENT OVERVIEW (combined splits + payments for settlement UI)
// ============================================================================

class SettlementOverviewData {
  final List<ExpenseSplitGroup> splits;
  final List<SettlementPaymentRecord> payments;

  const SettlementOverviewData({
    required this.splits,
    required this.payments,
  });
}

/// Combined provider that watches both canonical splits and settlement
/// payments for a household. This is the single source of truth for
/// settlement UI (card + sheet). Keyed by householdId only.
///
/// - Loading: when either input is loading with no cached value.
/// - Error: when either input errors with no cached value.
/// - Data: when both have usable values.
final settlementOverviewProvider =
    Provider.autoDispose.family<AsyncValue<SettlementOverviewData>, String>(
  (ref, householdId) {
    final splitsAsync = ref.watch(
      cachedHouseholdSplitsProvider(
        HouseholdSplitsParams(householdId: householdId),
      ),
    );
    final paymentsAsync = ref.watch(
      householdSettlementPaymentsProvider(householdId),
    );

    final splits = splitsAsync.valueOrNull;
    final payments = paymentsAsync.valueOrNull;
    final optimisticPayments = ref.watch(
      optimisticSettlementPaymentsProvider.select(
        (state) => state[householdId] ?? const <SettlementPaymentRecord>[],
      ),
    );

    // If either has errored and has no usable cached value, propagate error.
    if (splits == null && splitsAsync.hasError) {
      return AsyncValue.error(
        splitsAsync.error!,
        splitsAsync.stackTrace ?? StackTrace.current,
      );
    }
    if (payments == null && paymentsAsync.hasError) {
      return AsyncValue.error(
        paymentsAsync.error!,
        paymentsAsync.stackTrace ?? StackTrace.current,
      );
    }

    // If either is still loading with no cached value, show loading.
    if (splits == null || payments == null) {
      return const AsyncValue.loading();
    }

    return AsyncValue.data(SettlementOverviewData(
      splits: splits,
      payments: [...optimisticPayments, ...payments],
    ));
  },
);

final householdDerivedSummaryProvider =
    Provider.family<AsyncValue<HouseholdSummary?>, HouseholdSummaryParams>(
  (ref, params) {
    final currentUserId = supabase.auth.currentUser?.id;
    final rangeStart = _normalizeDate(DateTime.parse(params.startDate));
    final rangeEnd = _normalizeDate(DateTime.parse(params.endDate));
    final query = DashboardScopeQuery(
      userId: currentUserId ?? '',
      householdId: params.householdId,
      selectedCurrency: params.currency,
      startDate: rangeStart,
      endDate: rangeEnd,
    );
    final expensesAsync = ref.watch(
      dashboardCalendarTransactionsProvider(query),
    );
    final splitsAsync = ref.watch(
      cachedHouseholdSplitsProvider(
        HouseholdSplitsParams(householdId: params.householdId),
      ),
    );
    final membersAsync =
        ref.watch(householdMembersProvider(params.householdId));
    final budgetsAsync =
        ref.watch(householdBudgetsProvider(params.householdId));

    // Recurring: used to project synthetic occurrences into analytics.
    // This provider is a StateNotifier that may not have loaded yet.
    final recurringState = ref.watch(recurringTransactionsProvider(
      params.householdId,
    ));

    if (currentUserId != null &&
        currentUserId.isNotEmpty &&
        !recurringState.hasLoadedOnce &&
        !recurringState.data.isLoading) {
      final recurringNotifier = ref.read(
        recurringTransactionsProvider(params.householdId).notifier,
      );
      Future.microtask(() {
        recurringNotifier.loadRecurringTransactions(currentUserId);
      });
    }

    final baseExpenses = expensesAsync.valueOrNull;
    if (baseExpenses == null) {
      if (expensesAsync.hasError) {
        return AsyncValue.error(
          expensesAsync.error!,
          expensesAsync.stackTrace!,
        );
      }
      return const AsyncValue.loading();
    }

    final expenses = mergeDashboardTransactionsWithLocalOverlay(
      base: baseExpenses,
      localOverlay: ref.watch(dashboardLocalOverlayTransactionsProvider(query)),
      query: query,
    );

    final optimisticExpenses = ref.watch(
      householdOptimisticExpensesProvider.select(
        (state) => state[params.householdId] ?? const <ExpenseEntry>[],
      ),
    );
    final deletedIds = ref.watch(
      householdOptimisticDeletedExpenseIdsProvider.select(
        (state) => state[params.householdId] ?? const <String>{},
      ),
    );
    final mergedExpenses = mergeHouseholdExpenses(
      expenses,
      optimisticExpenses,
      deletedIds: deletedIds,
    );
    final splits = splitsAsync.valueOrNull ?? const <ExpenseSplitGroup>[];
    final members = membersAsync.valueOrNull ?? const <HouseholdMember>[];
    final budgets = budgetsAsync.valueOrNull ?? const <SharedBudget>[];

    final expensesWithRecurring = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: mergedExpenses,
      recurringTransactions: recurringState.data.valueOrNull ?? const [],
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      selectedCurrency: params.currency,
      includeFutureOccurrences: false,
    );

    final summary = _buildHouseholdSummary(
      params: params,
      expenses: expensesWithRecurring,
      splits: splits,
      members: members,
      budgets: budgets,
    );

    return AsyncValue.data(summary);
  },
);

HouseholdSummary _buildHouseholdSummary({
  required HouseholdSummaryParams params,
  required List<ExpenseEntry> expenses,
  required List<ExpenseSplitGroup> splits,
  required List<HouseholdMember> members,
  required List<SharedBudget> budgets,
}) {
  final currency = params.currency.toUpperCase();
  final rangeStart = _normalizeDate(DateTime.parse(params.startDate));
  final rangeEnd = _normalizeDate(DateTime.parse(params.endDate));

  final splitById = {
    for (final g in splits) g.id: g,
  };

  final balances = <String, int>{};
  final contributionByUser = <String, _MemberContributionBuilder>{};
  final splitGroupsByUser = <String, Set<String>>{};
  final categoryTotals = <String, _CategoryTotals>{};
  final splitGroupIds = <String>{};

  int totalExpenseCents = 0;
  int totalIncomeCents = 0;
  int transactionCount = 0;

  for (final e in expenses) {
    if (!_expenseMatchesCurrency(e, currency)) continue;
    if (!_expenseInRange(e, rangeStart, rangeEnd)) continue;

    transactionCount += 1;

    final amount = e.amountCents.abs();
    final type = (e.type ?? 'expense').toLowerCase();
    final isIncome = type == 'income';

    if (isIncome) {
      totalIncomeCents += amount;
      continue;
    }

    totalExpenseCents += amount;

    final category = (e.category ?? 'other').trim();
    final catTotals = categoryTotals.putIfAbsent(
      category,
      () => _CategoryTotals(category: category),
    );
    catTotals.amountCents += amount;
    catTotals.transactionCount += 1;

    final groupId = e.splitGroupId;
    final group = groupId != null ? splitById[groupId] : null;

    if (group == null ||
        group.splitLines == null ||
        group.splitLines!.isEmpty) {
      final owner = e.userId;
      if (owner != null && owner.isNotEmpty) {
        _addContribution(
          contributionByUser,
          splitGroupsByUser,
          owner,
          amount,
          groupId: groupId,
        );
      }
      continue;
    }

    splitGroupIds.add(group.id);

    for (final line in group.splitLines!) {
      final lineAmount = (line.amountCents ?? 0).abs();
      if (lineAmount <= 0) continue;

      _addContribution(
        contributionByUser,
        splitGroupsByUser,
        line.userId,
        lineAmount,
        groupId: group.id,
      );

      if (line.isSettled) continue;
      if (line.userId == group.payerUserId) continue;
      balances[group.payerUserId] =
          (balances[group.payerUserId] ?? 0) + lineAmount;
      balances[line.userId] = (balances[line.userId] ?? 0) - lineAmount;
    }
  }

  final memberContributions = _buildMemberContributions(
    members: members,
    contributionByUser: contributionByUser,
    splitGroupsByUser: splitGroupsByUser,
    balances: balances,
  );

  final totals = Totals(
    totalExpensesCents: totalExpenseCents,
    totalIncomeCents: totalIncomeCents,
    netCents: totalIncomeCents - totalExpenseCents,
    transactionCount: transactionCount,
    splitCount: splitGroupIds.length,
  );

  final breakdown = _buildCategoryBreakdown(
    categoryTotals: categoryTotals,
    totalExpenseCents: totalExpenseCents,
  );

  final budgetStatuses = _buildBudgetStatuses(
    budgets: budgets,
    expenses: expenses,
    splitById: splitById,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
    currency: currency,
  );

  return HouseholdSummary(
    householdId: params.householdId,
    currency: currency,
    period: DatePeriod(
      startDate: rangeStart.toIso8601String(),
      endDate: rangeEnd.toIso8601String(),
    ),
    totals: totals,
    memberContributions: memberContributions,
    categoryBreakdown: breakdown,
    budgets: budgetStatuses,
    balances: balances,
  );
}

DateTime _normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _expenseMatchesCurrency(ExpenseEntry expense, String currency) {
  final code = (expense.currency ?? '').trim().toUpperCase();
  return code.isEmpty || code == currency;
}

bool _expenseInRange(ExpenseEntry expense, DateTime start, DateTime end) {
  final d = _normalizeDate(expense.date);
  return !d.isBefore(start) && !d.isAfter(end);
}

void _addContribution(
  Map<String, _MemberContributionBuilder> target,
  Map<String, Set<String>> splitGroupsByUser,
  String userId,
  int amountCents, {
  String? groupId,
}) {
  final builder = target.putIfAbsent(
    userId,
    () => _MemberContributionBuilder(userId: userId),
  );
  builder.totalSpentCents += amountCents;
  builder.transactionCount += 1;
  if (groupId != null && groupId.isNotEmpty) {
    final groups = splitGroupsByUser.putIfAbsent(userId, () => <String>{});
    groups.add(groupId);
  }
}

List<MemberContribution> _buildMemberContributions({
  required List<HouseholdMember> members,
  required Map<String, _MemberContributionBuilder> contributionByUser,
  required Map<String, Set<String>> splitGroupsByUser,
  required Map<String, int> balances,
}) {
  final contributions = <MemberContribution>[];

  if (members.isNotEmpty) {
    for (final member in members) {
      final builder = contributionByUser[member.userId];
      final splitCount = splitGroupsByUser[member.userId]?.length ?? 0;
      contributions.add(
        MemberContribution(
          userId: member.userId,
          totalSpentCents: builder?.totalSpentCents ?? 0,
          transactionCount: builder?.transactionCount ?? 0,
          splitCount: splitCount,
          balanceCents: balances[member.userId] ?? 0,
          userEmail: member.userEmail,
          userName: member.userName,
        ),
      );
    }
    return contributions;
  }

  for (final entry in contributionByUser.values) {
    final splitCount = splitGroupsByUser[entry.userId]?.length ?? 0;
    contributions.add(
      MemberContribution(
        userId: entry.userId,
        totalSpentCents: entry.totalSpentCents,
        transactionCount: entry.transactionCount,
        splitCount: splitCount,
        balanceCents: balances[entry.userId] ?? 0,
      ),
    );
  }

  return contributions;
}

List<CategoryBreakdown> _buildCategoryBreakdown({
  required Map<String, _CategoryTotals> categoryTotals,
  required int totalExpenseCents,
}) {
  final breakdown = categoryTotals.values.map((entry) {
    final percentage = totalExpenseCents > 0
        ? (entry.amountCents / totalExpenseCents) * 100
        : 0.0;
    return CategoryBreakdown(
      category: entry.category,
      amountCents: entry.amountCents,
      percentage: percentage,
      transactionCount: entry.transactionCount,
    );
  }).toList();

  breakdown.sort((a, b) => b.amountCents.compareTo(a.amountCents));
  return breakdown;
}

List<BudgetStatus> _buildBudgetStatuses({
  required List<SharedBudget> budgets,
  required List<ExpenseEntry> expenses,
  required Map<String, ExpenseSplitGroup> splitById,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required String currency,
}) {
  final statuses = <BudgetStatus>[];
  for (final budget in budgets) {
    if (!budget.isActive) continue;
    if (budget.currency.toUpperCase() != currency) continue;

    final spentCents = _calculateBudgetSpent(
      budget: budget,
      expenses: expenses,
      splitById: splitById,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    final remainingCents = budget.amountCents - spentCents;
    final percentageUsed =
        budget.amountCents > 0 ? (spentCents / budget.amountCents) * 100 : 0.0;

    statuses.add(
      BudgetStatus(
        budgetId: budget.id,
        name: budget.name,
        currency: budget.currency.toUpperCase(),
        period: budget.period.toJson(),
        amountCents: budget.amountCents,
        spentCents: spentCents,
        remainingCents: remainingCents,
        percentageUsed: percentageUsed,
        isOverBudget: spentCents > budget.amountCents,
        isAtWarnThreshold: percentageUsed >= (budget.warnThreshold * 100.0),
        isAtAlertThreshold: percentageUsed >= (budget.alertThreshold * 100.0),
      ),
    );
  }
  return statuses;
}

int _calculateBudgetSpent({
  required SharedBudget budget,
  required List<ExpenseEntry> expenses,
  required Map<String, ExpenseSplitGroup> splitById,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  int spentCents = 0;
  final isPersonal = budget.budgetType == BudgetType.personal;
  final budgetUserId = budget.userId;

  for (final e in expenses) {
    if (!_expenseMatchesCurrency(e, budget.currency.toUpperCase())) continue;
    if (!_expenseInRange(e, rangeStart, rangeEnd)) continue;

    final type = (e.type ?? 'expense').toLowerCase();
    if (type == 'income') continue;

    final amount = e.amountCents.abs();
    if (!isPersonal) {
      spentCents += amount;
      continue;
    }

    if (budgetUserId == null || budgetUserId.isEmpty) continue;

    final groupId = e.splitGroupId;
    final group = groupId != null ? splitById[groupId] : null;
    if (group != null && group.splitLines != null) {
      ExpenseSplitLine? line;
      for (final candidate in group.splitLines!) {
        if (candidate.userId == budgetUserId) {
          line = candidate;
          break;
        }
      }
      if (line != null && (line.amountCents ?? 0) > 0) {
        if (budget.countSplitPortionOnly) {
          spentCents += (line.amountCents ?? 0).abs();
          continue;
        }
        if (e.userId == budgetUserId) {
          spentCents += amount;
          continue;
        }
      }
    }

    if (e.userId == budgetUserId) {
      spentCents += amount;
    }
  }

  return spentCents;
}

class _MemberContributionBuilder {
  final String userId;
  int totalSpentCents;
  int transactionCount;

  _MemberContributionBuilder({
    required this.userId,
  })  : totalSpentCents = 0,
        transactionCount = 0;
}

class _CategoryTotals {
  final String category;
  int amountCents;
  int transactionCount;

  _CategoryTotals({
    required this.category,
  })  : amountCents = 0,
        transactionCount = 0;
}
