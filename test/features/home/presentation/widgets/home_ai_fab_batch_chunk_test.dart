import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';

void main() {
  test('ambiguous and retryable batch failures retain durable transactions',
      () {
    for (final result in [
      {'success': false, 'error': 'write failed'},
      {'success': false, 'status': 503, 'error': 'write failed'},
      {'success': false, 'code': 'SERVER_ERROR'},
      {'success': false, 'status': 429},
      {'success': false, 'status': 401},
    ]) {
      expect(shouldKeepQueuedAiBatchFailureForRetry(result), true,
          reason: result.toString());
    }
    expect(
        shouldKeepQueuedAiBatchFailureForRetry(
            {'success': false, 'status': 400, 'code': 'VALIDATION_ERROR'}),
        false);
    expect(
        shouldKeepQueuedAiBatchFailureForRetry(
            {'success': false, 'code': 'VALIDATION_ERROR'}),
        false);
  });
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

  test('verified clocks use the configured IANA zone rather than the device',
      () {
    for (final values in [
      ('2026-07-02', 'America/New_York', DateTime.utc(2026, 7, 2, 22, 45, 27)),
      ('2026-12-02', 'America/New_York', DateTime.utc(2026, 12, 2, 23, 45, 27)),
      ('2026-07-02', 'Asia/Kathmandu', DateTime.utc(2026, 7, 2, 13, 0, 27)),
    ]) {
      final transaction = ParsedExpense(
          amount: 30,
          category: 'food',
          currency: 'USD',
          currencySymbol: r'$',
          date: DateTime.parse(values.$1),
          transactionTime: '18:45:27');
      expect(
          resolveAiTransactionCreatedAt(
              transaction: transaction,
              isRecurring: false,
              preferredTimezone: values.$2,
              isInteractive: true),
          values.$3);
    }
  });

  test(
      'verified custom and other categories cannot be replaced by descriptions',
      () {
    for (final category in ['家族の食費', 'consulting', 'other']) {
      expect(
          resolveAiParsedCategory(
              rawCategory: category,
              rawDescription: 'groceries',
              isIncome: category == 'consulting',
              isInteractive: true),
          category);
    }
    expect(
        () => resolveAiParsedCategory(
            rawCategory: null,
            rawDescription: 'groceries',
            isIncome: false,
            isInteractive: true),
        throwsFormatException);
  });
}
