import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';

void main() {
  group('PocketEnvelope limits', () {
    test('limit uses budget amount cents', () {
      final p = PocketEnvelope(
        id: 'p1',
        name: 'Test',
        budgetAmountCents: 3333,
        spent: 0,
        currency: 'USD',
        lastUpdated: DateTime(2026, 1, 1),
      );

      expect(p.getLimitFromTotalBudgetCents(10000), 3333);
    });
  });
}
