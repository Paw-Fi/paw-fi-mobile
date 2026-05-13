import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/goals/domain/models/goal.dart';
import 'package:moneko/features/goals/presentation/providers/goals_providers.dart'
    as goals;
import 'package:moneko/features/insights/domain/monthly_financial_report.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MonthlyReportNotifier extends AsyncNotifier<MonthlyFinancialReport> {
  @override
  Future<MonthlyFinancialReport> build() async {
    final user = ref.watch(authProvider);
    final preview = ref.watch(previewModeProvider);
    final userId = user.uid;
    final currencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final preferredTimezone = ref.watch(appPreferredTimezoneProvider);
    final householdScope = ref.watch(householdScopeProvider);
    final now = effectiveNow(preferredTimezone: preferredTimezone);
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final previousMonthStart = DateTime(now.year, now.month - 1);
    final previousMonthEnd = DateTime(now.year, now.month, 0);
    final historicalStart = DateTime(now.year, now.month - 6);
    final householdId = _reportHouseholdId(householdScope);
    final pocketsScope = _pocketsScopeType(householdScope.activeAccountType);

    if (preview.isActive) {
      throw UnsupportedError(
        'Monthly financial health uses real account data and is unavailable in preview mode.',
      );
    }

    if (userId.isEmpty) {
      return buildMonthlyFinancialReport(
        MonthlyReportInput(
          monthStart: monthStart,
          now: now,
          currencyCode: currencyCode,
          currentBalance: 0,
          currentMonthTransactions: const [],
          previousMonthTransactions: const [],
          historicalTransactions: const [],
          budgetItems: const [],
          futureTransactions: const [],
          recurringItems: const [],
          goals: const [],
        ),
      );
    }

    final currentQuery = DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      startDate: monthStart,
      endDate: monthEnd,
    );
    final previousQuery = DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      startDate: previousMonthStart,
      endDate: previousMonthEnd,
    );
    final historicalQuery = DashboardScopeQuery(
      userId: userId,
      householdId: householdId,
      selectedCurrency: currencyCode,
      startDate: historicalStart,
      endDate: previousMonthEnd,
    );

    final currentBase = await ref.watch(
      dashboardCalendarTransactionsProvider(currentQuery).future,
    );
    final previousBase = await ref.watch(
      dashboardCalendarTransactionsProvider(previousQuery).future,
    );
    final historicalBase = await ref.watch(
      dashboardCalendarTransactionsProvider(historicalQuery).future,
    );
    final currentTransactions = mergeDashboardTransactionsWithLocalOverlay(
      base: currentBase,
      localOverlay:
          ref.watch(dashboardLocalOverlayTransactionsProvider(currentQuery)),
      query: currentQuery,
    );
    final previousTransactions = mergeDashboardTransactionsWithLocalOverlay(
      base: previousBase,
      localOverlay:
          ref.watch(dashboardLocalOverlayTransactionsProvider(previousQuery)),
      query: previousQuery,
    );
    final historicalTransactions = mergeDashboardTransactionsWithLocalOverlay(
      base: historicalBase,
      localOverlay:
          ref.watch(dashboardLocalOverlayTransactionsProvider(historicalQuery)),
      query: historicalQuery,
    );

    final recurringTransactions = await _loadRecurringTransactions(
      ref,
      userId: userId,
      householdId: householdId,
    );
    final futureTransactions = _futureTransactionsForReport(
      actualTransactions: currentTransactions,
      recurringTransactions: recurringTransactions,
      now: now,
      monthEnd: monthEnd,
      currencyCode: currencyCode,
    );
    final recurringItems = _recurringItemsForReport(
      recurringTransactions,
      previousTransactions: previousTransactions,
      now: now,
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencyCode: currencyCode,
    );

    final pocketsParams = PocketsScopeParams(
      scope: pocketsScope,
      householdId: householdId,
      periodMonth: monthStart,
      currency: currencyCode,
      includeUpcomingRecurring: true,
    );
    final pocketsState = ref.watch(pocketsProvider(pocketsParams));
    if (pocketsState.isLoading && !pocketsState.hasDisplayData) {
      await ref.read(pocketsProvider(pocketsParams).notifier).load();
    }
    final loadedPocketsState = ref.read(pocketsProvider(pocketsParams));
    if (loadedPocketsState.error != null &&
        loadedPocketsState.error!.trim().isNotEmpty) {
      throw StateError('Budget data unavailable: ${loadedPocketsState.error}');
    }

    final walletSnapshot = await _readWalletSnapshot(
      ref,
      userId: userId,
      householdId: householdId,
      currencyCode: currencyCode,
      monthStart: monthStart,
    );
    final previousNetWorth = await _readPreviousNetWorth(
      ref,
      userId: userId,
      householdId: householdId,
      currencyCode: currencyCode,
      monthStart: monthStart,
    );
    final goalInputsResult = await _loadGoalInputsForReport(
      ref,
      userId: userId,
      householdId: householdId,
      currencyCode: currencyCode,
    );
    return buildMonthlyFinancialReport(
      MonthlyReportInput(
        monthStart: monthStart,
        now: now,
        currencyCode: currencyCode,
        currentBalance: walletSnapshot.netWorthCents / 100.0,
        currentMonthTransactions:
            currentTransactions.map(_transactionInput).toList(growable: false),
        previousMonthTransactions:
            previousTransactions.map(_transactionInput).toList(growable: false),
        historicalTransactions:
            historicalTransactions.map(_transactionInput).toList(growable: false),
        budgetItems: _budgetInputs(loadedPocketsState.editing),
        futureTransactions:
            futureTransactions.map(_transactionInput).toList(growable: false),
        recurringItems: recurringItems,
        goals: goalInputsResult.items,
        previousNetWorth: previousNetWorth,
        goalsDataAvailable: goalInputsResult.dataAvailable,
      ),
    );
  }
}

