import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/utils/settlement_breakdown_calculator.dart';

void main() {
  group('computeSettlementBreakdownRows', () {
    test('reduces you-owe rows by prior settlements using FIFO', () {
      final rows = computeSettlementBreakdownRows(
        currentUserId: 'me',
        memberUserId: 'alex',
        currencyCode: 'USD',
        transactions: [
          _expense(
            id: 'expense-1',
            date: DateTime(2026, 1, 10),
            amountCents: 1000,
            rawText: 'Groceries',
          ),
          _expense(
            id: 'expense-2',
            date: DateTime(2026, 2, 5),
            amountCents: 2000,
            rawText: 'Dinner',
          ),
        ],
        splits: [
          _splitGroup(
            id: 'group-1',
            expenseId: 'expense-1',
            payerUserId: 'alex',
            participantUserId: 'me',
            amountCents: 1000,
          ),
          _splitGroup(
            id: 'group-2',
            expenseId: 'expense-2',
            payerUserId: 'alex',
            participantUserId: 'me',
            amountCents: 2000,
          ),
        ],
        paidToCents: 1000,
        paidFromCents: 0,
      );

      expect(rows, hasLength(1));
      expect(rows.single.direction, SettlementBreakdownDirection.youOwe);
      expect(rows.single.splitAmountCents, 2000);
      expect(rows.single.transaction.rawText, 'Dinner');
    });

    test('reduces they-owe-you rows by prior settlements using FIFO', () {
      final rows = computeSettlementBreakdownRows(
        currentUserId: 'me',
        memberUserId: 'alex',
        currencyCode: 'USD',
        transactions: [
          _expense(
            id: 'expense-1',
            date: DateTime(2026, 1, 12),
            amountCents: 4000,
            rawText: 'Taxi',
          ),
          _expense(
            id: 'expense-2',
            date: DateTime(2026, 3, 1),
            amountCents: 2500,
            rawText: 'Hotel',
          ),
        ],
        splits: [
          _splitGroup(
            id: 'group-1',
            expenseId: 'expense-1',
            payerUserId: 'me',
            participantUserId: 'alex',
            amountCents: 4000,
          ),
          _splitGroup(
            id: 'group-2',
            expenseId: 'expense-2',
            payerUserId: 'me',
            participantUserId: 'alex',
            amountCents: 2500,
          ),
        ],
        paidToCents: 0,
        paidFromCents: 5000,
      );

      expect(rows, hasLength(1));
      expect(rows.single.direction, SettlementBreakdownDirection.theyOweYou);
      expect(rows.single.splitAmountCents, 1500);
      expect(rows.single.transaction.rawText, 'Hotel');
    });

    test('ignores settled, wrong-currency, and wrong-member rows', () {
      final rows = computeSettlementBreakdownRows(
        currentUserId: 'me',
        memberUserId: 'alex',
        currencyCode: 'USD',
        transactions: [
          _expense(
            id: 'expense-1',
            date: DateTime(2026, 1, 10),
            amountCents: 1000,
            rawText: 'Lunch',
          ),
          _expense(
            id: 'expense-2',
            date: DateTime(2026, 1, 11),
            amountCents: 2000,
            rawText: 'Salary',
            type: 'income',
          ),
          _expense(
            id: 'expense-3',
            date: DateTime(2026, 1, 12),
            amountCents: 3000,
            rawText: 'Train',
          ),
          _expense(
            id: 'expense-4',
            date: DateTime(2026, 1, 13),
            amountCents: 4000,
            rawText: 'Coffee',
          ),
        ],
        splits: [
          _splitGroup(
            id: 'group-1',
            expenseId: 'expense-1',
            payerUserId: 'alex',
            participantUserId: 'me',
            amountCents: 1000,
          ),
          _splitGroup(
            id: 'group-2',
            expenseId: 'expense-2',
            payerUserId: 'alex',
            participantUserId: 'me',
            amountCents: 2000,
          ),
          _splitGroup(
            id: 'group-3',
            expenseId: 'expense-3',
            payerUserId: 'alex',
            participantUserId: 'me',
            amountCents: 3000,
            currency: 'EUR',
          ),
          _splitGroup(
            id: 'group-4',
            expenseId: 'expense-4',
            payerUserId: 'alex',
            participantUserId: 'sam',
            amountCents: 4000,
          ),
          _splitGroup(
            id: 'group-5',
            expenseId: 'expense-4',
            payerUserId: 'alex',
            participantUserId: 'me',
            amountCents: 500,
            isSettled: true,
          ),
        ],
        paidToCents: 500,
        paidFromCents: 0,
      );

      expect(rows, hasLength(2));
      expect(rows[0].direction, SettlementBreakdownDirection.youOwe);
      expect(rows[0].splitAmountCents, 2000);
      expect(rows[0].transaction.rawText, 'Salary');
      expect(rows[1].direction, SettlementBreakdownDirection.youOwe);
      expect(rows[1].splitAmountCents, 500);
      expect(rows[1].transaction.rawText, 'Lunch');
    });

    test('row totals reconcile to the remaining net after settlements', () {
      final rows = computeSettlementBreakdownRows(
        currentUserId: 'me',
        memberUserId: 'alex',
        currencyCode: 'USD',
        transactions: [
          _expense(
            id: 'expense-1',
            date: DateTime(2026, 1, 10),
            amountCents: 3000,
            rawText: 'Flight',
          ),
          _expense(
            id: 'expense-2',
            date: DateTime(2026, 1, 12),
            amountCents: 1000,
            rawText: 'Taxi',
          ),
        ],
        splits: [
          _splitGroup(
            id: 'group-1',
            expenseId: 'expense-1',
            payerUserId: 'alex',
            participantUserId: 'me',
            amountCents: 3000,
          ),
          _splitGroup(
            id: 'group-2',
            expenseId: 'expense-2',
            payerUserId: 'me',
            participantUserId: 'alex',
            amountCents: 1000,
          ),
        ],
        paidToCents: 500,
        paidFromCents: 200,
      );

      final youOweTotal = rows
          .where((row) => row.direction == SettlementBreakdownDirection.youOwe)
          .fold<int>(0, (sum, row) => sum + row.splitAmountCents);
      final theyOweTotal = rows
          .where(
              (row) => row.direction == SettlementBreakdownDirection.theyOweYou)
          .fold<int>(0, (sum, row) => sum + row.splitAmountCents);

      expect(youOweTotal, 2500);
      expect(theyOweTotal, 800);
      expect(youOweTotal - theyOweTotal, 1700);
    });

    test('preserves reversed net when legacy settlements exceed raw debt', () {
      final breakdown = computeSettlementBreakdownData(
        currentUserId: 'me',
        memberUserId: 'alex',
        currencyCode: 'USD',
        transactions: [
          _expense(
            id: 'expense-1',
            date: DateTime(2026, 1, 10),
            amountCents: 1000,
            rawText: 'Museum',
          ),
        ],
        splits: [
          _splitGroup(
            id: 'group-1',
            expenseId: 'expense-1',
            payerUserId: 'alex',
            participantUserId: 'me',
            amountCents: 1000,
          ),
        ],
        paidToCents: 1500,
        paidFromCents: 0,
      );

      expect(breakdown.rows, isEmpty);
      expect(breakdown.netCents, -500);
    });

    test('keeps rows and raw totals when expense metadata is missing', () {
      final breakdown = computeSettlementBreakdownData(
        currentUserId: 'me',
        memberUserId: 'alex',
        currencyCode: 'USD',
        transactions: const [],
        splits: [
          _splitGroup(
            id: 'group-1',
            expenseId: 'missing-expense',
            payerUserId: 'alex',
            participantUserId: 'me',
            amountCents: 19250,
            description: 'Missing expense metadata',
          ),
        ],
        paidToCents: 0,
        paidFromCents: 0,
      );

      expect(breakdown.netCents, 19250);
      expect(breakdown.rows, hasLength(1));
      expect(breakdown.rows.single.splitAmountCents, 19250);
      expect(breakdown.rows.single.transaction.id, 'missing-expense');
      expect(breakdown.rows.single.transaction.rawText,
          'Missing expense metadata');
      expect(breakdown.missingTransactionCount, 1);
    });

    test('includes income-linked split rows because pairwise net includes them',
        () {
      final breakdown = computeSettlementBreakdownData(
        currentUserId: 'me',
        memberUserId: 'alex',
        currencyCode: 'USD',
        transactions: [
          _expense(
            id: 'income-1',
            date: DateTime(2026, 1, 10),
            amountCents: 16618,
            rawText: 'Salary split',
            type: 'income',
          ),
        ],
        splits: [
          _splitGroup(
            id: 'group-1',
            expenseId: 'income-1',
            payerUserId: 'alex',
            participantUserId: 'me',
            amountCents: 16618,
          ),
        ],
        paidToCents: 0,
        paidFromCents: 0,
      );

      expect(breakdown.netCents, 16618);
      expect(breakdown.rows, hasLength(1));
      expect(breakdown.rows.single.splitAmountCents, 16618);
      expect(breakdown.rows.single.transaction.rawText, 'Salary split');
    });
  });
}

ExpenseEntry _expense({
  required String id,
  required DateTime date,
  required int amountCents,
  required String rawText,
  String currency = 'USD',
  String type = 'expense',
}) {
  return ExpenseEntry(
    id: id,
    date: date,
    amountCents: amountCents,
    currency: currency,
    rawText: rawText,
    createdAt: date,
    type: type,
  );
}

ExpenseSplitGroup _splitGroup({
  required String id,
  required String expenseId,
  required String payerUserId,
  required String participantUserId,
  required int amountCents,
  String currency = 'USD',
  bool isSettled = false,
  String? description,
}) {
  final createdAt = DateTime(2026, 1, 1);
  return ExpenseSplitGroup(
    id: id,
    householdId: 'household-1',
    expenseId: expenseId,
    payerUserId: payerUserId,
    splitType: SplitType.equal,
    currency: currency,
    totalAmountCents: amountCents,
    description: description,
    createdAt: createdAt,
    updatedAt: createdAt,
    splitLines: [
      ExpenseSplitLine(
        id: '$id-line',
        splitGroupId: id,
        userId: participantUserId,
        amountCents: amountCents,
        isSettled: isSettled,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    ],
  );
}
