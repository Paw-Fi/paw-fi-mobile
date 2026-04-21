import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/utils/member_spending_attribution.dart';

ExpenseEntry _expense({
  required String id,
  required String userId,
  required int amountCents,
  required String currency,
  required DateTime date,
  String? splitGroupId,
  String type = 'expense',
}) {
  return ExpenseEntry(
    id: id,
    userId: userId,
    date: date,
    amountCents: amountCents,
    currency: currency,
    splitGroupId: splitGroupId,
    type: type,
    createdAt: date,
  );
}

ExpenseSplitGroup _splitGroup({
  required String id,
  required String payerUserId,
  required List<ExpenseSplitLine> lines,
}) {
  return ExpenseSplitGroup(
    id: id,
    householdId: 'house-1',
    expenseId: 'expense-1',
    payerUserId: payerUserId,
    splitType: SplitType.amount,
    currency: 'INR',
    totalAmountCents: 10000,
    createdAt: DateTime(2026, 4, 10),
    updatedAt: DateTime(2026, 4, 10),
    splitLines: lines,
  );
}

ExpenseSplitLine _splitLine({
  required String id,
  required String userId,
  required int amountCents,
}) {
  return ExpenseSplitLine(
    id: id,
    splitGroupId: 'split-1',
    userId: userId,
    amountCents: amountCents,
    isSettled: false,
    createdAt: DateTime(2026, 4, 10),
    updatedAt: DateTime(2026, 4, 10),
  );
}

void main() {
  test('uses split lines for member attribution when split data exists', () {
    final totals = computeSplitAwareMemberSpendingTotals(
      transactions: [
        _expense(
          id: 'expense-1',
          userId: 'payer-user',
          amountCents: 10000,
          currency: 'INR',
          date: DateTime(2026, 4, 10),
          splitGroupId: 'split-1',
        ),
      ],
      from: DateTime(2026, 4, 1),
      to: DateTime(2026, 4, 30),
      splits: [
        _splitGroup(
          id: 'split-1',
          payerUserId: 'payer-user',
          lines: [
            _splitLine(id: 'line-1', userId: 'payer-user', amountCents: 4000),
            _splitLine(id: 'line-2', userId: 'member-user', amountCents: 6000),
          ],
        ),
      ],
      selectedCurrency: 'INR',
    );

    expect(totals.totalForUser('payer-user'), 4000);
    expect(totals.totalForUser('member-user'), 6000);
    expect(totals.transactionCountForUser('payer-user'), 1);
    expect(totals.transactionCountForUser('member-user'), 1);
  });

  test('falls back to full payer attribution when split data is missing', () {
    final totals = computeSplitAwareMemberSpendingTotals(
      transactions: [
        _expense(
          id: 'expense-1',
          userId: 'payer-user',
          amountCents: 10000,
          currency: 'INR',
          date: DateTime(2026, 4, 10),
          splitGroupId: 'missing-split',
        ),
        _expense(
          id: 'income-1',
          userId: 'payer-user',
          amountCents: 20000,
          currency: 'INR',
          date: DateTime(2026, 4, 11),
          type: 'income',
        ),
      ],
      from: DateTime(2026, 4, 1),
      to: DateTime(2026, 4, 30),
      splits: const [],
      selectedCurrency: 'INR',
    );

    expect(totals.totalForUser('payer-user'), 10000);
    expect(totals.transactionCountForUser('payer-user'), 1);
    expect(totals.totalForUser('member-user'), 0);
  });
}
