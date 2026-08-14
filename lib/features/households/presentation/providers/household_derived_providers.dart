import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/households/domain/entities/shared_budget.dart';
import 'package:moneko/features/households/domain/utils/settlement_net_calculator.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
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

class _SettlementOverviewRefreshSnapshot {
  const _SettlementOverviewRefreshSnapshot({
    required this.splits,
    required this.payments,
    required this.durablePendingPayments,
  });

  final List<ExpenseSplitGroup> splits;
  final List<SettlementPaymentRecord> payments;
  final List<SettlementPaymentRecord> durablePendingPayments;
}

class _SettlementOverviewRefreshCache {
  final _entries = <String, _SettlementOverviewRefreshSnapshot>{};

  _SettlementOverviewRefreshSnapshot? operator [](String key) => _entries[key];

  void put(String key, _SettlementOverviewRefreshSnapshot snapshot) {
    _entries[key] = snapshot;
  }
}

final _settlementOverviewRefreshCacheProvider =
    Provider<_SettlementOverviewRefreshCache>(
  (ref) => _SettlementOverviewRefreshCache(),
);

/// Combined local projection for multi-currency and pending-payment
/// settlement UI. The normal single-currency card and settle-up sheet use
/// [householdPairwiseSettlementBalancesV2Provider] directly.
///
/// - Loading: when either input is loading with no cached value.
/// - Error: when either input errors with no cached value.
/// - Data: when both have usable values.
final settlementOverviewProvider =
    Provider.autoDispose.family<AsyncValue<SettlementOverviewData>, String>(
  (ref, householdId) {
    final currentUserId = ref.watch(authProvider).uid;
    final refreshCache = ref.read(_settlementOverviewRefreshCacheProvider);
    final cacheKey = '$currentUserId|$householdId';
    final retained = refreshCache[cacheKey];
    final splitsAsync = ref.watch(
      cachedHouseholdSplitsProvider(
        HouseholdSplitsParams(householdId: householdId),
      ),
    );
    final paymentsAsync = ref.watch(
      householdSettlementPaymentsProvider(householdId),
    );

    final splits = splitsAsync.valueOrNull ?? retained?.splits;
    final payments = paymentsAsync.valueOrNull ?? retained?.payments;
    final optimisticSplits = ref.watch(
      householdOptimisticSplitsProvider.select(
        (state) => state[householdId] ?? const <ExpenseSplitGroup>[],
      ),
    );
    final optimisticPayments = ref.watch(
      optimisticSettlementPaymentsProvider.select(
        (state) => state[householdId] ?? const <SettlementPaymentRecord>[],
      ),
    );
    final durablePendingPaymentsAsync = ref.watch(
      pendingHouseholdSettlementPaymentsProvider(householdId),
    );
    final durablePendingPayments = durablePendingPaymentsAsync.valueOrNull ??
        retained?.durablePendingPayments;

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
    if (durablePendingPayments == null &&
        durablePendingPaymentsAsync.hasError) {
      return AsyncValue.error(
        durablePendingPaymentsAsync.error!,
        durablePendingPaymentsAsync.stackTrace ?? StackTrace.current,
      );
    }

    // If either is still loading with no cached value, show loading.
    if (splits == null || payments == null || durablePendingPayments == null) {
      return const AsyncValue.loading();
    }

    if (splitsAsync.valueOrNull != null &&
        paymentsAsync.valueOrNull != null &&
        durablePendingPaymentsAsync.valueOrNull != null) {
      refreshCache.put(
        cacheKey,
        _SettlementOverviewRefreshSnapshot(
          splits: splitsAsync.valueOrNull!,
          payments: paymentsAsync.valueOrNull!,
          durablePendingPayments: durablePendingPaymentsAsync.valueOrNull!,
        ),
      );
    }

    return AsyncValue.data(SettlementOverviewData(
      splits: mergeHouseholdSplits(splits, optimisticSplits),
      // The session overlay gives an immediate result after enqueue. As soon as
      // SQLite is available, its durable overlay replaces it to avoid double
      // counting the same mutation and to survive an app restart.
      payments: [
        ...(durablePendingPayments.isEmpty
            ? optimisticPayments
            : durablePendingPayments),
        ...payments,
      ],
    ));
  },
);

