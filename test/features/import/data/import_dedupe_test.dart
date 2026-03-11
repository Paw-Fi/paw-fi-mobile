import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/import/data/import_dedupe.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

void main() {
  test('marks duplicates against existing expenses', () {
    final existing = [
      ExpenseEntry(
        id: '1',
        date: DateTime(2026, 2, 1),
        amountCents: 1200,
        currency: 'USD',
        category: 'Food',
        createdAt: DateTime(2026, 2, 1),
        type: 'expense',
        rawText: 'Lunch',
      ),
    ];

    final rows = [
      ImportParsedRow(
        index: 0,
        date: DateTime(2026, 2, 1),
        amountCents: 1200,
        currency: 'USD',
        category: 'Food',
        description: 'Lunch',
        type: 'expense',
        errors: const [],
      ),
      ImportParsedRow(
        index: 1,
        date: DateTime(2026, 2, 2),
        amountCents: 1500,
        currency: 'USD',
        category: 'Food',
        description: 'Dinner',
        type: 'expense',
        errors: const [],
      ),
    ];

    final result = markDuplicates(rows, existing);
    expect(result[0].isDuplicate, isTrue);
    expect(result[1].isDuplicate, isFalse);
  });
}