final monthlyFinancialReportProvider =
    AsyncNotifierProvider<MonthlyReportNotifier, MonthlyFinancialReport>(
  MonthlyReportNotifier.new,
);

String? _reportHouseholdId(HouseholdScope scope) {
  switch (scope.activeAccountType) {
    case ActiveWalletType.personal:
      return null;
    case ActiveWalletType.portfolio:
      return scope.activeAccountHouseholdId;
    case ActiveWalletType.household:
      return scope.selectedHouseholdId ?? scope.activeAccountHouseholdId;
  }
}

PocketsScopeType _pocketsScopeType(ActiveWalletType type) {
  switch (type) {
    case ActiveWalletType.personal:
      return PocketsScopeType.personal;
    case ActiveWalletType.portfolio:
      return PocketsScopeType.portfolio;
    case ActiveWalletType.household:
      return PocketsScopeType.household;
  }
}

Future<List<RecurringTransaction>> _loadRecurringTransactions(
  Ref ref, {
  required String userId,
  required String? householdId,
}) async {
  final state = ref.watch(recurringTransactionsProvider(householdId));
  if (!state.hasLoadedOnce && !state.data.isLoading) {
    await ref
        .read(recurringTransactionsProvider(householdId).notifier)
        .loadRecurringTransactions(userId);
  }
  return ref
          .read(recurringTransactionsProvider(householdId))
          .data
          .valueOrNull ??
      state.data.valueOrNull ??
      const <RecurringTransaction>[];
}

Future<WalletsMonthSnapshot> _readWalletSnapshot(
  Ref ref, {
  required String userId,
  required String? householdId,
  required String currencyCode,
  required DateTime monthStart,
}) async {
  return ref.watch(
    walletsMonthSnapshotProvider(
      WalletsMonthQuery(
        scope: WalletsScopeQuery(
          userId: userId,
          householdId: householdId,
          selectedCurrency: currencyCode,
          currentMonthStart: monthStart,
        ),
        monthStart: monthStart,
      ),
    ).future,
  );
}

