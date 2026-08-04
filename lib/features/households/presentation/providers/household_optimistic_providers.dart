import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';

List<ExpenseEntry> mergeHouseholdExpenses(
  List<ExpenseEntry> base,
  List<ExpenseEntry> optimistic, {
  Set<String> deletedIds = const <String>{},
}) {
  if (optimistic.isEmpty && deletedIds.isEmpty) return base;
  final merged = <ExpenseEntry>[];
  final idIndexes = <String, int>{};
  final reconciliationIndexes = <String, int>{};

  void index(ExpenseEntry entry, int index) {
    idIndexes[entry.id] = index;
    for (final key in _householdExpenseReconciliationKeys(entry)) {
      reconciliationIndexes[key] = index;
    }
  }

  void add(ExpenseEntry entry, {required bool isOptimistic}) {
    final id = entry.id.trim();
    if (id.isEmpty || deletedIds.contains(id)) return;

    final existingIndex = idIndexes[id];
    if (existingIndex != null) {
      if (isOptimistic) {
        merged[existingIndex] = entry;
        index(entry, existingIndex);
      }
      return;
    }

    for (final key in _householdExpenseReconciliationKeys(entry)) {
      final matchingIndex = reconciliationIndexes[key];
      if (matchingIndex == null) continue;

      // A server row and its queued/local predecessor represent one mutation.
      // Keep the local row until a coherent transaction/split pair can replace
      // it; publishing both would double-count the household aggregate.
      final existing = merged[matchingIndex];
      final existingIsOptimistic = _isOptimisticHouseholdExpense(existing);
      if (existingIsOptimistic != isOptimistic) {
        if (!isOptimistic) {
          // The split-aware projection decides when it is safe to replace this
          // local row with the server row. Retaining it here prevents a server
          // transaction from briefly losing its matching provisional split.
          return;
        }
        merged[matchingIndex] = entry;
        index(entry, matchingIndex);
        return;
      }
    }

    index(entry, merged.length);
    merged.add(entry);
  }

  for (final entry in optimistic) {
    add(entry, isOptimistic: true);
  }
  for (final entry in base) {
    add(entry, isOptimistic: false);
  }

  merged.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    return b.createdAt.compareTo(a.createdAt);
  });

  return merged;
}

bool _isOptimisticHouseholdExpense(ExpenseEntry entry) {
  final id = entry.id.trim();
  if (id.startsWith('optimistic_')) return true;
  final clientRecordId = entry.clientRecordId?.trim();
  return clientRecordId != null && clientRecordId.startsWith('optimistic_');
}

List<String> _householdExpenseReconciliationKeys(ExpenseEntry entry) {
  final keys = <String>[];
  final id = entry.id.trim();
  final clientRecordId = entry.clientRecordId?.trim();
  final clientMutationId = entry.clientMutationId?.trim();
  final idempotencyKey = entry.idempotencyKey?.trim();

  if (id.isNotEmpty) keys.add('record:$id');
  if (clientRecordId != null && clientRecordId.isNotEmpty) {
    keys.add('record:$clientRecordId');
  }
  if (clientMutationId != null && clientMutationId.isNotEmpty) {
    keys.add('mutation:$clientMutationId');
  }
  if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
    keys.add('idempotency:$idempotencyKey');
  }
  return keys;
}

/// A coherent transaction/split view for split-aware household aggregates.
///
/// A split group is not optional once an expense references one. Remote
/// transaction and split reads are separate, so reconciliation can otherwise
/// publish the server transaction one provider tick before its split group.
/// That would make split-aware calculators legitimately fall back to
/// payer-full attribution. This snapshot instead retains the last complete
/// pair for that mutation until the replacement pair is complete.
class HouseholdSplitAwareExpenseSnapshot {
  const HouseholdSplitAwareExpenseSnapshot({
    required this.expenses,
    required this.splits,
    required this.hasDeferredSplitReferences,
  });

