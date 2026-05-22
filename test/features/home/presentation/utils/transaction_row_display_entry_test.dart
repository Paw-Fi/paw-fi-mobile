import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/transaction_row_display_entry.dart';

ExpenseEntry _entry({
  required String id,
  required int amountCents,
  required String currency,
}) {
  final date = DateTime(2026, 5, 22);
  return ExpenseEntry(
    id: id,
    date: date,
    amountCents: amountCents,
    currency: currency,
    createdAt: date,
  );
}

void main() {
  group('resolveTransactionRowDisplayEntry', () {
    test('uses the original source-currency entry for transaction rows', () {
      final convertedEntry = _entry(
        id: 'tx-1',
        amountCents: 500,
        currency: 'USD',
      );
      final originalEntry = _entry(
        id: 'tx-1',
        amountCents: 2000,
        currency: 'EUR',
      );

      final result = resolveTransactionRowDisplayEntry(
        convertedEntry,
        {'tx-1': originalEntry},
      );

      expect(result, same(originalEntry));
      expect(result.amountCents, 2000);
      expect(result.currency, 'EUR');
    });

    test('falls back to the grouped entry when no original exists', () {
      final convertedEntry = _entry(
        id: 'tx-2',
        amountCents: 500,
        currency: 'USD',
      );

      final result = resolveTransactionRowDisplayEntry(
        convertedEntry,
        const {},
      );

      expect(result, same(convertedEntry));
    });
  });
}