Future<double?> _readPreviousNetWorth(
  Ref ref, {
  required String userId,
  required String? householdId,
  required String currencyCode,
  required DateTime monthStart,
}) async {
  final history = await ref.watch(
    walletsHistoryProvider(
      WalletsScopeQuery(
        userId: userId,
        householdId: householdId,
        selectedCurrency: currencyCode,
        currentMonthStart: monthStart,
      ),
    ).future,
  );
  final priorPoints = history.netWorthSeries
      .where((point) => point.monthStart.isBefore(monthStart))
      .toList(growable: false)
    ..sort((a, b) => b.monthStart.compareTo(a.monthStart));
  if (priorPoints.isEmpty) return null;
  return priorPoints.first.netWorthCents / 100.0;
}

Future<_GoalInputsResult> _loadGoalInputsForReport(
  Ref ref, {
  required String userId,
  required String? householdId,
  required String currencyCode,
}) async {
  try {
    final supabase = ref.read(goals.supabaseProvider);
    final response = await supabase.functions.invoke(
      'list-goals',
      method: HttpMethod.get,
      queryParameters: {
        'userId': userId,
        if (householdId != null) 'householdId': householdId,
        'status': 'active',
      },
    );
    if (response.status != 200 || response.data == null) {
      return const _GoalInputsResult(
        items: <MonthlyReportGoalInput>[],
        dataAvailable: false,
      );
    }
    final data = response.data as Map<String, dynamic>;
    final rows = data['goals'] as List<dynamic>? ?? const [];
    final items = rows
        .whereType<Map<String, dynamic>>()
        .map(Goal.fromJson)
        .where((goal) => goal.isActive && !goal.privacyRedacted)
        .map((goal) => _goalInput(goal, currencyCode))
        .whereType<MonthlyReportGoalInput>()
        .toList(growable: false);
    return _GoalInputsResult(items: items, dataAvailable: true);
  } catch (_) {
    return const _GoalInputsResult(
      items: <MonthlyReportGoalInput>[],
      dataAvailable: false,
    );
  }
}

class _GoalInputsResult {
  const _GoalInputsResult({
    required this.items,
    required this.dataAvailable,
  });

  final List<MonthlyReportGoalInput> items;
  final bool dataAvailable;
}

MonthlyReportGoalInput? _goalInput(Goal goal, String currencyCode) {
  final selectedCurrency = currencyCode.toUpperCase();
  final goalCurrency = goal.currency.toUpperCase();
  final baseCurrency = goal.baseCurrency?.toUpperCase();
  final useNormalized = baseCurrency == selectedCurrency &&
      goal.normalizedTargetAmount != null &&
      goal.normalizedCurrentAmount != null;
  if (!useNormalized && goalCurrency != selectedCurrency) return null;

  return MonthlyReportGoalInput(
    title: goal.title,
    targetAmount:
        useNormalized ? goal.normalizedTargetAmount! : goal.targetAmount,
    currentAmount:
        useNormalized ? goal.normalizedCurrentAmount! : goal.currentAmount,
    currencyCode: selectedCurrency,
    targetDate: goal.targetDate,
    isOnTrack: goal.isOnTrack,
  );
}

