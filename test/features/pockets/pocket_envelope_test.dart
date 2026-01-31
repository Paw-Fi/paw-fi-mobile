import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';

void main() {
  group('PocketEnvelope limits', () {
    test('percentage limit uses stable cent rounding', () {
      final p = PocketEnvelope(
        id: 'p1',
        name: 'Test',
        percentage: 33.33,
        spent: 0,
        currency: 'USD',
        lastUpdated: DateTime(2026, 1, 1),
      );

      // $100.00
      expect(p.getLimitFromTotalBudgetCents(10000), 3333);
    });

    test('allocation overrides percentage', () {
      final p = PocketEnvelope(
        id: 'p1',
        name: 'Test',
        percentage: 99.99,
        spent: 0,
        currency: 'USD',
        allocationCents: 50000,
        lastUpdated: DateTime(2026, 1, 1),
      );

      // allocation is authoritative
      expect(p.getLimitFromTotalBudgetCents(10000), 50000);
    });
  });
}