  final List<ExpenseEntry> expenses;
  final List<ExpenseSplitGroup> splits;
  final bool hasDeferredSplitReferences;
}

HouseholdSplitAwareExpenseSnapshot stabilizeHouseholdExpenseSplitSnapshot({
  required List<ExpenseEntry> expenses,
  required List<ExpenseSplitGroup> splitCandidates,
  HouseholdSplitAwareExpenseSnapshot? retained,
}) {
  final retainedByReconciliationKey = <String, ExpenseEntry>{};
  final retainedGroupsByExpenseId = <String, ExpenseSplitGroup>{};
  if (retained != null) {
    for (final entry in retained.expenses) {
      for (final key in _householdExpenseReconciliationKeys(entry)) {
        retainedByReconciliationKey[key] = entry;
      }
    }
    for (final group in retained.splits) {
      retainedGroupsByExpenseId[group.expenseId] = group;
    }
  }

  ExpenseSplitGroup? matchingGroup(ExpenseEntry expense) {
    final expectedGroupId = expense.splitGroupId?.trim();
    if (expectedGroupId == null || expectedGroupId.isEmpty) return null;
    for (final group in splitCandidates) {
      if (group.id == expectedGroupId && group.expenseId == expense.id) {
        return group;
      }
    }
    // Older app versions could persist an `optimistic_split_*` bridge after a
    // successful save response omitted the canonical UUID. That bridge is
    // never a valid backend reference. It is nevertheless safe to repair the
    // display while the regular remote refresh rewrites SQLite when exactly one
    // canonical group identifies the same server expense.
    if (!expectedGroupId.startsWith('optimistic_split_')) return null;
    final matchingExpenseGroups = splitCandidates
        .where((group) => group.expenseId == expense.id)
        .toList(growable: false);
    if (matchingExpenseGroups.length == 1) {
      return matchingExpenseGroups.single;
    }
    return null;
  }

  bool isCoherent(ExpenseEntry expense, ExpenseSplitGroup? group) {
    final expectedGroupId = expense.splitGroupId?.trim();
    if (expectedGroupId == null || expectedGroupId.isEmpty) return true;
    return group != null &&
        group.totalAmountCents == expense.amountCents.abs() &&
        _hasCompleteSplitLines(group);
  }

  ExpenseEntry? retainedMatch(ExpenseEntry current) {
    for (final key in _householdExpenseReconciliationKeys(current)) {
      final candidate = retainedByReconciliationKey[key];
      if (candidate == null) continue;
      final group = retainedGroupsByExpenseId[candidate.id];
      if (isCoherent(candidate, group)) return candidate;
    }
    return null;
  }

  final resolvedExpenses = <ExpenseEntry>[];
  final resolvedSplits = <ExpenseSplitGroup>[];
  final resolvedExpenseIds = <String>{};
  var hasDeferredSplitReferences = false;

  void addResolved(ExpenseEntry expense, ExpenseSplitGroup? group) {
    if (!resolvedExpenseIds.add(expense.id)) return;
    resolvedExpenses.add(expense);
    if (group != null) resolvedSplits.add(group);
  }

  for (final expense in expenses) {
    final group = matchingGroup(expense);
    if (isCoherent(expense, group)) {
      addResolved(expense, group);
      continue;
    }

    hasDeferredSplitReferences = true;
    final previous = retainedMatch(expense);
    if (previous == null) {
      // The expense will become visible once its required group arrives. Do
      // not fabricate payer-full attribution for a known split expense.
      continue;
    }
    addResolved(previous, retainedGroupsByExpenseId[previous.id]);
  }

  return HouseholdSplitAwareExpenseSnapshot(
    expenses: resolvedExpenses,
    splits: resolvedSplits,
    hasDeferredSplitReferences: hasDeferredSplitReferences,
  );
}