List<ExpenseEntry> _futureTransactionsForReport({
  required List<ExpenseEntry> actualTransactions,
  required List<RecurringTransaction> recurringTransactions,
  required DateTime now,
  required DateTime monthEnd,
  required String currencyCode,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final actualFuture = actualTransactions.where((entry) {
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    return day.isAfter(today) && !day.isAfter(monthEnd);
  }).toList(growable: false);
  final projected = projectRecurringTransactionsAsExpenseEntries(
    recurringTransactions: recurringTransactions,
    rangeStart: today.add(const Duration(days: 1)),
    rangeEnd: monthEnd,
    selectedCurrency: currencyCode,
  );
  final dedupedProjected = dedupeProjectedRecurringExpenseEntries(
    projectedExpenses: projected,
    actualExpenses: actualFuture,
  );

  return <ExpenseEntry>[...actualFuture, ...dedupedProjected]
    ..sort((a, b) => a.date.compareTo(b.date));
}

List<MonthlyReportRecurringInput> _recurringItemsForReport(
  List<RecurringTransaction> recurringTransactions, {
  required List<ExpenseEntry> previousTransactions,
  required DateTime now,
  required DateTime monthStart,
  required DateTime monthEnd,
  required String currencyCode,
}) {
  final nowDay = DateTime(now.year, now.month, now.day);
  return recurringTransactions.where((item) {
    return item.isActive &&
        item.currency.toUpperCase() == currencyCode.toUpperCase();
  }).map((item) {
    final nextDate = item
        .getNextOccurrence(nowDay.subtract(const Duration(microseconds: 1)));
    return MonthlyReportRecurringInput(
      id: item.id,
      name: _recurringName(item),
      amount: item.amount.abs(),
      type: item.type,
      currencyCode: item.currency.toUpperCase(),
      nextDate: nextDate,
      previousAmount: _previousAmountForRecurring(item, previousTransactions),
    );
  }).where((item) {
    final day =
        DateTime(item.nextDate.year, item.nextDate.month, item.nextDate.day);
    return !day.isBefore(nowDay) &&
        !day.isBefore(monthStart) &&
        !day.isAfter(monthEnd);
  }).toList(growable: false);
}

List<MonthlyReportBudgetInput> _budgetInputs(List<PocketEnvelope> pockets) {
  return pockets
      .map(
        (pocket) => MonthlyReportBudgetInput(
          name: pocket.name,
          budgetAmount: pocket.budgetAmountCents / 100.0,
          spent: pocket.spent,
        ),
      )
      .toList(growable: false);
}

MonthlyReportTransactionInput _transactionInput(ExpenseEntry entry) {
  return MonthlyReportTransactionInput(
    id: entry.id,
    date: entry.date,
    amount: entry.amount.abs(),
    type: (entry.type ?? 'expense').toLowerCase(),
    category: (entry.category?.trim().isNotEmpty == true)
        ? entry.category!.trim()
        : 'Uncategorized',
    merchant: entry.merchant?.trim().isNotEmpty == true
        ? entry.merchant!.trim()
        : entry.rawText,
    currencyCode: (entry.currency ?? '').toUpperCase(),
  );
}

String _recurringName(RecurringTransaction item) {
  final merchant = item.merchant?.trim();
  if (merchant != null && merchant.isNotEmpty) return merchant;
  final description = item.description?.trim();
  if (description != null && description.isNotEmpty) return description;
  final source = item.source?.trim();
  if (source != null && source.isNotEmpty) return source;
  return item.category;
}

double? _previousAmountForRecurring(
  RecurringTransaction item,
  List<ExpenseEntry> previousTransactions,
) {
  final recurringName = _normalizeRecurringMatch(_recurringName(item));
  final category = _normalizeRecurringMatch(item.category);
  final matches = previousTransactions.where((tx) {
    if ((tx.type ?? 'expense').toLowerCase() != item.type.toLowerCase()) {
      return false;
    }
    final merchant = _normalizeRecurringMatch(tx.merchant ?? tx.rawText ?? '');
    final txCategory = _normalizeRecurringMatch(tx.category ?? '');
    return merchant == recurringName || txCategory == category;
  }).toList(growable: false)
    ..sort((a, b) => b.date.compareTo(a.date));
  if (matches.isEmpty) return null;
  return matches.first.amount.abs();
}

String _normalizeRecurringMatch(String value) => value.trim().toLowerCase();
