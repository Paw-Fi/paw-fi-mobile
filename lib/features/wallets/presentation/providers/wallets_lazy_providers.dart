import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/state.dart'
    show analyticsProvider;
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart'
    show PocketsScopeType, loadScopedRecurringTransactions;
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_snapshot_math.dart';

final walletsRefreshSignalProvider = StateProvider<int>((ref) => 0);

abstract class WalletsDataService {
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query);
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(WalletsMonthQuery query);
}

class SupabaseWalletsDataService implements WalletsDataService {
  const SupabaseWalletsDataService();

  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    // CRITICAL: keep the wallets history RPC pointed at the recurring-aware v2
    // wrapper.
    // STRICT REQUIREMENT: switching back to v1 removes recurring month deltas
    // from the main wallets history response.
    final response = await supabase.rpc(
      'get_wallets_history_v2',
      params: query.toHistoryRpcParams(),
    );
    return WalletsHistorySummary.fromJson(_toMap(response));
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
      WalletsMonthQuery query) async {
    // CRITICAL: keep the wallets month snapshot RPC pointed at the
    // recurring-aware v2 wrapper.
    // STRICT REQUIREMENT: switching back to v1 drops recurring month
    // occurrences from wallet balances and month totals.
    final response = await supabase.rpc(
      'get_wallets_month_snapshot_v2',
      params: query.toRpcParams(),
    );
    return WalletsMonthSnapshot.fromJson(_toMap(response));
  }

  Map<String, dynamic> _toMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    return const <String, dynamic>{};
  }
}

final walletsDataServiceProvider = Provider<WalletsDataService>((ref) {
  return const SupabaseWalletsDataService();
});

final walletsHistoryProvider =
    FutureProvider.family<WalletsHistorySummary, WalletsScopeQuery>(
  (ref, query) async {
    ref.watch(walletsRefreshSignalProvider);
    ref.watch(dashboardRefreshSignalProvider);
    final now = _walletProjectionNow(ref);
    final endInclusive = DateTime(now.year, now.month, now.day);
    // CRITICAL: the wallets landing page history must be built from the
    // recurring-aware transaction set.
    // STRICT REQUIREMENT: do not replace this with raw posted transactions
    // only, or recurring bills disappear from the monthly graph/history.
    final recurringAwareData = await _loadWalletRecurringAwareData(
      ref,
      query,
      endInclusive: endInclusive,
    );
    final availableMonths = buildWalletAvailableMonths(
      now: now,
      transactions: recurringAwareData.transactions,
    );
    final netWorthSeries = availableMonths
        .reversed
        .map((monthStart) {
          final snapshot = buildWalletSnapshot(
            wallets: recurringAwareData.wallets,
            transactions: recurringAwareData.transactions,
            endExclusive: _walletSnapshotEndExclusive(
              monthStart: monthStart,
              now: now,
            ),
          );
          return WalletNetWorthPoint(
            monthStart: monthStart,
            netWorthCents: snapshot.netWorthCents,
          );
        })
        .toList(growable: false);

    return WalletsHistorySummary(
      availableMonths: availableMonths,
      netWorthSeries: netWorthSeries,
    );
  },
);

final walletsMonthSnapshotProvider =
    FutureProvider.autoDispose.family<WalletsMonthSnapshot, WalletsMonthQuery>(
  (ref, query) async {
    ref.watch(walletsRefreshSignalProvider);
    ref.watch(dashboardRefreshSignalProvider);
    final now = _walletProjectionNow(ref);
    final endExclusive = _walletSnapshotEndExclusive(
      monthStart: query.monthStart,
      now: now,
    );
    // CRITICAL: every wallet month card/snapshot must use the recurring-aware
    // month transaction set.
    // STRICT REQUIREMENT: if recurring projections are removed here, wallets
    // page month totals fall out of sync with wallet details and pockets.
    final recurringAwareData = await _loadWalletRecurringAwareData(
      ref,
      query.scope,
      endInclusive: endExclusive.subtract(const Duration(days: 1)),
    );
    final snapshot = buildWalletSnapshot(
      wallets: recurringAwareData.wallets,
      transactions: recurringAwareData.transactions,
      endExclusive: endExclusive,
    );

    return WalletsMonthSnapshot(
      monthStart: query.monthStart,
      monthEndExclusive: endExclusive,
      incomeTotalCents: snapshot.totalIncomeCents,
      spentTotalCents: snapshot.totalSpentCents,
      netWorthCents: snapshot.netWorthCents,
      walletBalances: snapshot.walletBalances,
    );
  },
);

class _WalletRecurringAwareData {
  const _WalletRecurringAwareData({
    required this.wallets,
    required this.transactions,
  });

  final List<WalletEntity> wallets;
  final List<ExpenseEntry> transactions;
}

DateTime _walletProjectionNow(Ref ref) {
  final preferredTimezone =
      ref.read(analyticsProvider).contact?.preferredTimezone;
  final now = effectiveNow(preferredTimezone: preferredTimezone);
  return DateTime(now.year, now.month, now.day);
}

DateTime _walletSnapshotEndExclusive({
  required DateTime monthStart,
  required DateTime now,
}) {
  final normalizedMonthStart = DateTime(monthStart.year, monthStart.month, 1);
  final currentMonthStart = DateTime(now.year, now.month, 1);
  if (normalizedMonthStart == currentMonthStart) {
    return now.add(const Duration(days: 1));
  }
  return DateTime(
    normalizedMonthStart.year,
    normalizedMonthStart.month + 1,
    1,
  );
}

