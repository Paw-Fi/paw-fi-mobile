import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/income/domain/models/income_summary.dart';

void main() {
  group('Period - Model Creation', () {
    test('creates period with dates', () {
      final period = Period(
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 31),
      );

      expect(period.startDate, DateTime(2024, 1, 1));
      expect(period.endDate, DateTime(2024, 1, 31));
    });

    test('fromJson parses period correctly', () {
      final json = {
        'startDate': '2024-01-01',
        'endDate': '2024-01-31',
      };

      final period = Period.fromJson(json);

      expect(period.startDate, DateTime(2024, 1, 1));
      expect(period.endDate, DateTime(2024, 1, 31));
    });

    test('toJson serializes period correctly', () {
      final period = Period(
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 31),
      );

      final json = period.toJson();

      expect(json['startDate'], '2024-01-01');
      expect(json['endDate'], '2024-01-31');
    });

    test('handles dates with time component', () {
      final period = Period(
        startDate: DateTime(2024, 1, 1, 10, 30, 45),
        endDate: DateTime(2024, 1, 31, 23, 59, 59),
      );

      final json = period.toJson();

      expect(json['startDate'], '2024-01-01');
      expect(json['endDate'], '2024-01-31');
    });
  });

  group('CurrencyBreakdown - Model Creation', () {
    test('creates currency breakdown with all fields', () {
      final breakdown = CurrencyBreakdown(
        count: 10,
        total: 5000.0,
      );

      expect(breakdown.count, 10);
      expect(breakdown.total, 5000.0);
    });

    test('fromJson parses currency breakdown correctly', () {
      final json = {
        'count': 10,
        'total': 5000.0,
      };

      final breakdown = CurrencyBreakdown.fromJson(json);

      expect(breakdown.count, 10);
      expect(breakdown.total, 5000.0);
    });

    test('fromJson handles integer total', () {
      final json = {
        'count': 10,
        'total': 5000,
      };

      final breakdown = CurrencyBreakdown.fromJson(json);

      expect(breakdown.total, 5000.0);
    });

    test('toJson serializes currency breakdown correctly', () {
      final breakdown = CurrencyBreakdown(
        count: 10,
        total: 5000.0,
      );

      final json = breakdown.toJson();

      expect(json['count'], 10);
      expect(json['total'], 5000.0);
    });
  });

  group('IncomeSummary - Model Creation', () {
    test('creates income summary with all fields', () {
      final summary = IncomeSummary(
        totalIncome: 10000.0,
        mtdIncome: 3000.0,
        ytdIncome: 50000.0,
        currency: 'USD',
        categoryBreakdown: {'Salary': 8000.0, 'Bonus': 2000.0},
        currencyBreakdown: {
          'USD': CurrencyBreakdown(count: 5, total: 8000.0),
          'EUR': CurrencyBreakdown(count: 2, total: 2000.0),
        },
        memberBreakdown: {'user1': 6000.0, 'user2': 4000.0},
        transactionCount: 7,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      expect(summary.totalIncome, 10000.0);
      expect(summary.mtdIncome, 3000.0);
      expect(summary.ytdIncome, 50000.0);
      expect(summary.currency, 'USD');
      expect(summary.categoryBreakdown['Salary'], 8000.0);
      expect(summary.transactionCount, 7);
    });

    test('creates income summary with minimal fields', () {
      final summary = IncomeSummary(
        totalIncome: 10000.0,
        currency: 'USD',
        categoryBreakdown: {},
        transactionCount: 0,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      expect(summary.totalIncome, 10000.0);
      expect(summary.mtdIncome, null);
      expect(summary.ytdIncome, null);
      expect(summary.currencyBreakdown, null);
      expect(summary.memberBreakdown, null);
    });
  });

  group('IncomeSummary - JSON Serialization', () {
    test('fromJson parses complete income summary', () {
      final json = {
        'totalIncome': 10000.0,
        'mtdIncome': 3000.0,
        'ytdIncome': 50000.0,
        'currency': 'USD',
        'categoryBreakdown': {'Salary': 8000.0, 'Bonus': 2000.0},
        'currencyBreakdown': {
          'USD': {'count': 5, 'total': 8000.0},
          'EUR': {'count': 2, 'total': 2000.0},
        },
        'memberBreakdown': {'user1': 6000.0, 'user2': 4000.0},
        'transactionCount': 7,
        'period': {
          'startDate': '2024-01-01',
          'endDate': '2024-01-31',
        },
      };

      final summary = IncomeSummary.fromJson(json);

      expect(summary.totalIncome, 10000.0);
      expect(summary.mtdIncome, 3000.0);
      expect(summary.ytdIncome, 50000.0);
      expect(summary.currency, 'USD');
      expect(summary.categoryBreakdown['Salary'], 8000.0);
      expect(summary.categoryBreakdown['Bonus'], 2000.0);
      expect(summary.currencyBreakdown!['USD']!.count, 5);
      expect(summary.currencyBreakdown!['EUR']!.total, 2000.0);
      expect(summary.memberBreakdown!['user1'], 6000.0);
      expect(summary.transactionCount, 7);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'totalIncome': 10000.0,
        'currency': 'USD',
        'categoryBreakdown': <String, dynamic>{},
        'transactionCount': 5,
        'period': {
          'startDate': '2024-01-01',
          'endDate': '2024-01-31',
        },
      };

      final summary = IncomeSummary.fromJson(json);

      expect(summary.mtdIncome, null);
      expect(summary.ytdIncome, null);
      expect(summary.currencyBreakdown, null);
      expect(summary.memberBreakdown, null);
    });

    test('fromJson defaults currency to USD', () {
      final json = {
        'totalIncome': 10000.0,
        'categoryBreakdown': <String, dynamic>{},
        'transactionCount': 5,
        'period': {
          'startDate': '2024-01-01',
          'endDate': '2024-01-31',
        },
      };

      final summary = IncomeSummary.fromJson(json);

      expect(summary.currency, 'USD');
    });

    test('fromJson defaults transactionCount to 0', () {
      final json = {
        'totalIncome': 10000.0,
        'currency': 'USD',
        'categoryBreakdown': <String, dynamic>{},
        'period': {
          'startDate': '2024-01-01',
          'endDate': '2024-01-31',
        },
      };

      final summary = IncomeSummary.fromJson(json);

      expect(summary.transactionCount, 0);
    });

    test('fromJson handles integer values in breakdowns', () {
      final json = {
        'totalIncome': 10000,
        'categoryBreakdown': {'Salary': 8000, 'Bonus': 2000},
        'memberBreakdown': {'user1': 6000, 'user2': 4000},
        'currency': 'USD',
        'transactionCount': 7,
        'period': {
          'startDate': '2024-01-01',
          'endDate': '2024-01-31',
        },
      };

      final summary = IncomeSummary.fromJson(json);

      expect(summary.totalIncome, 10000.0);
      expect(summary.categoryBreakdown['Salary'], 8000.0);
      expect(summary.memberBreakdown!['user1'], 6000.0);
    });

    test('toJson serializes complete income summary', () {
      final summary = IncomeSummary(
        totalIncome: 10000.0,
        mtdIncome: 3000.0,
        ytdIncome: 50000.0,
        currency: 'USD',
        categoryBreakdown: {'Salary': 8000.0, 'Bonus': 2000.0},
        currencyBreakdown: {
          'USD': CurrencyBreakdown(count: 5, total: 8000.0),
        },
        memberBreakdown: {'user1': 6000.0},
        transactionCount: 7,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      final json = summary.toJson();

      expect(json['totalIncome'], 10000.0);
      expect(json['mtdIncome'], 3000.0);
      expect(json['ytdIncome'], 50000.0);
      expect(json['currency'], 'USD');
      expect(json['categoryBreakdown']['Salary'], 8000.0);
      expect(json['transactionCount'], 7);
    });
  });

  group('IncomeSummary - Edge Cases', () {
    test('handles zero income', () {
      final summary = IncomeSummary(
        totalIncome: 0.0,
        currency: 'USD',
        categoryBreakdown: {},
        transactionCount: 0,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      expect(summary.totalIncome, 0.0);
    });

    test('handles very large income amounts', () {
      final summary = IncomeSummary(
        totalIncome: 999999999.99,
        mtdIncome: 100000000.00,
        ytdIncome: 999999999.99,
        currency: 'USD',
        categoryBreakdown: {'Salary': 999999999.99},
        transactionCount: 1000000,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 12, 31),
        ),
      );

      expect(summary.totalIncome, 999999999.99);
    });

    test('handles multiple categories', () {
      final summary = IncomeSummary(
        totalIncome: 10000.0,
        currency: 'USD',
        categoryBreakdown: {
          'Salary': 5000.0,
          'Bonus': 2000.0,
          'Freelance': 1500.0,
          'Investment': 1000.0,
          'Other': 500.0,
        },
        transactionCount: 5,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      expect(summary.categoryBreakdown.length, 5);
      expect(summary.categoryBreakdown['Freelance'], 1500.0);
    });

    test('handles multiple currencies', () {
      final summary = IncomeSummary(
        totalIncome: 10000.0,
        currency: 'USD',
        categoryBreakdown: {},
        currencyBreakdown: {
          'USD': CurrencyBreakdown(count: 10, total: 5000.0),
          'EUR': CurrencyBreakdown(count: 5, total: 3000.0),
          'GBP': CurrencyBreakdown(count: 3, total: 2000.0),
        },
        transactionCount: 18,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      expect(summary.currencyBreakdown!.length, 3);
      expect(summary.currencyBreakdown!['EUR']!.count, 5);
    });

    test('handles multiple household members', () {
      final summary = IncomeSummary(
        totalIncome: 10000.0,
        currency: 'USD',
        categoryBreakdown: {},
        memberBreakdown: {
          'user1': 4000.0,
          'user2': 3500.0,
          'user3': 2500.0,
        },
        transactionCount: 10,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      expect(summary.memberBreakdown!.length, 3);
      expect(summary.memberBreakdown!['user3'], 2500.0);
    });

    test('handles empty category breakdown', () {
      final summary = IncomeSummary(
        totalIncome: 10000.0,
        currency: 'USD',
        categoryBreakdown: {},
        transactionCount: 0,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      expect(summary.categoryBreakdown.isEmpty, true);
    });

    test('handles period spanning multiple months', () {
      final summary = IncomeSummary(
        totalIncome: 30000.0,
        currency: 'USD',
        categoryBreakdown: {},
        transactionCount: 10,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 3, 31),
        ),
      );

      expect(summary.period.startDate, DateTime(2024, 1, 1));
      expect(summary.period.endDate, DateTime(2024, 3, 31));
    });

    test('handles period spanning full year', () {
      final summary = IncomeSummary(
        totalIncome: 120000.0,
        ytdIncome: 120000.0,
        currency: 'USD',
        categoryBreakdown: {},
        transactionCount: 12,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 12, 31),
        ),
      );

      expect(summary.ytdIncome, 120000.0);
    });

    test('handles various currency codes', () {
      final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CNY', 'INR'];

      for (final code in currencies) {
        final summary = IncomeSummary(
          totalIncome: 10000.0,
          currency: code,
          categoryBreakdown: {},
          transactionCount: 5,
          period: Period(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 1, 31),
          ),
        );

        expect(summary.currency, code);
      }
    });

    test('handles negative income values', () {
      final summary = IncomeSummary(
        totalIncome: -500.0,
        currency: 'USD',
        categoryBreakdown: {'Refund': -500.0},
        transactionCount: 1,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      expect(summary.totalIncome, -500.0);
    });

    test('handles floating point precision', () {
      final summary = IncomeSummary(
        totalIncome: 0.1 + 0.2,
        currency: 'USD',
        categoryBreakdown: {},
        transactionCount: 1,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      expect(summary.totalIncome, closeTo(0.3, 0.0001));
    });

    test('handles special characters in category names', () {
      final summary = IncomeSummary(
        totalIncome: 10000.0,
        currency: 'USD',
        categoryBreakdown: {
          'Salary & Wages': 5000.0,
          'Bonus (Annual)': 2000.0,
          'Freelance/Contract': 3000.0,
        },
        transactionCount: 3,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      expect(summary.categoryBreakdown['Salary & Wages'], 5000.0);
      expect(summary.categoryBreakdown['Bonus (Annual)'], 2000.0);
    });

    test('handles zero transaction count with non-zero income', () {
      final summary = IncomeSummary(
        totalIncome: 10000.0,
        currency: 'USD',
        categoryBreakdown: {},
        transactionCount: 0,
        period: Period(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        ),
      );

      expect(summary.transactionCount, 0);
      expect(summary.totalIncome, 10000.0);
    });
  });
}
