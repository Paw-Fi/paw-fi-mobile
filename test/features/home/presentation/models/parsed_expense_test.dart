import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';

void main() {
  group('ParsedExpense - Model Creation', () {
    test('creates expense with all required fields', () {
      final date = DateTime(2024, 1, 1);
      final expense = ParsedExpense(
        amount: 50.0,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: date,
      );

      expect(expense.isIncome, false);
      expect(expense.amount, 50.0);
      expect(expense.category, 'Food');
      expect(expense.currency, 'USD');
      expect(expense.currencySymbol, '\$');
      expect(expense.date, date);
      expect(expense.description, null);
      expect(expense.localImagePath, null);
    });

    test('creates income with all optional fields', () {
      final date = DateTime(2024, 1, 1);
      final expense = ParsedExpense(
        isIncome: true,
        amount: 1000.0,
        category: 'Salary',
        currency: 'EUR',
        currencySymbol: '€',
        date: date,
        description: 'Monthly salary',
        localImagePath: '/path/to/image.jpg',
      );

      expect(expense.isIncome, true);
      expect(expense.amount, 1000.0);
      expect(expense.category, 'Salary');
      expect(expense.currency, 'EUR');
      expect(expense.currencySymbol, '€');
      expect(expense.date, date);
      expect(expense.description, 'Monthly salary');
      expect(expense.localImagePath, '/path/to/image.jpg');
    });
  });

  group('ParsedExpense - JSON Serialization', () {
    test('fromJson parses expense correctly with type field', () {
      final json = {
        'type': 'expense',
        'amount': 50.0,
        'category': 'Food',
        'currency': 'USD',
        'currencySymbol': '\$',
        'date': '2024-01-01',
        'description': 'Lunch',
        'localImagePath': '/path/to/image.jpg',
      };

      final expense = ParsedExpense.fromJson(json);

      expect(expense.isIncome, false);
      expect(expense.amount, 50.0);
      // normalizeCategory converts 'Food' to 'food & drinks'
      expect(expense.category, 'food & drinks');
      expect(expense.currency, 'USD');
      expect(expense.currencySymbol, '\$');
      expect(expense.date, DateTime(2024, 1, 1));
      expect(expense.description, 'Lunch');
      expect(expense.localImagePath, '/path/to/image.jpg');
    });

    test('fromJson parses income correctly with type field', () {
      final json = {
        'type': 'income',
        'amount': 1000.0,
        'category': 'Salary',
        'currency': 'USD',
        'currencySymbol': '\$',
        'date': '2024-01-01',
      };

      final expense = ParsedExpense.fromJson(json);

      expect(expense.isIncome, true);
    });

    test('fromJson parses income with uppercase TYPE', () {
      final json = {
        'type': 'INCOME',
        'amount': 1000.0,
        'category': 'Salary',
        'currency': 'USD',
        'date': '2024-01-01',
      };

      final expense = ParsedExpense.fromJson(json);

      expect(expense.isIncome, true);
    });

    test('fromJson parses income with isIncome field', () {
      final json = {
        'isIncome': true,
        'amount': 1000.0,
        'category': 'Salary',
        'currency': 'USD',
        'currencySymbol': '\$',
        'date': '2024-01-01',
      };

      final expense = ParsedExpense.fromJson(json);

      expect(expense.isIncome, true);
    });

    test('fromJson handles default currencySymbol', () {
      final json = {
        'amount': 50.0,
        'category': 'Food',
        'currency': 'USD',
        'date': '2024-01-01',
      };

      final expense = ParsedExpense.fromJson(json);

      expect(expense.currencySymbol, '\$');
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'amount': 50.0,
        'category': 'Food',
        'currency': 'USD',
        'currencySymbol': '\$',
        'date': '2024-01-01',
        'description': null,
        'localImagePath': null,
      };

      final expense = ParsedExpense.fromJson(json);

      expect(expense.description, null);
      expect(expense.localImagePath, null);
    });

    test('fromJson parses amount as int', () {
      final json = {
        'amount': 50,
        'category': 'Food',
        'currency': 'USD',
        'currencySymbol': '\$',
        'date': '2024-01-01',
      };

      final expense = ParsedExpense.fromJson(json);

      expect(expense.amount, 50.0);
    });

    test('toJson serializes expense correctly', () {
      final date = DateTime(2024, 1, 15);
      final expense = ParsedExpense(
        isIncome: false,
        amount: 50.0,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: date,
        description: 'Lunch',
        localImagePath: '/path/to/image.jpg',
      );

      final json = expense.toJson();

      expect(json['isIncome'], false);
      expect(json['amount'], 50.0);
      expect(json['category'], 'Food');
      expect(json['currency'], 'USD');
      expect(json['currencySymbol'], '\$');
      expect(json['date'], '2024-01-15');
      expect(json['description'], 'Lunch');
      expect(json['localImagePath'], '/path/to/image.jpg');
    });

    test('toJson formats date correctly without time', () {
      final date = DateTime(2024, 12, 31, 23, 59, 59);
      final expense = ParsedExpense(
        amount: 50.0,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: date,
      );

      final json = expense.toJson();

      expect(json['date'], '2024-12-31');
    });
  });

  group('ParsedExpense - CopyWith', () {
    test('copyWith creates new instance with updated fields', () {
      final date = DateTime(2024, 1, 1);
      final original = ParsedExpense(
        amount: 50.0,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: date,
      );

      final updated = original.copyWith(
        amount: 75.0,
        description: 'Dinner',
      );

      expect(updated.amount, 75.0);
      expect(updated.description, 'Dinner');
      expect(updated.category, 'Food');
      expect(updated.currency, 'USD');
      expect(updated.date, date);
    });

    test('copyWith without parameters returns identical values', () {
      final date = DateTime(2024, 1, 1);
      final original = ParsedExpense(
        isIncome: true,
        amount: 1000.0,
        category: 'Salary',
        currency: 'USD',
        currencySymbol: '\$',
        date: date,
        description: 'Monthly salary',
      );

      final copy = original.copyWith();

      expect(copy.isIncome, original.isIncome);
      expect(copy.amount, original.amount);
      expect(copy.category, original.category);
      expect(copy.description, original.description);
    });
  });

  group('ParsedExpense - Computed Properties', () {
    test('amountCents converts amount to cents correctly', () {
      final expense = ParsedExpense(
        amount: 50.0,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: DateTime(2024, 1, 1),
      );

      expect(expense.amountCents, 5000);
    });

    test('amountCents rounds fractional cents correctly', () {
      final expense = ParsedExpense(
        amount: 50.555,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: DateTime(2024, 1, 1),
      );

      expect(expense.amountCents, 5056);
    });

    test('amountCents handles zero amount', () {
      final expense = ParsedExpense(
        amount: 0.0,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: DateTime(2024, 1, 1),
      );

      expect(expense.amountCents, 0);
    });

    test('formattedAmount formats with currency symbol', () {
      final expense = ParsedExpense(
        amount: 50.0,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: DateTime(2024, 1, 1),
      );

      expect(expense.formattedAmount, '\$50.00');
    });

    test('formattedAmount formats with euro symbol', () {
      final expense = ParsedExpense(
        amount: 123.45,
        category: 'Food',
        currency: 'EUR',
        currencySymbol: '€',
        date: DateTime(2024, 1, 1),
      );

      expect(expense.formattedAmount, '€123.45');
    });

    test('formattedAmount always shows two decimal places', () {
      final expense = ParsedExpense(
        amount: 100.0,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: DateTime(2024, 1, 1),
      );

      expect(expense.formattedAmount, '\$100.00');
    });
  });

  group('ParsedExpense - Edge Cases', () {
    test('handles very large amount', () {
      final expense = ParsedExpense(
        amount: 999999.99,
        category: 'Investment',
        currency: 'USD',
        currencySymbol: '\$',
        date: DateTime(2024, 1, 1),
      );

      expect(expense.amount, 999999.99);
      expect(expense.amountCents, 99999999);
    });

    test('handles very small amount', () {
      final expense = ParsedExpense(
        amount: 0.01,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: DateTime(2024, 1, 1),
      );

      expect(expense.amount, 0.01);
      expect(expense.amountCents, 1);
    });

    test('handles negative amount', () {
      final expense = ParsedExpense(
        amount: -50.0,
        category: 'Refund',
        currency: 'USD',
        currencySymbol: '\$',
        date: DateTime(2024, 1, 1),
      );

      expect(expense.amount, -50.0);
      expect(expense.amountCents, -5000);
      expect(expense.formattedAmount, '\$-50.00');
    });

    test('handles different currency symbols', () {
      final symbols = ['\$', '€', '£', '¥', '₹', 'R\$', 'kr'];
      
      for (final symbol in symbols) {
        final expense = ParsedExpense(
          amount: 100.0,
          category: 'Food',
          currency: 'XXX',
          currencySymbol: symbol,
          date: DateTime(2024, 1, 1),
        );

        expect(expense.currencySymbol, symbol);
        expect(expense.formattedAmount, '$symbol${100.00.toStringAsFixed(2)}');
      }
    });

    test('handles empty description', () {
      final expense = ParsedExpense(
        amount: 50.0,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: DateTime(2024, 1, 1),
        description: '',
      );

      expect(expense.description, '');
    });

    test('handles long description', () {
      final longDesc = 'A' * 500;
      final expense = ParsedExpense(
        amount: 50.0,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: DateTime(2024, 1, 1),
        description: longDesc,
      );

      expect(expense.description, longDesc);
    });

    test('handles various date formats', () {
      final dates = [
        DateTime(2024, 1, 1),
        DateTime(2024, 12, 31),
        DateTime(2000, 1, 1),
        DateTime(2099, 12, 31),
      ];

      for (final date in dates) {
        final expense = ParsedExpense(
          amount: 50.0,
          category: 'Food',
          currency: 'USD',
          currencySymbol: '\$',
          date: date,
        );

        expect(expense.date, date);
      }
    });

    test('handles income vs expense flag', () {
      final expense = ParsedExpense(
        isIncome: false,
        amount: 50.0,
        category: 'Food',
        currency: 'USD',
        currencySymbol: '\$',
        date: DateTime(2024, 1, 1),
      );

      final income = expense.copyWith(isIncome: true);

      expect(expense.isIncome, false);
      expect(income.isIncome, true);
    });
  });
}