final _databaseUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// The complete local-first input set shared by household aggregate cards.
///
/// Cards must consume this projection instead of independently turning an
/// unresolved provider into an empty list. During refresh, the retained
/// projection is merged with the current optimistic overlays so a new or
/// edited transaction is visible immediately without a false zero/fallback.
class HouseholdDashboardProjection {
  const HouseholdDashboardProjection({
    required this.actualExpenses,
    required this.expensesWithRecurring,
    required this.splits,
    required this.recurringTransactions,
    this.hasDeferredSplitReferences = false,
  });

  final List<ExpenseEntry> actualExpenses;
  final List<ExpenseEntry> expensesWithRecurring;
  final List<ExpenseSplitGroup> splits;
  final List<RecurringTransaction> recurringTransactions;
  final bool hasDeferredSplitReferences;
}

class _HouseholdDashboardProjectionRefreshCache {
  final _entries = <DashboardScopeQuery, HouseholdDashboardProjection>{};

  HouseholdDashboardProjection? operator [](DashboardScopeQuery query) =>
      _entries[query];

  void put(
    DashboardScopeQuery query,
    HouseholdDashboardProjection projection,
  ) {
    _entries[query] = projection;
  }
}

final _householdDashboardProjectionRefreshCacheProvider =
    Provider<_HouseholdDashboardProjectionRefreshCache>(
  (ref) => _HouseholdDashboardProjectionRefreshCache(),
);

List<ExpenseEntry> mergeHouseholdDashboardExpenses({
  required List<ExpenseEntry> base,
  required List<ExpenseEntry> localOverlay,
  required DashboardScopeQuery query,
  required List<ExpenseEntry> optimisticExpenses,
  required Set<String> deletedIds,
  int? limit,
}) {
  final merged = mergeHouseholdExpenses(
    mergeDashboardTransactionsWithLocalOverlay(
      base: base,
      localOverlay: localOverlay,
      query: query,
    ),
    optimisticExpenses,
    deletedIds: deletedIds,
  );
  if (limit == null || limit < 0 || merged.length <= limit) return merged;
  return merged.take(limit).toList(growable: false);
}

Set<String> householdDashboardReferencedSplitGroupIds({
  required Iterable<ExpenseEntry> actualExpenses,
  required Iterable<RecurringTransaction> recurringTransactions,
}) =>
    {
      ...actualExpenses
          .map((entry) => entry.splitGroupId?.trim())
          .whereType<String>()
          .where(_databaseUuidPattern.hasMatch),
      ...recurringTransactions
          .map((transaction) => transaction.splitGroupId?.trim())
          .whereType<String>()
          .where(_databaseUuidPattern.hasMatch),
    };

