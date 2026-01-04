import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/currency_summary.dart';

void main() {
  group('CurrencySummary - Model Creation', () {
    test('creates currency summary with all fields', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 1000.0,
        totalIncome: 1500.0,
        totalBudget: 1200.0,
        transactionCount: 25,
      );

      expect(summary.currencyCode, 'USD');
      expect(summary.totalExpenses, 1000.0);
      expect(summary.totalIncome, 1500.0);
      expect(summary.totalBudget, 1200.0);
      expect(summary.transactionCount, 25);
    });

    test('creates currency summary with zero values', () {
      const summary = CurrencySummary(
        currencyCode: 'EUR',
        totalExpenses: 0.0,
        totalIncome: 0.0,
        totalBudget: 0.0,
        transactionCount: 0,
      );

      expect(summary.totalExpenses, 0.0);
      expect(summary.totalIncome, 0.0);
      expect(summary.totalBudget, 0.0);
      expect(summary.transactionCount, 0);
    });

    test('creates currency summary with negative values', () {
      const summary = CurrencySummary(
        currencyCode: 'GBP',
        totalExpenses: 500.0,
        totalIncome: 300.0,
        totalBudget: 400.0,
        transactionCount: 10,
      );

      expect(summary.totalExpenses, 500.0);
      expect(summary.totalIncome, 300.0);
    });
  });

  group('CurrencySummary - Computed Properties', () {
    test('netCashflow calculates correctly for positive cashflow', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 1000.0,
        totalIncome: 1500.0,
        totalBudget: 1200.0,
        transactionCount: 25,
      );

      expect(summary.netCashflow, 500.0);
    });

    test('netCashflow calculates correctly for negative cashflow', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 1500.0,
        totalIncome: 1000.0,
        totalBudget: 1200.0,
        transactionCount: 25,
      );

      expect(summary.netCashflow, -500.0);
    });

    test('netCashflow is zero when income equals expenses', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 1000.0,
        totalIncome: 1000.0,
        totalBudget: 1200.0,
        transactionCount: 25,
      );

      expect(summary.netCashflow, 0.0);
    });

    test('isPositive returns true for positive cashflow', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 1000.0,
        totalIncome: 1500.0,
        totalBudget: 1200.0,
        transactionCount: 25,
      );

      expect(summary.isPositive, true);
    });

    test('isPositive returns false for negative cashflow', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 1500.0,
        totalIncome: 1000.0,
        totalBudget: 1200.0,
        transactionCount: 25,
      );

      expect(summary.isPositive, false);
    });

    test('isPositive returns true for zero cashflow', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 1000.0,
        totalIncome: 1000.0,
        totalBudget: 1200.0,
        transactionCount: 25,
      );

      expect(summary.isPositive, true);
    });
  });

  group('CurrencySummary - Edge Cases', () {
    test('handles very large amounts', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 999999999.99,
        totalIncome: 1000000000.00,
        totalBudget: 1000000000.00,
        transactionCount: 1000000,
      );

      expect(summary.netCashflow, closeTo(0.01, 0.001));
      expect(summary.isPositive, true);
    });

    test('handles very small fractional amounts', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 0.01,
        totalIncome: 0.02,
        totalBudget: 0.03,
        transactionCount: 1,
      );

      expect(summary.netCashflow, closeTo(0.01, 0.001));
      expect(summary.isPositive, true);
    });

    test('handles various currency codes', () {
      final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CNY', 'INR', 'BRL'];

      for (final code in currencies) {
        final summary = CurrencySummary(
          currencyCode: code,
          totalExpenses: 100.0,
          totalIncome: 150.0,
          totalBudget: 120.0,
          transactionCount: 5,
        );

        expect(summary.currencyCode, code);
        expect(summary.netCashflow, 50.0);
      }
    });

    test('handles empty currency code', () {
      const summary = CurrencySummary(
        currencyCode: '',
        totalExpenses: 100.0,
        totalIncome: 150.0,
        totalBudget: 120.0,
        transactionCount: 5,
      );

      expect(summary.currencyCode, '');
    });

    test('handles zero transactions with non-zero amounts', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 100.0,
        totalIncome: 150.0,
        totalBudget: 120.0,
        transactionCount: 0,
      );

      expect(summary.transactionCount, 0);
      expect(summary.netCashflow, 50.0);
    });

    test('handles negative transaction count', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 100.0,
        totalIncome: 150.0,
        totalBudget: 120.0,
        transactionCount: -5,
      );

      expect(summary.transactionCount, -5);
    });

    test('handles budget exceeding income', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 100.0,
        totalIncome: 150.0,
        totalBudget: 200.0,
        transactionCount: 10,
      );

      expect(summary.totalBudget, 200.0);
      expect(summary.netCashflow, 50.0);
    });

    test('handles expenses exceeding budget', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 1500.0,
        totalIncome: 1000.0,
        totalBudget: 1200.0,
        transactionCount: 20,
      );

      expect(summary.totalExpenses, 1500.0);
      expect(summary.totalBudget, 1200.0);
      expect(summary.netCashflow, -500.0);
      expect(summary.isPositive, false);
    });

    test('handles floating point precision', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 0.1 + 0.2,
        totalIncome: 0.3,
        totalBudget: 0.5,
        transactionCount: 3,
      );

      expect(summary.netCashflow, closeTo(0.0, 0.0001));
    });

    test('handles multiple currency symbols', () {
      final summaries = [
        const CurrencySummary(
          currencyCode: 'USD',
          totalExpenses: 100.0,
          totalIncome: 150.0,
          totalBudget: 120.0,
          transactionCount: 5,
        ),
        const CurrencySummary(
          currencyCode: 'EUR',
          totalExpenses: 200.0,
          totalIncome: 250.0,
          totalBudget: 220.0,
          transactionCount: 10,
        ),
        const CurrencySummary(
          currencyCode: 'GBP',
          totalExpenses: 300.0,
          totalIncome: 350.0,
          totalBudget: 320.0,
          transactionCount: 15,
        ),
      ];

      expect(summaries[0].netCashflow, 50.0);
      expect(summaries[1].netCashflow, 50.0);
      expect(summaries[2].netCashflow, 50.0);
    });

    test('handles large transaction counts', () {
      const summary = CurrencySummary(
        currencyCode: 'USD',
        totalExpenses: 10000.0,
        totalIncome: 15000.0,
        totalBudget: 12000.0,
        transactionCount: 999999,
      );

      expect(summary.transactionCount, 999999);
    });
  });
}
