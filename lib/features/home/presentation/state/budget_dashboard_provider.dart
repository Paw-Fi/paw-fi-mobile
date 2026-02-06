import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/shared_budget.dart';

class ConsolidatedTransaction {
  final ExpenseEntry entry;
  final String accountLabel;
  final String? accountId; // null = personal
  final bool isPortfolio;
  final String? householdName;

  const ConsolidatedTransaction({
    required this.entry,
    required this.accountLabel,
    this.accountId,
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
  final user = ref.watch(authProvider);
  if (user.uid.isEmpty) {
    return const AsyncValue.data(DashboardData(isLoading: false));
  }

  // 1. Personal Expenses & Budgets
  final analytics = ref.watch(analyticsProvider);
  // We prioritize showing data even if reloading
  if (analytics.isLoading && (analytics.hasLoadedOnce != true)) {
    return const AsyncValue.loading();
  }

  // 2. Households
  final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));

  return householdsAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
      data: (households) {
        final List<ConsolidatedTransaction> merged = [];
        final Set<String> seenIds = {};
        final Map<String, List<SharedBudget>> householdBudgetsMap = {};

        // Helper to add unique
        void add(ConsolidatedTransaction tx) {
          if (seenIds.contains(tx.entry.id)) return;
          seenIds.add(tx.entry.id);
          merged.add(tx);
        }

        // Add Personal (Where householdId is null or empty)
        for (final e in analytics.allExpenses) {
          if (e.isRecurring) continue;
          if (e.householdId == null || e.householdId!.isEmpty) {
            add(ConsolidatedTransaction(
              entry: e,
              accountLabel: 'Personal', // TODO: Localize
              accountId: null,
            ));
          }
        }

        // Add Households
        bool anyHouseholdLoading = false;
        for (final h in households) {
          final params = HouseholdExpensesParams(householdId: h.id);
          final expensesAsync = ref.watch(householdExpensesProvider(params));

          // Fetch budgets
          final budgetsAsync = ref.watch(householdBudgetsProvider(h.id));
          if (budgetsAsync.hasValue) {
            householdBudgetsMap[h.id] = budgetsAsync.value!;
          }

          if (expensesAsync.isLoading && !expensesAsync.hasValue) {
            anyHouseholdLoading = true;
          }

          final expenses = expensesAsync.valueOrNull ?? [];
          for (final e in expenses) {
            if (e.isRecurring) continue;
            add(ConsolidatedTransaction(
              entry: e,
              accountLabel: h.name,
              accountId: h.id,
              isPortfolio: h.isPortfolio,
              householdName: h.name,
            ));
          }
        }

        // Sort by Date DESC, CreatedAt DESC
        merged.sort((a, b) {
          final dateComp = b.entry.date.compareTo(a.entry.date);
          if (dateComp != 0) return dateComp;
          return b.entry.createdAt.compareTo(a.entry.createdAt);
        });

        return AsyncValue.data(DashboardData(
          allTransactions: merged,
          households: households,
          allBudgets: analytics.allBudgets,
          householdBudgets: householdBudgetsMap,
          isLoading: anyHouseholdLoading,
        ));
      });
});
