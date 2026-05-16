import 'package:flutter_test/flutter_test.dart';
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
}
