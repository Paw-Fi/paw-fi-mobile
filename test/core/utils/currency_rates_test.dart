import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/currency_rates.dart';

void main() {
  group('CurrencyRateTable', () {
    test('converts between currencies using live USD-based rates', () {
      const table = CurrencyRateTable(
        baseCurrency: 'USD',
        rates: {'USD': 1.0, 'EUR': 0.8, 'JPY': 160.0},
      );

      expect(table.convert(20, 'EUR', 'USD'), closeTo(25, 0.0001));
      expect(table.convert(25, 'USD', 'EUR'), closeTo(20, 0.0001));
      expect(table.convert(20, 'EUR', 'JPY'), closeTo(4000, 0.0001));
    });

    test('falls back to original amount for unsupported currencies', () {
      const table = CurrencyRateTable(
        baseCurrency: 'USD',
        rates: {'USD': 1.0, 'EUR': 0.8},
      );

      expect(table.convert(12, 'ABC', 'USD'), 12);
      expect(table.convert(12, 'USD', 'XYZ'), 12);
    });
  });
}
