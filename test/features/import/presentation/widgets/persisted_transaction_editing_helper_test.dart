import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/import/presentation/widgets/persisted_transaction_editing_helper.dart';

void main() {
  group('persisted transaction editing helper', () {
    test('buildImportParsedRowFromExpense preserves editable values', () {
      final expense = ExpenseEntry(
        id: 'expense-1',
        date: DateTime(2026, 4, 23),
        amountCents: 1234,
        currency: 'USD',
        category: 'coffee & tea',
        createdAt: DateTime(2026, 4, 23),
        rawText: 'SQ *COFFEE SHOP',
        merchant: 'Coffee Shop',
        type: 'expense',
      );

      final row = buildImportParsedRowFromExpense(
        expense: expense,
        index: 7,
      );

      expect(row.index, 7);
      expect(row.amountCents, 1234);
      expect(row.category, 'coffee & tea');
      expect(row.description, 'SQ *COFFEE SHOP');
      expect(row.merchant, 'Coffee Shop');
    });

    test(
        'updatePersistedExpensesInChunks processes successful updates in chunks',
        () async {
      final expenses = List.generate(
        5,
        (index) => ExpenseEntry(
          id: 'expense-$index',
          date: DateTime(2026, 4, 23),
          amountCents: 1000 + index,
          currency: 'USD',
          category: 'old',
          createdAt: DateTime(2026, 4, 23),
          type: 'expense',
        ),
      );

      final result = await updatePersistedExpensesInChunks(
        expenses: expenses,
        chunkSize: 2,
        buildRow: (expense, index) => buildImportParsedRowFromExpense(
          expense: expense,
          index: index,
        ),
        transformRow: (row) => row.copyWith(category: 'new'),
        updateExpense: (expense, row) async {
          if (expense.id == 'expense-3') {
            throw Exception('fail one');
          }

          return expense.copyWith(category: row.category);
        },
      );

      expect(result.updatedExpenses.length, 4);
      expect(
        result.updatedExpenses.every((expense) => expense.category == 'new'),
        isTrue,
      );
      expect(
        result.updatedExpenses.any((expense) => expense.id == 'expense-3'),
        isFalse,
      );
      expect(
          result.failures.map((failure) => failure.expenseId), ['expense-3']);
      expect(result.failures.first.error.toString(), contains('fail one'));
    });

    test('updatePersistedExpensesInChunks rejects non-positive chunk size',
        () async {
      final expense = ExpenseEntry(
        id: 'expense-1',
        date: DateTime(2026, 4, 23),
        amountCents: 1234,
        currency: 'USD',
        category: 'coffee & tea',
        createdAt: DateTime(2026, 4, 23),
        type: 'expense',
      );

      expect(
        () => updatePersistedExpensesInChunks(
          expenses: [expense],
          chunkSize: 0,
          buildRow: (currentExpense, index) => buildImportParsedRowFromExpense(
            expense: currentExpense,
            index: index,
          ),
          transformRow: (row) => row,
          updateExpense: (currentExpense, row) async => currentExpense,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
