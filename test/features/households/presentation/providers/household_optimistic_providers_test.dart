import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';

ExpenseSplitGroup _group({
  required String id,
  required String expenseId,
  required int payerAmountCents,
  required int memberAmountCents,
}) {
  final now = DateTime(2026, 5, 15);
  return ExpenseSplitGroup(
    id: id,
    householdId: 'household-1',
    expenseId: expenseId,
    payerUserId: 'user-a',
    splitType: SplitType.equal,
    currency: 'EUR',
    totalAmountCents: payerAmountCents + memberAmountCents,
    createdAt: now,
    updatedAt: now,
    splitLines: [
      ExpenseSplitLine(
        id: '$id-line-a',
        splitGroupId: id,
        userId: 'user-a',
        amountCents: payerAmountCents,
        isSettled: false,
        createdAt: now,
        updatedAt: now,
      ),
      ExpenseSplitLine(
        id: '$id-line-b',
        splitGroupId: id,
        userId: 'user-b',
        amountCents: memberAmountCents,
        isSettled: false,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
}

void main() {
  group('stabilizeHouseholdExpenseSplitSnapshot', () {
    const householdId = 'household-1';
    final date = DateTime(2026, 8, 4);

    ExpenseEntry entry({
      required String id,
      required String splitGroupId,
      String? clientRecordId,
      int amountCents = 1000,
    }) =>
        ExpenseEntry(
          id: id,
          userId: 'user-a',
          householdId: householdId,
          date: date,
          amountCents: amountCents,
          currency: 'USD',
          category: 'Groceries',
          createdAt: date,
          splitGroupId: splitGroupId,
          clientRecordId: clientRecordId,
        );

    test(
        'retains a complete optimistic pair while its server replacement is incomplete',
        () {
      final optimistic = entry(
        id: 'optimistic-expense',
        splitGroupId: 'optimistic-split',
      );
      final retained = stabilizeHouseholdExpenseSplitSnapshot(
        expenses: [optimistic],
        splitCandidates: [
          _group(
            id: 'optimistic-split',
            expenseId: optimistic.id,
            payerAmountCents: 500,
            memberAmountCents: 500,
          ),
        ],
      );
      final server = entry(
        id: 'server-expense',
        splitGroupId: 'server-split',
        clientRecordId: optimistic.id,
      );

      final duringReconciliation = stabilizeHouseholdExpenseSplitSnapshot(
        expenses: [server],
        splitCandidates: const [],
        retained: retained,
      );

      expect(duringReconciliation.hasDeferredSplitReferences, isTrue);
      expect(duringReconciliation.expenses, [optimistic]);
      expect(duringReconciliation.splits.single.id, 'optimistic-split');
    });

    test('publishes the server replacement only with its matching split group',
        () {
      final optimistic = entry(
        id: 'optimistic-expense',
        splitGroupId: 'optimistic-split',
      );
      final retained = stabilizeHouseholdExpenseSplitSnapshot(
        expenses: [optimistic],
        splitCandidates: [
          _group(
            id: 'optimistic-split',
            expenseId: optimistic.id,
            payerAmountCents: 500,
            memberAmountCents: 500,
          ),
        ],
      );
      final server = entry(
        id: 'server-expense',
        splitGroupId: 'server-split',
        clientRecordId: optimistic.id,
      );

      final reconciled = stabilizeHouseholdExpenseSplitSnapshot(
        expenses: [server],
        splitCandidates: [
          _group(
            id: 'server-split',
            expenseId: server.id,
            payerAmountCents: 500,
            memberAmountCents: 500,
          ),
        ],
        retained: retained,
      );

      expect(reconciled.hasDeferredSplitReferences, isFalse);
      expect(reconciled.expenses, [server]);
      expect(reconciled.splits.single.id, 'server-split');
    });

    test('does not turn an unresolved split expense into payer-full data', () {
      final unresolved = entry(
        id: 'server-expense',
        splitGroupId: 'server-split',
      );

      final snapshot = stabilizeHouseholdExpenseSplitSnapshot(
        expenses: [unresolved],
        splitCandidates: const [],
      );

      expect(snapshot.hasDeferredSplitReferences, isTrue);
      expect(snapshot.expenses, isEmpty);
      expect(snapshot.splits, isEmpty);
    });

    test('repairs a legacy persisted optimistic split ID from its one group',
        () {
      final legacy = entry(
        id: 'server-expense',
        splitGroupId: 'optimistic_split_server-expense',
      );

      final snapshot = stabilizeHouseholdExpenseSplitSnapshot(
        expenses: [legacy],
        splitCandidates: [
          _group(
            id: 'server-split',
            expenseId: legacy.id,
            payerAmountCents: 500,
            memberAmountCents: 500,
          ),
        ],
      );

      expect(snapshot.hasDeferredSplitReferences, isFalse);
      expect(snapshot.expenses, [legacy]);
      expect(snapshot.splits.single.id, 'server-split');
    });

    test('holds the prior pair while an edit publishes only one side', () {
      final original = entry(
        id: 'server-expense',
        splitGroupId: 'server-split',
      );
      final retained = stabilizeHouseholdExpenseSplitSnapshot(
        expenses: [original],
        splitCandidates: [
          _group(
            id: 'server-split',
            expenseId: original.id,
            payerAmountCents: 500,
            memberAmountCents: 500,
          ),
        ],
      );

      final splitOnlyUpdate = stabilizeHouseholdExpenseSplitSnapshot(
        expenses: [original],
        splitCandidates: [
          _group(
            id: 'server-split',
            expenseId: original.id,
            payerAmountCents: 1000,
            memberAmountCents: 1000,
          ),
        ],
        retained: retained,
      );

      expect(splitOnlyUpdate.hasDeferredSplitReferences, isTrue);
      expect(splitOnlyUpdate.expenses.single.amountCents, 1000);
      expect(splitOnlyUpdate.splits.single.totalAmountCents, 1000);
    });
  });

  test('keeps one logical expense when server reconciliation changes its id',
      () {
    final date = DateTime(2026, 8, 4);
    final optimistic = ExpenseEntry(
      id: 'optimistic_1',
      userId: 'user-a',
      householdId: 'household-1',
      date: date,
      amountCents: 1000,
      currency: 'USD',
      createdAt: date,
      clientRecordId: 'optimistic_1',
    );
    final server = ExpenseEntry(
      id: 'server-1',
      userId: 'user-a',
      householdId: 'household-1',
      date: date,
      amountCents: 1000,
      currency: 'USD',
      createdAt: date,
      clientRecordId: 'optimistic_1',
    );

    final merged = mergeHouseholdExpenses([server], [optimistic]);

    expect(merged, [optimistic]);
  });

  test('authoritative split group replaces provisional split for same expense',
      () {
    final notifier = OptimisticHouseholdSplitsNotifier();
    notifier.addSplitGroup(
      'household-1',
      _group(
        id: 'optimistic_split_expense-1',
        expenseId: 'expense-1',
        payerAmountCents: 2000,
        memberAmountCents: 0,
      ),
    );

    notifier.addSplitGroup(
      'household-1',
      _group(
        id: 'server-split-1',
        expenseId: 'expense-1',
        payerAmountCents: 1000,
        memberAmountCents: 1000,
      ),
    );

    final groups = notifier.state['household-1']!;
    expect(groups, hasLength(1));
    expect(groups.single.id, 'server-split-1');
    expect(
      groups.single.splitLines!.map((line) => line.amountCents),
      [1000, 1000],
    );
  });

  group('optimistic household overlay pruning', () {
    final date = DateTime(2026, 8, 4);

    ExpenseEntry entry({
      required String id,
      String? splitGroupId,
    }) =>
        ExpenseEntry(
          id: id,
          userId: 'user-a',
          householdId: 'household-1',
          date: date,
          amountCents: 1000,
          currency: 'USD',
          createdAt: date,
          splitGroupId: splitGroupId,
        );

    test('keeps a split-aware row until the canonical split reference matches',
        () {
      final notifier = OptimisticHouseholdExpensesNotifier();
      notifier.addExpense(
        'household-1',
        entry(id: 'expense-1', splitGroupId: 'split-1'),
      );

      notifier.pruneIfInServer(
        'household-1',
        [entry(id: 'expense-1')],
      );

      expect(notifier.state['household-1'], hasLength(1));

      notifier.pruneIfInServer(
        'household-1',
        [entry(id: 'expense-1', splitGroupId: 'split-1')],
      );

      expect(notifier.state['household-1'], isNull);
    });

    test('keeps a split until an exact complete canonical group arrives', () {
      final notifier = OptimisticHouseholdSplitsNotifier();
      final optimistic = _group(
        id: 'split-1',
        expenseId: 'expense-1',
        payerAmountCents: 500,
        memberAmountCents: 500,
      );
      notifier.addSplitGroup('household-1', optimistic);

      notifier.pruneIfInServer(
        'household-1',
        [
          _group(
            id: 'older-split',
            expenseId: 'expense-1',
            payerAmountCents: 1000,
            memberAmountCents: 0,
          ),
        ],
      );

      expect(notifier.state['household-1'], [optimistic]);

      notifier.pruneIfInServer('household-1', [optimistic]);

      expect(notifier.state['household-1'], isNull);
    });
  });

  group('reconcileSyncedHouseholdTransactionOverlays', () {
    const householdId = 'household-1';
    final date = DateTime(2026, 8, 4);

    ExpenseEntry entry({
      required String id,
      String? householdId,
      String? splitGroupId,
    }) =>
        ExpenseEntry(
          id: id,
          userId: 'user-a',
          householdId: householdId,
          date: date,
          amountCents: 2000,
          currency: 'USD',
          category: 'Groceries',
          createdAt: date,
          splitGroupId: splitGroupId,
        );

    test('rebinds a queued household split to the server row atomically', () {
      final expenses = OptimisticHouseholdExpensesNotifier();
      final splits = OptimisticHouseholdSplitsNotifier();
      final optimistic = entry(
        id: 'optimistic-expense',
        householdId: householdId,
        splitGroupId: 'optimistic-split',
      );
      final saved = entry(
        id: 'server-expense',
        householdId: householdId,
        splitGroupId: 'server-split',
      );
      expenses.addExpense(householdId, optimistic);
      splits.addSplitGroup(
        householdId,
        _group(
          id: 'optimistic-split',
          expenseId: optimistic.id,
          payerAmountCents: 1000,
          memberAmountCents: 1000,
        ),
      );

      final visibleEntry = reconcileSyncedHouseholdTransactionOverlays(
        expensesNotifier: expenses,
        splitsNotifier: splits,
        optimisticId: optimistic.id,
        optimisticHouseholdId: householdId,
        savedEntry: saved,
      );

      expect(expenses.state[householdId], hasLength(1));
      expect(expenses.state[householdId]!.single.id, 'server-expense');
      expect(
        expenses.state[householdId]!.single.splitGroupId,
        'server-split',
      );
      expect(visibleEntry.splitGroupId, 'server-split');
      final visibleSplit = splits.state[householdId]!.single;
      expect(visibleSplit.id, 'server-split');
      expect(visibleSplit.expenseId, 'server-expense');
      expect(
        visibleSplit.splitLines!.every(
          (line) => line.splitGroupId == 'server-split',
        ),
        isTrue,
      );
    });

    test('keeps the provisional pair while a split response is incomplete', () {
      final expenses = OptimisticHouseholdExpensesNotifier();
      final splits = OptimisticHouseholdSplitsNotifier();
      final optimistic = entry(
        id: 'optimistic-expense',
        householdId: householdId,
        splitGroupId: 'optimistic-split',
      );
      expenses.addExpense(householdId, optimistic);
      splits.addSplitGroup(
        householdId,
        _group(
          id: 'optimistic-split',
          expenseId: optimistic.id,
          payerAmountCents: 1000,
          memberAmountCents: 1000,
        ),
      );

      final visibleEntry = reconcileSyncedHouseholdTransactionOverlays(
        expensesNotifier: expenses,
        splitsNotifier: splits,
        optimisticId: optimistic.id,
        optimisticHouseholdId: householdId,
        savedEntry: entry(id: 'server-expense', householdId: householdId),
      );

      expect(visibleEntry.splitGroupId, 'optimistic-split');
      expect(
          expenses.state[householdId]!.single.splitGroupId, 'optimistic-split');
      expect(splits.state[householdId]!.single.expenseId, 'server-expense');
    });

    test(
        'removes an optimistic household row when the server confirms a personal row',
        () {
      final expenses = OptimisticHouseholdExpensesNotifier();
      final splits = OptimisticHouseholdSplitsNotifier();
      final optimistic = entry(
        id: 'optimistic-expense',
        householdId: householdId,
        splitGroupId: 'optimistic-split',
      );
      expenses.addExpense(householdId, optimistic);
      splits.addSplitGroup(
        householdId,
        _group(
          id: 'optimistic-split',
          expenseId: optimistic.id,
          payerAmountCents: 1000,
          memberAmountCents: 1000,
        ),
      );

      reconcileSyncedHouseholdTransactionOverlays(
        expensesNotifier: expenses,
        splitsNotifier: splits,
        optimisticId: optimistic.id,
        optimisticHouseholdId: householdId,
        savedEntry: entry(id: 'server-expense'),
      );

      expect(expenses.state[householdId], isNull);
      expect(splits.state[householdId], isNull);
    });

    test('moves an optimistic row when the server confirms another household',
        () {
      final expenses = OptimisticHouseholdExpensesNotifier();
      final splits = OptimisticHouseholdSplitsNotifier();
      final optimistic = entry(
        id: 'optimistic-expense',
        householdId: householdId,
        splitGroupId: 'optimistic-split',
      );
      final saved = entry(
        id: 'server-expense',
        householdId: 'household-2',
        splitGroupId: 'server-split',
      );
      expenses.addExpense(householdId, optimistic);
      splits.addSplitGroup(
        householdId,
        _group(
          id: 'optimistic-split',
          expenseId: optimistic.id,
          payerAmountCents: 1000,
          memberAmountCents: 1000,
        ),
      );

      reconcileSyncedHouseholdTransactionOverlays(
        expensesNotifier: expenses,
        splitsNotifier: splits,
        optimisticId: optimistic.id,
        optimisticHouseholdId: householdId,
        savedEntry: saved,
      );

      expect(expenses.state[householdId], isNull);
      expect(expenses.state['household-2'], [saved]);
      expect(splits.state[householdId], isNull);
    });
  });
}
