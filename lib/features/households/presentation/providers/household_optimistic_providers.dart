import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';

List<ExpenseEntry> mergeHouseholdExpenses(
  List<ExpenseEntry> base,
  List<ExpenseEntry> optimistic,
) {
  if (optimistic.isEmpty) return base;
  final seen = <String>{};
  final merged = <ExpenseEntry>[];

  for (final entry in base) {
    if (entry.id.isEmpty) continue;
    if (seen.add(entry.id)) merged.add(entry);
  }
  for (final entry in optimistic) {
    if (entry.id.isEmpty) continue;
    if (seen.add(entry.id)) merged.add(entry);
  }

  merged.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    return b.createdAt.compareTo(a.createdAt);
  });

  return merged;
}

List<ExpenseSplitGroup> mergeHouseholdSplits(
  List<ExpenseSplitGroup> base,
  List<ExpenseSplitGroup> optimistic,
) {
  if (optimistic.isEmpty) return base;
  final baseExpenseIds = base.map((g) => g.expenseId).toSet();
  final merged = <ExpenseSplitGroup>[...base];
  for (final group in optimistic) {
    if (!baseExpenseIds.contains(group.expenseId)) {
      merged.add(group);
    }
  }
  merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return merged;
}

class OptimisticHouseholdExpensesNotifier
    extends StateNotifier<Map<String, List<ExpenseEntry>>> {
  OptimisticHouseholdExpensesNotifier() : super(const {});

  void addExpense(String householdId, ExpenseEntry entry) {
    final existing = state[householdId] ?? const <ExpenseEntry>[];
    if (existing.any((e) => e.id == entry.id)) return;
    final updated = <ExpenseEntry>[entry, ...existing];
    state = {...state, householdId: updated};
  }

  void removeExpense(String householdId, String expenseId) {
    final existing = state[householdId];
    if (existing == null || existing.isEmpty) return;
    final filtered = existing.where((e) => e.id != expenseId).toList();
    if (filtered.length == existing.length) return;
    final next = {...state};
    if (filtered.isEmpty) {
      next.remove(householdId);
    } else {
      next[householdId] = filtered;
    }
    state = next;
  }

  void replaceExpense(String householdId, String oldExpenseId, ExpenseEntry entry) {
    final existing = state[householdId] ?? const <ExpenseEntry>[];
    final filtered = existing.where((e) => e.id != oldExpenseId).toList();
    final updated = <ExpenseEntry>[entry, ...filtered];
    state = {...state, householdId: updated};
  }

  void pruneIfInServer(String householdId, List<ExpenseEntry> server) {
    final existing = state[householdId];
    if (existing == null || existing.isEmpty) return;
    final serverIds = server.map((e) => e.id).toSet();
    final filtered =
        existing.where((e) => !serverIds.contains(e.id)).toList();
    if (filtered.length == existing.length) return;
    final next = {...state};
    if (filtered.isEmpty) {
      next.remove(householdId);
    } else {
      next[householdId] = filtered;
    }
    state = next;
  }

  void clearHousehold(String householdId) {
    if (!state.containsKey(householdId)) return;
    final next = {...state}..remove(householdId);
    state = next;
  }
}

final householdOptimisticExpensesProvider = StateNotifierProvider<
    OptimisticHouseholdExpensesNotifier, Map<String, List<ExpenseEntry>>>(
  (ref) => OptimisticHouseholdExpensesNotifier(),
);

class OptimisticHouseholdSplitsNotifier
    extends StateNotifier<Map<String, List<ExpenseSplitGroup>>> {
  OptimisticHouseholdSplitsNotifier() : super(const {});

  void addSplitGroup(String householdId, ExpenseSplitGroup group) {
    final existing = state[householdId] ?? const <ExpenseSplitGroup>[];
    if (existing.any((g) => g.expenseId == group.expenseId)) return;
    final updated = <ExpenseSplitGroup>[group, ...existing];
    state = {...state, householdId: updated};
  }

  void pruneIfInServer(String householdId, List<ExpenseSplitGroup> server) {
    final existing = state[householdId];
    if (existing == null || existing.isEmpty) return;
    final serverExpenseIds = server.map((g) => g.expenseId).toSet();
    final filtered = existing
        .where((g) => !serverExpenseIds.contains(g.expenseId))
        .toList();
    if (filtered.length == existing.length) return;
    final next = {...state};
    if (filtered.isEmpty) {
      next.remove(householdId);
    } else {
      next[householdId] = filtered;
    }
    state = next;
  }

  void clearHousehold(String householdId) {
    if (!state.containsKey(householdId)) return;
    final next = {...state}..remove(householdId);
    state = next;
  }
}

final householdOptimisticSplitsProvider = StateNotifierProvider<
    OptimisticHouseholdSplitsNotifier, Map<String, List<ExpenseSplitGroup>>>(
  (ref) => OptimisticHouseholdSplitsNotifier(),
);