Future<_WalletRecurringAwareData> _loadWalletRecurringAwareData(
  Ref ref,
  WalletsScopeQuery query, {
  required DateTime endInclusive,
}) async {
  final wallets = await _fetchScopedWallets(query.householdId);
  final actualTransactions = await _fetchWalletActualTransactions(
    ref,
    query,
    endInclusive: endInclusive,
  );
  final recurringTransactions = await _fetchScopedRecurringTransactions(
    ref,
    query,
  );
  final projectionRangeStart = _resolveWalletProjectionRangeStart(
    actualTransactions: actualTransactions,
    recurringTransactions: recurringTransactions,
    fallbackMonthStart: DateTime(endInclusive.year, endInclusive.month, 1),
  );
  final projectedTransactions = _buildProjectedWalletRecurringTransactions(
    recurringTransactions: recurringTransactions,
    actualTransactions: actualTransactions,
    selectedCurrency: query.selectedCurrency,
    rangeStart: projectionRangeStart,
    rangeEndInclusive: endInclusive,
  );

  return _WalletRecurringAwareData(
    wallets: wallets,
    transactions: <ExpenseEntry>[
      ...actualTransactions,
      ...projectedTransactions,
    ],
  );
}

Future<List<WalletEntity>> _fetchScopedWallets(String? householdId) async {
  final response = await supabase.functions.invoke(
    'list-wallets',
    body: {
      if (householdId != null && householdId.trim().isNotEmpty)
        'householdId': householdId,
    },
  );

  final payload = response.data as Map<String, dynamic>?;
  if (payload == null || payload['success'] != true) {
    throw Exception(payload?['error']?.toString() ?? 'Failed to load wallets');
  }

  final data = payload['data'] as List<dynamic>? ?? const [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(WalletEntity.fromJson)
      .where((wallet) => !wallet.isArchived)
      .toList(growable: false);
}

Future<List<ExpenseEntry>> _fetchWalletActualTransactions(
  Ref ref,
  WalletsScopeQuery query, {
  required DateTime endInclusive,
}) async {
  final service = ref.read(transactionsFeedServiceProvider);
  final scope = ref.read(householdScopeProvider);
  final transactions = await service.fetchAllPages(
    TransactionsFeedQuery(
      userId: query.userId,
      householdId: query.householdId,
      selectedCurrency: query.selectedCurrency,
      selectedCategory: null,
      selectedAccountId: null,
      selectedCategories: null,
      selectedType: 'all',
      searchQuery: '',
      startDate: null,
      endDate: endInclusive,
    ),
  );

  return filterWalletTransactions(
    allExpenses: transactions,
    scope: scope,
    selectedCurrency: query.selectedCurrency,
  );
}

Future<List<RecurringTransaction>> _fetchScopedRecurringTransactions(
  Ref ref,
  WalletsScopeQuery query,
) {
  final householdScope = ref.read(householdScopeProvider);
  final scope = switch (householdScope.activeAccountType) {
    ActiveWalletType.personal => PocketsScopeType.personal,
    ActiveWalletType.portfolio => PocketsScopeType.portfolio,
    ActiveWalletType.household => PocketsScopeType.household,
  };

  return loadScopedRecurringTransactions(
    userId: query.userId,
    scope: scope,
    householdId: query.householdId,
  );
}

DateTime _resolveWalletProjectionRangeStart({
  required List<ExpenseEntry> actualTransactions,
  required List<RecurringTransaction> recurringTransactions,
  required DateTime fallbackMonthStart,
}) {
  var earliest = DateTime(
    fallbackMonthStart.year,
    fallbackMonthStart.month,
    1,
  );

  for (final transaction in actualTransactions) {
    final monthStart = DateTime(transaction.date.year, transaction.date.month);
    if (monthStart.isBefore(earliest)) {
      earliest = monthStart;
    }
  }

  for (final recurring in recurringTransactions) {
    final anchor = recurring.recurrenceRule?.anchorDate ?? recurring.date;
    final monthStart = DateTime(anchor.year, anchor.month);
    if (monthStart.isBefore(earliest)) {
      earliest = monthStart;
    }
  }

  return earliest;
}

List<ExpenseEntry> _buildProjectedWalletRecurringTransactions({
  required List<RecurringTransaction> recurringTransactions,
  required List<ExpenseEntry> actualTransactions,
  required String selectedCurrency,
  required DateTime rangeStart,
  required DateTime rangeEndInclusive,
}) {
  if (recurringTransactions.isEmpty) {
    return const <ExpenseEntry>[];
  }

  final recurringById = <String, RecurringTransaction>{
    for (final recurring in recurringTransactions) recurring.id: recurring,
  };
  final projectedExpenses = projectRecurringTransactionsAsExpenseEntries(
    recurringTransactions: recurringTransactions,
    rangeStart: rangeStart,
    rangeEnd: rangeEndInclusive,
    selectedCurrency: selectedCurrency,
  ).map((expense) {
    final recurringId =
        extractRecurringTransactionIdFromProjectedExpenseId(expense.id);
    final source = recurringId == null ? null : recurringById[recurringId];
    final accountId = source?.accountId?.trim();
    // CRITICAL: preserve the source recurring account_id on projected wallet
    // rows.
    // STRICT REQUIREMENT: without this, projected recurring transactions lose
    // wallet ownership and either fall into the legacy default wallet or
    // disappear from wallet-specific calculations.
    return expense.copyWith(
      accountId: accountId == null || accountId.isEmpty ? null : accountId,
    );
  }).toList(growable: false);

  // CRITICAL: wallet month snapshots/history must include projected recurring
  // transactions month-by-month.
  // STRICT REQUIREMENT: keep this local recurring-aware path until every
  // wallet summary RPC used by the app is guaranteed to return the same
  // recurring-expanded balances, or the wallets page will regress again.
  return dedupeProjectedRecurringExpenseEntries(
    projectedExpenses: projectedExpenses,
    actualExpenses: actualTransactions,
  );
}