List<ExpenseSplitGroup> mergeHouseholdSplits(
  List<ExpenseSplitGroup> base,
  List<ExpenseSplitGroup> optimistic,
) {
  if (optimistic.isEmpty) return base;
  final seenExpenseIds = <String>{};
  final merged = <ExpenseSplitGroup>[];
  for (final group in optimistic) {
    if (seenExpenseIds.add(group.expenseId)) {
      merged.add(group);
    }
  }
  for (final group in base) {
    if (seenExpenseIds.add(group.expenseId)) {
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

  void replaceExpense(
      String householdId, String oldExpenseId, ExpenseEntry entry) {
    final existing = state[householdId] ?? const <ExpenseEntry>[];
    final seen = <String>{};
    final updated = <ExpenseEntry>[];

    void addIfUnique(ExpenseEntry candidate) {
      if (candidate.id.isEmpty) return;
      if (seen.add(candidate.id)) {
        updated.add(candidate);
      }
    }

    addIfUnique(entry);
    for (final candidate in existing) {
      if (candidate.id == oldExpenseId) continue;
      addIfUnique(candidate);
    }

    state = {...state, householdId: updated};
  }

  void pruneIfInServer(String householdId, List<ExpenseEntry> server) {
    final existing = state[householdId];
    if (existing == null || existing.isEmpty) return;
    final filtered = existing.where((optimistic) {
      // A transaction feed and the split feed reconcile independently. An ID
      // match by itself is not proof that this row can replace an optimistic
      // split-aware row: a stale/partial feed can carry the expense before its
      // `split_group_id` is visible. Keep the overlay until the canonical row
      // proves the same split relationship (or both rows are intentionally
      // unsplit).
      return !server.any(
        (canonical) =>
            canonical.id == optimistic.id &&
            _sameSplitGroupReference(
              canonical.splitGroupId,
              optimistic.splitGroupId,
            ),
      );
    }).toList(growable: false);
    if (filtered.length == existing.length) return;
    final next = {...state};
    if (filtered.isEmpty) {
      next.remove(householdId);
    } else {
      next[householdId] = filtered;
    }
    state = next;
  }

  void removeExpenseByIdAcrossHouseholds(String expenseId) {
    if (expenseId.isEmpty) return;
    final next = <String, List<ExpenseEntry>>{};
    for (final entry in state.entries) {
      final filtered =
          entry.value.where((expense) => expense.id != expenseId).toList();
      if (filtered.isNotEmpty) {
        next[entry.key] = filtered;
      }
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

class OptimisticHouseholdDeletedExpensesNotifier
    extends StateNotifier<Map<String, Set<String>>> {
  OptimisticHouseholdDeletedExpensesNotifier() : super(const {});

  void markDeleted(String householdId, Iterable<String> expenseIds) {
    final normalized =
        expenseIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (normalized.isEmpty) return;

    final current = state[householdId] ?? const <String>{};
    state = {
      ...state,
      householdId: {...current, ...normalized},
    };
  }

  void restore(String householdId, Iterable<String> expenseIds) {
    final current = state[householdId];
    if (current == null || current.isEmpty) return;

    final removeIds =
        expenseIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (removeIds.isEmpty) return;

    final nextIds = current.difference(removeIds);
    final next = {...state};
    if (nextIds.isEmpty) {
      next.remove(householdId);
    } else {
      next[householdId] = nextIds;
    }
    state = next;
  }
}

final householdOptimisticDeletedExpenseIdsProvider = StateNotifierProvider<
    OptimisticHouseholdDeletedExpensesNotifier, Map<String, Set<String>>>(
  (ref) => OptimisticHouseholdDeletedExpensesNotifier(),
);

class OptimisticHouseholdSplitsNotifier
    extends StateNotifier<Map<String, List<ExpenseSplitGroup>>> {
  OptimisticHouseholdSplitsNotifier() : super(const {});

  void addSplitGroup(String householdId, ExpenseSplitGroup group) {
    final existing = state[householdId] ?? const <ExpenseSplitGroup>[];
    if (existing.any((g) => g.expenseId == group.expenseId)) {
      final updated = existing
          .map((candidate) =>
              candidate.expenseId == group.expenseId ? group : candidate)
          .toList(growable: false);
      state = {...state, householdId: updated};
      return;
    }
    final updated = <ExpenseSplitGroup>[group, ...existing];
    state = {...state, householdId: updated};
  }

  void removeSplitByExpenseIdAcrossHouseholds(String expenseId) {
    if (expenseId.isEmpty) return;
    final next = <String, List<ExpenseSplitGroup>>{};
    for (final entry in state.entries) {
      final filtered =
          entry.value.where((group) => group.expenseId != expenseId).toList();
      if (filtered.isNotEmpty) {
        next[entry.key] = filtered;
      }
    }
    state = next;
  }

  /// Moves a locally complete split from its provisional transaction ID to the
  /// server ID without publishing a transaction-only state in between.
  ///
  /// The server transaction response and the split read are independent. A
  /// create reconciliation therefore cannot discard the locally configured
  /// split merely because the canonical group has not reached this process
  /// yet. When the response already carries the canonical group ID we adopt
  /// that ID immediately; otherwise the provisional ID remains a short-lived
  /// bridge until the canonical group arrives.
  ExpenseSplitGroup? rebindSplitExpenseId({
    required String fromExpenseId,
    required String toExpenseId,
    String? canonicalSplitGroupId,
  }) {
    if (fromExpenseId.isEmpty || toExpenseId.isEmpty) return null;

    for (final householdEntry in state.entries) {
      ExpenseSplitGroup? existing;
      for (final candidate in householdEntry.value) {
        if (candidate.expenseId == fromExpenseId) {
          existing = candidate;
          break;
        }
      }
      if (existing == null) continue;

      final targetGroupId = canonicalSplitGroupId?.trim().isNotEmpty == true
          ? canonicalSplitGroupId!.trim()
          : existing.id;
      final rebound = _copySplitGroup(
        existing,
        id: targetGroupId,
        expenseId: toExpenseId,
      );
      final next = <String, List<ExpenseSplitGroup>>{
        for (final entry in state.entries)
          entry.key: entry.key == householdEntry.key
              ? entry.value
                  .map(
                    (group) =>
                        group.expenseId == fromExpenseId ? rebound : group,
                  )
                  .toList(growable: false)
              : entry.value,
      };
      state = next;
      return rebound;
    }
    return null;
  }

  void pruneIfInServer(String householdId, List<ExpenseSplitGroup> server) {
    final existing = state[householdId];
    if (existing == null || existing.isEmpty) return;
    final filtered = existing.where((optimistic) {
      // Do not retire an optimistic split merely because the split endpoint
      // returned *a* group for its expense. During an edit/reconciliation that
      // can be the previous group, or a group whose lines have not arrived.
      // Only a complete, exact canonical group is safe to publish on its own.
      return !server.any(
        (canonical) => _isExactCanonicalSplit(
          canonical: canonical,
          optimistic: optimistic,
        ),
      );
    }).toList(growable: false);
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

String? _normalizedSplitGroupReference(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

bool _sameSplitGroupReference(String? left, String? right) =>
    _normalizedSplitGroupReference(left) == _normalizedSplitGroupReference(right);

bool _isExactCanonicalSplit({
  required ExpenseSplitGroup canonical,
  required ExpenseSplitGroup optimistic,
}) {
  return canonical.id == optimistic.id &&
      canonical.expenseId == optimistic.expenseId &&
      canonical.totalAmountCents == optimistic.totalAmountCents &&
      _hasCompleteSplitLines(canonical);
}

bool _hasCompleteSplitLines(ExpenseSplitGroup group) {
  final lines = group.splitLines;
  if (lines == null || lines.isEmpty) return false;
  final total = lines.fold<int>(
    0,
    (sum, line) => sum + (line.amountCents ?? 0).abs(),
  );
  return total == group.totalAmountCents.abs();
}

final householdOptimisticSplitsProvider = StateNotifierProvider<
    OptimisticHouseholdSplitsNotifier, Map<String, List<ExpenseSplitGroup>>>(
  (ref) => OptimisticHouseholdSplitsNotifier(),
);

ExpenseSplitGroup _copySplitGroup(
  ExpenseSplitGroup group, {
  required String id,
  required String expenseId,
}) {
  final lines = group.splitLines
      ?.map(
        (line) => ExpenseSplitLine(
          id: line.id,
          splitGroupId: id,
          userId: line.userId,
          amountCents: line.amountCents,
          percentage: line.percentage,
          shares: line.shares,
          isSettled: line.isSettled,
          settledAt: line.settledAt,
          createdAt: line.createdAt,
          updatedAt: line.updatedAt,
          userEmail: line.userEmail,
          userName: line.userName,
          settledByUserId: line.settledByUserId,
        ),
      )
      .toList(growable: false);
  return ExpenseSplitGroup(
    id: id,
    householdId: group.householdId,
    expenseId: expenseId,
    payerUserId: group.payerUserId,
    splitType: group.splitType,
    currency: group.currency,
    totalAmountCents: group.totalAmountCents,
    description: group.description,
    createdAt: group.createdAt,
    updatedAt: group.updatedAt,
    payerEmail: group.payerEmail,
    splitLines: lines,
  );
}

/// Reconciles the transient household overlays once the durable transaction
/// mutation has succeeded. The saved entry is authoritative: it may retain the
/// original household scope with a server split, move scope, or intentionally
/// have no split at all.
ExpenseEntry reconcileSyncedHouseholdTransactionOverlays({
  required OptimisticHouseholdExpensesNotifier expensesNotifier,
  required OptimisticHouseholdSplitsNotifier splitsNotifier,
  required String optimisticId,
  required String? optimisticHouseholdId,
  required ExpenseEntry savedEntry,
}) {
  String? normalizedHouseholdId(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  final fromHouseholdId = normalizedHouseholdId(optimisticHouseholdId);
  final toHouseholdId = normalizedHouseholdId(savedEntry.householdId);

  // Keep a complete optimistic pair together through the hand-off from the
  // provisional transaction ID to the server ID. The previous implementation
  // replaced the row first and then unconditionally removed this group. That
  // made every split-aware consumer briefly (and correctly, given its input)
  // treat the confirmed row as payer-full.
  final canRetainSplitPair =
      fromHouseholdId != null && fromHouseholdId == toHouseholdId;
  final reboundSplit = canRetainSplitPair
      ? splitsNotifier.rebindSplitExpenseId(
          fromExpenseId: optimisticId,
          toExpenseId: savedEntry.id,
          canonicalSplitGroupId: savedEntry.splitGroupId,
        )
      : null;
  final visibleEntry = reboundSplit == null
      ? savedEntry
      : savedEntry.copyWith(splitGroupId: reboundSplit.id);

  if (fromHouseholdId == toHouseholdId && toHouseholdId != null) {
    expensesNotifier.replaceExpense(
      toHouseholdId,
      optimisticId,
      visibleEntry,
    );
  } else {
    if (fromHouseholdId != null) {
      expensesNotifier.removeExpense(fromHouseholdId, optimisticId);
    }
    if (toHouseholdId != null) {
      expensesNotifier.addExpense(toHouseholdId, visibleEntry);
    }
  }

  // An intentional unsplit save has no local split to rebind, so this retains
  // the old removal behavior for that valid case. A split save instead keeps
  // its coherent local pair until canonical split data supersedes it.
  if (reboundSplit == null) {
    splitsNotifier.removeSplitByExpenseIdAcrossHouseholds(optimisticId);
  }
  return visibleEntry;
}