/// Shared stale-while-revalidate source for household aggregate cards.
///
/// It is intentionally scoped by [DashboardScopeQuery], which includes user,
/// household, currencies, and date range. The refresh cache is in-memory only;
/// dashboard SQLite snapshots remain the restart source of truth.
final householdDashboardProjectionProvider = Provider.autoDispose
    .family<AsyncValue<HouseholdDashboardProjection>, DashboardScopeQuery>(
  (ref, query) {
    final householdId = query.householdId?.trim();
    if (query.userId.isEmpty || householdId == null || householdId.isEmpty) {
      return const AsyncValue.data(
        HouseholdDashboardProjection(
          actualExpenses: <ExpenseEntry>[],
          expensesWithRecurring: <ExpenseEntry>[],
          splits: <ExpenseSplitGroup>[],
          recurringTransactions: <RecurringTransaction>[],
        ),
      );
    }

    final refreshCache = ref.read(
      _householdDashboardProjectionRefreshCacheProvider,
    );
    final retained = refreshCache[query];
    final transactionsAsync = ref.watch(
      dashboardCalendarTransactionsProvider(query),
    );
    final localOverlay = ref.watch(
      dashboardLocalOverlayTransactionsProvider(query),
    );
    final optimisticExpenses = ref.watch(
      householdOptimisticExpensesProvider.select(
        (state) => state[householdId] ?? const <ExpenseEntry>[],
      ),
    );
    final deletedIds = ref.watch(
      householdOptimisticDeletedExpenseIdsProvider.select(
        (state) => state[householdId] ?? const <String>{},
      ),
    );
    final splitsAsync = ref.watch(householdDashboardSplitsProvider(query));
    final optimisticSplits = ref.watch(
      householdOptimisticSplitsProvider.select(
        (state) => state[householdId] ?? const <ExpenseSplitGroup>[],
      ),
    );
    final recurringState = ref.watch(
      recurringTransactionsProvider(householdId),
    );
    final occurrenceResolution =
        query.startDate == null || query.endDate == null
            ? const RecurringOccurrenceProjectionResolution()
            : ref.watch(recurringOccurrenceProjectionResolutionProvider(
                RecurringOccurrenceProjectionResolutionQuery(
                  userId: query.userId,
                  householdId: householdId,
                  startDate: query.startDate!,
                  endDate: query.endDate!,
                ),
              ));
    if (!recurringState.hasLoadedOnce) {
      final recurringNotifier = ref.read(
        recurringTransactionsProvider(householdId).notifier,
      );
      Future.microtask(() {
        recurringNotifier.loadRecurringTransactions(query.userId);
      });
    }

    final dependencyState = householdDashboardDependencyState(
      <AsyncValue<Object?>>[
        transactionsAsync,
        splitsAsync,
        recurringState.data,
      ],
    );

    List<ExpenseEntry> resolveExpenses(List<ExpenseEntry> base) =>
        mergeHouseholdDashboardExpenses(
          base: base,
          localOverlay: localOverlay,
          query: query,
          optimisticExpenses: optimisticExpenses,
          deletedIds: deletedIds,
        );

    HouseholdDashboardProjection buildProjection({
      required List<ExpenseEntry> baseExpenses,
      required List<ExpenseSplitGroup> baseSplits,
      required List<RecurringTransaction> recurringTransactions,
      HouseholdDashboardProjection? retainedProjection,
    }) {
      final splitAwareSnapshot = stabilizeHouseholdExpenseSplitSnapshot(
        expenses: resolveExpenses(baseExpenses),
        // Do not pre-deduplicate these candidates by expense id. During
        // reconciliation a provisional and canonical group can coexist; the
        // transaction's splitGroupId selects the one that belongs to it.
        splitCandidates: [...optimisticSplits, ...baseSplits],
        retained: retainedProjection == null
            ? null
            : HouseholdSplitAwareExpenseSnapshot(
                expenses: retainedProjection.actualExpenses,
                splits: retainedProjection.splits,
                hasDeferredSplitReferences:
                    retainedProjection.hasDeferredSplitReferences,
              ),
      );
      final actualExpenses = splitAwareSnapshot.expenses;
      final expensesWithRecurring =
          query.startDate == null || query.endDate == null
              ? actualExpenses
              : mergeActualExpensesWithProjectedRecurring(
                  actualExpenses: actualExpenses,
                  recurringTransactions: recurringTransactions,
                  rangeStart: query.startDate!,
                  rangeEnd: query.endDate!,
                  confirmedOccurrenceSuppressionEntries:
                      occurrenceResolution.suppressionEntries,
                  selectedCurrency: query.selectedCurrency ?? 'USD',
                  selectedCurrencies: query.normalizedCurrencies,
                  includeFutureOccurrences: true,
                );
      return HouseholdDashboardProjection(
        actualExpenses: actualExpenses,
        expensesWithRecurring: expensesWithRecurring,
        splits: splitAwareSnapshot.splits,
        recurringTransactions: recurringTransactions,
        hasDeferredSplitReferences:
            splitAwareSnapshot.hasDeferredSplitReferences,
      );
    }

    final baseExpenses = transactionsAsync.valueOrNull;
    final baseSplits = splitsAsync.valueOrNull;
    final recurringTransactions = recurringState.data.valueOrNull;
    if (baseExpenses != null &&
        baseSplits != null &&
        recurringTransactions != null) {
      final projection = buildProjection(
        baseExpenses: baseExpenses,
        baseSplits: baseSplits,
        recurringTransactions: recurringTransactions,
      );
      if (!projection.hasDeferredSplitReferences) {
        refreshCache.put(query, projection);
      }
      return AsyncValue.data(projection);
    }

    if (retained != null) {
      final projection = buildProjection(
        baseExpenses: baseExpenses ?? retained.actualExpenses,
        baseSplits: baseSplits ?? retained.splits,
        recurringTransactions:
            recurringTransactions ?? retained.recurringTransactions,
        retainedProjection: retained,
      );
      return AsyncValue.data(projection);
    }

    if (dependencyState.hasError) {
      return AsyncValue.error(
        dependencyState.error!,
        dependencyState.stackTrace ?? StackTrace.current,
      );
    }
    return const AsyncValue.loading();
  },
);

class _HouseholdDerivedSummaryCacheKey {
  const _HouseholdDerivedSummaryCacheKey({
    required this.userId,
    required this.params,
    required this.includeBudgets,
  });

