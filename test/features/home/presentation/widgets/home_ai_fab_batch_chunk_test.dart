import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';

void main() {
  test('chunkList splits items into batches of max size', () {
    final items = List<int>.generate(501, (index) => index);
    final chunks = chunkList(items, 500);

    expect(chunks.length, 2);
    expect(chunks[0].length, 500);
    expect(chunks[1].length, 1);
  });

  test('chunkList returns empty list when input is empty', () {
    final chunks = chunkList(<int>[], 500);

    expect(chunks, isEmpty);
  });

  test('explicit AI time resolves to a transaction occurrence instant', () {
    final transaction = ParsedExpense(
      amount: 30,
      category: 'food',
      currency: 'USD',
      currencySymbol: r'$',
      date: DateTime(2026, 9, 2),
      transactionTime: '18:45:27',
    );

    final createdAt = resolveAiTransactionCreatedAt(
      transaction: transaction,
      isRecurring: false,
      preferredTimezone: 'UTC+08:00',
      fallbackNow: DateTime.utc(2026, 9, 22, 8),
    );

    expect(createdAt, DateTime.utc(2026, 9, 2, 10, 45, 27));
  });

  test('date-only and recurring AI items retain insertion-time fallback', () {
    final fallbackNow = DateTime.utc(2026, 9, 22, 8);
    final dateOnly = ParsedExpense(
      amount: 30,
      category: 'food',
      currency: 'USD',
      currencySymbol: r'$',
      date: DateTime(2026, 9, 2),
    );
    final recurringWithTime = dateOnly.copyWith(
      transactionTime: '18:45:27',
    );

    expect(
      resolveAiTransactionCreatedAt(
        transaction: dateOnly,
        isRecurring: false,
        preferredTimezone: 'UTC',
        fallbackNow: fallbackNow,
      ),
      fallbackNow,
    );
    expect(
      resolveAiTransactionCreatedAt(
        transaction: recurringWithTime,
        isRecurring: true,
        preferredTimezone: 'UTC',
        fallbackNow: fallbackNow,
      ),
      fallbackNow,
    );
  });
}
