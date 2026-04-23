import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersistedExpenseBatchUpdateResult {
  const PersistedExpenseBatchUpdateResult({
    required this.updatedExpenses,
    required this.failures,
  });

  final List<ExpenseEntry> updatedExpenses;
  final List<PersistedExpenseUpdateFailure> failures;
}

class PersistedExpenseUpdateFailure {
  const PersistedExpenseUpdateFailure({
    required this.expenseId,
    required this.error,
  });

  final String expenseId;
  final Object error;
}

ImportParsedRow buildImportParsedRowFromExpense({
  required ExpenseEntry expense,
  required int index,
}) {
  return ImportParsedRow(
    index: index,
    date: expense.date,
    amountCents: expense.amountCents,
    category: normalizeEditableCategory(expense.category),
    description: expense.rawText,
    merchant: expense.merchant,
    currency: expense.currency,
    type: expense.type ?? 'expense',
    errors: const [],
  );
}

Future<ExpenseEntry> updatePersistedExpenseFromImportRow({
  required ExpenseEntry expense,
  required ImportParsedRow row,
}) async {
  final response = await Supabase.instance.client.functions.invoke(
    'update-expense',
    body: {
      'expenseId': expense.id,
      'updates': {
        'amount_cents': row.amountCents,
        'category': normalizeEditableCategory(row.category),
        'raw_text': row.description,
        'merchant': row.merchant,
        'currency': row.currency ?? expense.currency,
        if (row.date != null)
          'date': DateFormat('yyyy-MM-dd').format(row.date!),
      },
    },
  );

  final payload = response.data as Map<String, dynamic>?;
  if (response.status >= 400 || payload?['success'] != true) {
    throw Exception(
      payload?['error']?.toString() ?? 'Failed to update transaction',
    );
  }

  final updatedExpenseJson = payload?['data'];
  if (updatedExpenseJson is! Map<String, dynamic>) {
    throw Exception('Updated transaction payload was missing');
  }

  return ExpenseEntry.fromJson(updatedExpenseJson);
}

Future<PersistedExpenseBatchUpdateResult> updatePersistedExpensesInChunks({
  required List<ExpenseEntry> expenses,
  required ImportParsedRow Function(ExpenseEntry expense, int index) buildRow,
  required ImportParsedRow Function(ImportParsedRow row) transformRow,
  required Future<ExpenseEntry> Function(
          ExpenseEntry expense, ImportParsedRow row)
      updateExpense,
  int chunkSize = 20,
}) async {
  if (chunkSize <= 0) {
    throw ArgumentError.value(chunkSize, 'chunkSize', 'Must be greater than 0');
  }

  final updatedExpenses = <ExpenseEntry>[];
  final failures = <PersistedExpenseUpdateFailure>[];

  for (var start = 0; start < expenses.length; start += chunkSize) {
    final end = (start + chunkSize > expenses.length)
        ? expenses.length
        : start + chunkSize;
    final chunk = expenses.sublist(start, end);
    final chunkResults = await Future.wait(
      chunk.asMap().entries.map((entry) async {
        final expense = entry.value;
        final row = transformRow(buildRow(expense, start + entry.key));
        try {
          return (await updateExpense(expense, row), null);
        } catch (error) {
          return (
            null,
            PersistedExpenseUpdateFailure(expenseId: expense.id, error: error),
          );
        }
      }),
    );

    for (final result in chunkResults) {
      final updatedExpense = result.$1;
      final failure = result.$2;
      if (updatedExpense != null) {
        updatedExpenses.add(updatedExpense);
      }
      if (failure != null) {
        failures.add(failure);
      }
    }
  }

  return PersistedExpenseBatchUpdateResult(
    updatedExpenses: updatedExpenses,
    failures: failures,
  );
}

String normalizeEditableCategory(String? category) {
  final trimmed = category?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return 'uncategorized';
  }
  return trimmed;
}
