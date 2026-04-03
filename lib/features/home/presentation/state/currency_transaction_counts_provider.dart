import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

/// Returns a map of `CURRENCY_CODE -> transactionCount` for the current user.
///
/// Notes:
/// - Counts are computed from the `expenses` table and include both expenses and
///   income rows (since both live in that table).
/// - This mirrors the query previously implemented inside
///   `currency_selector_modal.dart`, but moved to a provider so the UI remains
///   reactive and consistent with the app's data flow.
final currencyTransactionCountsProvider =
    Provider.autoDispose<Map<String, int>>((ref) {
  final scope = ref.watch(householdScopeProvider);
  final analyticsData = ref.watch(analyticsProvider);

  final activeHouseholdId =
      scope.activeAccountType == ActiveWalletType.personal
          ? null
          : scope.activeAccountHouseholdId;
  final optimistic = ref.watch(
    householdOptimisticExpensesProvider.select(
      (state) => (activeHouseholdId == null || activeHouseholdId.isEmpty)
          ? const <ExpenseEntry>[]
          : state[activeHouseholdId] ?? const <ExpenseEntry>[],
    ),
  );

  final source = optimistic.isEmpty
      ? analyticsData.allExpenses
      : mergeHouseholdExpenses(analyticsData.allExpenses, optimistic);

  final counts = <String, int>{};
  for (final expense in source) {
    final householdId = expense.householdId;
    final matchesScope = switch (scope.activeAccountType) {
      ActiveWalletType.personal =>
        householdId == null || householdId.trim().isEmpty,
      ActiveWalletType.household ||
      ActiveWalletType.portfolio =>
        activeHouseholdId != null && householdId == activeHouseholdId,
    };
    if (!matchesScope) continue;

    final code = (expense.currency ?? '').toUpperCase();
    if (code.isEmpty) continue;
    counts[code] = (counts[code] ?? 0) + 1;
  }

  return counts;
});