  final String userId;
  final HouseholdSummaryParams params;
  final bool includeBudgets;

  @override
  bool operator ==(Object other) =>
      other is _HouseholdDerivedSummaryCacheKey &&
      userId == other.userId &&
      params == other.params &&
      includeBudgets == other.includeBudgets;

  @override
  int get hashCode => Object.hash(userId, params, includeBudgets);
}

/// Keeps the last complete, scope-specific derived summary visible while one
/// of its local-first inputs refreshes. This cache is intentionally in-memory:
/// persisted transaction/member/budget caches remain the restart source of
/// truth, while this only prevents an in-session refresh from blanking cards.
class _HouseholdDerivedSummaryRefreshCache {
  final _entries = <_HouseholdDerivedSummaryCacheKey, HouseholdSummary>{};

  HouseholdSummary? operator [](_HouseholdDerivedSummaryCacheKey key) =>
      _entries[key];

  void put(_HouseholdDerivedSummaryCacheKey key, HouseholdSummary summary) {
    _entries[key] = summary;
  }
}

final _householdDerivedSummaryRefreshCacheProvider =
    Provider<_HouseholdDerivedSummaryRefreshCache>(
  (ref) => _HouseholdDerivedSummaryRefreshCache(),
);

/// A refresh must not replace a complete household card with a loading state.
/// Without a retained value, callers should use the normal initial-loading or
/// error state.
AsyncValue<HouseholdSummary?>? retainHouseholdSummaryDuringRefresh({
  required AsyncValue<bool> dependencyState,
  required HouseholdSummary? retainedSummary,
}) {
  if (retainedSummary == null) return null;
  if (dependencyState.hasError || !dependencyState.hasValue) {
    return AsyncValue<HouseholdSummary?>.data(retainedSummary);
  }
  return null;
}

final householdDashboardSplitsProvider = Provider.autoDispose
    .family<AsyncValue<List<ExpenseSplitGroup>>, DashboardScopeQuery>(
  (ref, query) {
    final householdId = query.householdId?.trim();
    if (query.userId.isEmpty || householdId == null || householdId.isEmpty) {
      return const AsyncValue.data(<ExpenseSplitGroup>[]);
    }

    final transactionsAsync =
        ref.watch(dashboardCalendarTransactionsProvider(query));
    final baseTransactions = transactionsAsync.valueOrNull;
    if (baseTransactions == null) {
      if (transactionsAsync.hasError) {
        return AsyncValue.error(
          transactionsAsync.error!,
          transactionsAsync.stackTrace ?? StackTrace.current,
        );
      }
      return const AsyncValue.loading();
    }

    final localOverlay = ref.watch(
      dashboardLocalOverlayTransactionsProvider(query),
    );
    final optimisticExpenses = ref.watch(
      householdOptimisticExpensesProvider.select(
        (state) => state[householdId] ?? const <ExpenseEntry>[],
      ),
    );
    final deletedIds = ref.watch(
      householdOptimisticDeletedExpenseIdsProvider.select(
        (state) => state[householdId] ?? const <String>{},
      ),
    );
    final mergedExpenses = mergeHouseholdDashboardExpenses(
      base: baseTransactions,
      localOverlay: localOverlay,
      query: query,
      optimisticExpenses: optimisticExpenses,
      deletedIds: deletedIds,
    );
    // A projected recurring occurrence inherits its template's split-group ID.
    // That group is not referenced by a materialized transaction until the
    // occurrence is confirmed, so include it explicitly. Otherwise household
    // cards see the projection without its member allocations and attribute the
    // whole amount to the series creator.
    final recurringState =
        ref.watch(recurringTransactionsProvider(householdId));
    final referencedIds = householdDashboardReferencedSplitGroupIds(
      actualExpenses: mergedExpenses,
      recurringTransactions:
          recurringState.data.valueOrNull ?? const <RecurringTransaction>[],
    );
    final legacyOptimisticSplitExpenseIds = mergedExpenses
        .where(
          (entry) =>
              entry.splitGroupId?.trim().startsWith('optimistic_split_') ==
              true,
        )
        .map((entry) => entry.id)
        .toSet();
    if (referencedIds.isEmpty && legacyOptimisticSplitExpenseIds.isEmpty) {
      return const AsyncValue.data(<ExpenseSplitGroup>[]);
    }

    final legacySplitsAsync = legacyOptimisticSplitExpenseIds.isEmpty
        ? null
        : ref.watch(
            cachedHouseholdSplitsProvider(
              HouseholdSplitsParams(householdId: householdId),
            ),
          );
    final legacySplits = legacySplitsAsync?.valueOrNull;
    if (legacySplitsAsync != null && legacySplits == null) {
      if (legacySplitsAsync.hasError) {
        return AsyncValue.error(
          legacySplitsAsync.error!,
          legacySplitsAsync.stackTrace ?? StackTrace.current,
        );
      }
      return const AsyncValue.loading();
    }

    final legacyGroups = legacySplits
            ?.where(
              (group) =>
                  legacyOptimisticSplitExpenseIds.contains(group.expenseId),
            )
            .toList(growable: false) ??
        const <ExpenseSplitGroup>[];
    if (referencedIds.isEmpty) {
      return AsyncValue.data(legacyGroups);
    }

    final serverSplitsAsync = ref.watch(
      householdHomeSplitGroupsProvider(
        HouseholdHomeSplitGroupsParams(
          userId: query.userId,
          householdId: householdId,
          splitGroupIds: referencedIds,
        ),
      ),
    );
    final serverSplits = serverSplitsAsync.valueOrNull;
    if (serverSplits == null) {
      if (serverSplitsAsync.hasError) {
        return AsyncValue.error(
          serverSplitsAsync.error!,
          serverSplitsAsync.stackTrace ?? StackTrace.current,
        );
      }
      return const AsyncValue.loading();
    }

    final groupsById = <String, ExpenseSplitGroup>{
      for (final group in serverSplits) group.id: group,
      for (final group in legacyGroups) group.id: group,
    };
    return AsyncValue.data(groupsById.values.toList(growable: false));
  },
);

