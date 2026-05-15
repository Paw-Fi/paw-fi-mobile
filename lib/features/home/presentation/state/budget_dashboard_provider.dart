import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/shared_budget.dart';

class ConsolidatedTransaction {
  final ExpenseEntry entry;
  final String spaceLabel;
  final String? spaceId; // null = personal
  final bool isPortfolio;
  final String? householdName;

  const ConsolidatedTransaction({
    required this.entry,
    required this.spaceLabel,
    this.spaceId,
    this.isPortfolio = false,
    this.householdName,
  });
}

class DashboardData {
  final List<ConsolidatedTransaction> allTransactions;
  final List<Household> households;
  final List<DailyBudgetEntry> allBudgets; // Personal budgets
  final Map<String, List<SharedBudget>> householdBudgets; // Household budgets
  final bool isLoading;

  const DashboardData({
    this.allTransactions = const [],
    this.households = const [],
    this.allBudgets = const [],
    this.householdBudgets = const {},
    this.isLoading = false,
  });
}

final budgetDashboardProvider =
    Provider.autoDispose<AsyncValue<DashboardData>>((ref) {
  return ref.watch(budgetDashboardDataProvider);
});

final budgetDashboardDataProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  final user = ref.watch(authProvider);
  if (user.uid.isEmpty) {
    return const DashboardData(isLoading: false);
  }

  final analytics = ref.watch(analyticsProvider);
  final merged = <ConsolidatedTransaction>[];
  final seenIds = <String>{};

  void add(ConsolidatedTransaction tx) {
    if (seenIds.contains(tx.entry.id)) return;
    seenIds.add(tx.entry.id);
    merged.add(tx);
  }

  final personalTransactions = await ref.watch(
    transactionsFeedAllItemsProvider(
      _overviewTransactionsQuery(
        userId: user.uid,
        householdId: null,
      ),
    ).future,
  );
  for (final entry in personalTransactions) {
    if (entry.householdId == null || entry.householdId!.isEmpty) {
      add(ConsolidatedTransaction(
        entry: entry,
        spaceLabel: 'Personal', // TODO: Localize
        spaceId: null,
      ));
    }
  }

  final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
  if (householdsAsync.hasError && !householdsAsync.hasValue) {
    Error.throwWithStackTrace(
      householdsAsync.error!,
      householdsAsync.asError?.stackTrace ?? StackTrace.current,
    );
  }

  final households = householdsAsync.valueOrNull;
  if (households == null) {
    merged.sort(_compareConsolidatedTransactions);
    return DashboardData(
      allTransactions: merged,
      households: const [],
      allBudgets: analytics.allBudgets,
      householdBudgets: const {},
      isLoading: true,
    );
  }

  for (final household in households) {
    final householdTransactions = await ref.watch(
      transactionsFeedAllItemsProvider(
        _overviewTransactionsQuery(
          userId: user.uid,
          householdId: household.id,
        ),
      ).future,
    );

    for (final entry in householdTransactions) {
      add(ConsolidatedTransaction(
        entry: entry,
        spaceLabel: household.name,
        spaceId: household.id,
        isPortfolio: household.isPortfolio,
        householdName: household.name,
      ));
    }
  }

  merged.sort(_compareConsolidatedTransactions);

  return DashboardData(
    allTransactions: merged,
    households: households,
    allBudgets: analytics.allBudgets,
    householdBudgets: const {},
    isLoading: false,
  );
});

TransactionsFeedQuery _overviewTransactionsQuery({
  required String userId,
  required String? householdId,
}) {
  return TransactionsFeedQuery(
    userId: userId,
    householdId: householdId,
    selectedCurrency: null,
    selectedCategory: null,
    selectedType: 'all',
    searchQuery: '',
    startDate: null,
    endDate: null,
    pageSize: 500,
  );
}

int _compareConsolidatedTransactions(
  ConsolidatedTransaction left,
  ConsolidatedTransaction right,
) {
  final dateComp = right.entry.date.compareTo(left.entry.date);
  if (dateComp != 0) return dateComp;
  return right.entry.createdAt.compareTo(left.entry.createdAt);
}