AsyncValue<bool> householdDashboardDependencyState(
  Iterable<AsyncValue<Object?>> dependencies,
) {
  for (final dependency in dependencies) {
    if (dependency.valueOrNull == null && dependency.hasError) {
      return AsyncValue.error(
        dependency.error!,
        dependency.stackTrace ?? StackTrace.current,
      );
    }
  }

  for (final dependency in dependencies) {
    if (dependency.valueOrNull == null) {
      return const AsyncValue.loading();
    }
  }

  return const AsyncValue.data(true);
}

final householdDerivedSummaryProvider = Provider.autoDispose
    .family<AsyncValue<HouseholdSummary?>, HouseholdSummaryParams>(
  (ref, params) => _buildHouseholdDerivedSummary(
    ref,
    params,
    includeBudgets: true,
  ),
);

final householdDerivedSummaryWithoutBudgetsProvider = Provider.autoDispose
    .family<AsyncValue<HouseholdSummary?>, HouseholdSummaryParams>(
  (ref, params) => _buildHouseholdDerivedSummary(
    ref,
    params,
    includeBudgets: false,
  ),
);

AsyncValue<HouseholdSummary?> _buildHouseholdDerivedSummary(
  Ref ref,
  HouseholdSummaryParams params, {
  required bool includeBudgets,
}) {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null || currentUserId.isEmpty) {
    return const AsyncValue.data(null);
  }
  final summaryCacheKey = _HouseholdDerivedSummaryCacheKey(
    userId: currentUserId,
    params: params,
    includeBudgets: includeBudgets,
  );
  final summaryRefreshCache = ref.read(
    _householdDerivedSummaryRefreshCacheProvider,
  );
  final retainedSummary = summaryRefreshCache[summaryCacheKey];
  final rangeStart = _normalizeDate(DateTime.parse(params.startDate));
  final rangeEnd = _normalizeDate(DateTime.parse(params.endDate));
  final selectedCurrencies = ref.watch(
    homeFilterProvider.select((state) => state.normalizedSelectedCurrencies),
  );
  final query = DashboardScopeQuery(
    userId: currentUserId,
    householdId: params.householdId,
    selectedCurrency: params.currency,
    selectedCurrencies: selectedCurrencies,
    startDate: rangeStart,
    endDate: rangeEnd,
  );
  final projectionAsync = ref.watch(
    householdDashboardProjectionProvider(query),
  );
  final membersAsync = ref.watch(householdMembersProvider(params.householdId));
  final budgetsAsync = includeBudgets
      ? ref.watch(householdBudgetsProvider(params.householdId))
      : const AsyncValue<List<SharedBudget>>.data(<SharedBudget>[]);

  final dependencyState = householdDashboardDependencyState(
    <AsyncValue<Object?>>[
      projectionAsync,
      membersAsync,
      budgetsAsync,
    ],
  );
  if (dependencyState.hasError) {
    final retained = retainHouseholdSummaryDuringRefresh(
      dependencyState: dependencyState,
      retainedSummary: retainedSummary,
    );
    if (retained != null) return retained;
    return AsyncValue.error(
      dependencyState.error!,
      dependencyState.stackTrace ?? StackTrace.current,
    );
  }
  if (!dependencyState.hasValue) {
    final retained = retainHouseholdSummaryDuringRefresh(
      dependencyState: dependencyState,
      retainedSummary: retainedSummary,
    );
    if (retained != null) return retained;
    return const AsyncValue.loading();
  }

  final projection = projectionAsync.valueOrNull!;
  final splits = projection.splits;
  final members = membersAsync.valueOrNull!;
  final budgets = budgetsAsync.valueOrNull!;
  final expensesWithRecurring = projection.expensesWithRecurring;
  final shouldConvertCurrencies =
      selectedCurrencies != null && selectedCurrencies.length > 1;
  final rates = ref.watch(currencyRateTableProvider).valueOrNull ??
      const CurrencyRateTable(
        baseCurrency: 'USD',
        rates: CurrencyRates.rates,
        isStale: true,
      );
  final summaryExpenses = shouldConvertCurrencies
      ? convertTransactionsToCurrency(
          expensesWithRecurring,
          targetCurrency: params.currency,
          rates: rates,
        )
      : expensesWithRecurring;
  final summarySplits = shouldConvertCurrencies
      ? _convertSplitGroupsToCurrency(
          splits,
          targetCurrency: params.currency,
          rates: rates,
        )
      : splits;

  final summary = _buildHouseholdSummary(
    params: params,
    expenses: summaryExpenses,
    splits: summarySplits,
    members: members,
    budgets: budgets,
  );

  summaryRefreshCache.put(summaryCacheKey, summary);

  return AsyncValue.data(summary);
}

List<ExpenseSplitGroup> _convertSplitGroupsToCurrency(
  List<ExpenseSplitGroup> groups, {
  required String targetCurrency,
  required CurrencyRateTable rates,
}) {
  final normalizedTarget = targetCurrency.trim().toUpperCase();
  return groups.map((group) {
    final sourceCurrency = group.currency.trim().toUpperCase().isEmpty
        ? normalizedTarget
        : group.currency.trim().toUpperCase();
    return ExpenseSplitGroup(
      id: group.id,
      householdId: group.householdId,
      expenseId: group.expenseId,
      payerUserId: group.payerUserId,
      splitType: group.splitType,
      currency: normalizedTarget,
      totalAmountCents: convertAmountCentsToCurrency(
        group.totalAmountCents,
        fromCurrency: sourceCurrency,
        targetCurrency: normalizedTarget,
        rates: rates,
      ),
      description: group.description,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
      payerEmail: group.payerEmail,
      splitLines: group.splitLines?.map((line) {
        final amountCents = line.amountCents;
        return ExpenseSplitLine(
          id: line.id,
          splitGroupId: line.splitGroupId,
          userId: line.userId,
          amountCents: amountCents == null
              ? null
              : convertAmountCentsToCurrency(
                  amountCents,
                  fromCurrency: sourceCurrency,
                  targetCurrency: normalizedTarget,
                  rates: rates,
                ),
          percentage: line.percentage,
          shares: line.shares,
          isSettled: line.isSettled,
          settledAt: line.settledAt,
          createdAt: line.createdAt,
          updatedAt: line.updatedAt,
          userEmail: line.userEmail,
          userName: line.userName,
          settledByUserId: line.settledByUserId,
        );
      }).toList(growable: false),
    );
  }).toList(growable: false);
}

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

    final absoluteAmount = e.amountCents.abs();
    if (e.countsTowardIncome) {
      totalIncomeCents += absoluteAmount;
      continue;
    }
    if (e.effectiveSpendingMultiplier == 0) continue;
    final amount = absoluteAmount * e.effectiveSpendingMultiplier;

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

    if (e.effectiveSpendingMultiplier == 0) continue;

    final amount = e.amountCents.abs() * e.effectiveSpendingMultiplier;
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
          spentCents +=
              (line.amountCents ?? 0).abs() * e.effectiveSpendingMultiplier;
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
