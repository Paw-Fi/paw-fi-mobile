import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/category_summary.dart';

void main() {
  group('CategorySummary - Model Creation', () {
    test('creates category summary with all fields', () {
      final summary = CategorySummary(
        category: 'Food',
        amount: 500.0,
        transactionCount: 10,
        color: Colors.blue,
      );

      expect(summary.category, 'Food');
      expect(summary.amount, 500.0);
      expect(summary.transactionCount, 10);
      expect(summary.color, Colors.blue);
    });

    test('creates category summary with zero amount', () {
      final summary = CategorySummary(
        category: 'Entertainment',
        amount: 0.0,
        transactionCount: 0,
        color: Colors.red,
      );

      expect(summary.amount, 0.0);
      expect(summary.transactionCount, 0);
    });

    test('creates category summary with large amount', () {
      final summary = CategorySummary(
        category: 'Housing',
        amount: 10000.0,
        transactionCount: 1,
        color: Colors.green,
      );

      expect(summary.amount, 10000.0);
      expect(summary.transactionCount, 1);
    });
  });

  group('CategorySummary - Percentage Calculation', () {
    test('getPercentage calculates correctly for normal case', () {
      final summary = CategorySummary(
        category: 'Food',
        amount: 500.0,
        transactionCount: 10,
        color: Colors.blue,
      );

      final percentage = summary.getPercentage(1000.0);

      expect(percentage, 50.0);
    });

    test('getPercentage calculates correctly for 100%', () {
      final summary = CategorySummary(
        category: 'Food',
        amount: 1000.0,
        transactionCount: 10,
        color: Colors.blue,
      );

      final percentage = summary.getPercentage(1000.0);

      expect(percentage, 100.0);
    });

    test('getPercentage calculates correctly for small percentage', () {
      final summary = CategorySummary(
        category: 'Food',
        amount: 1.0,
        transactionCount: 1,
        color: Colors.blue,
      );

      final percentage = summary.getPercentage(1000.0);

      expect(percentage, 0.1);
    });

    test('getPercentage returns 0 when total is 0', () {
      final summary = CategorySummary(
        category: 'Food',
        amount: 500.0,
        transactionCount: 10,
        color: Colors.blue,
      );

      final percentage = summary.getPercentage(0.0);

      expect(percentage, 0.0);
    });

    test('getPercentage returns 0 when total is negative', () {
      final summary = CategorySummary(
        category: 'Food',
        amount: 500.0,
        transactionCount: 10,
        color: Colors.blue,
      );

      final percentage = summary.getPercentage(-1000.0);

      expect(percentage, 0.0);
    });

    test('getPercentage handles fractional percentages', () {
      final summary = CategorySummary(
        category: 'Food',
        amount: 333.33,
        transactionCount: 5,
        color: Colors.blue,
      );

      final percentage = summary.getPercentage(1000.0);

      expect(percentage, closeTo(33.333, 0.001));
    });

    test('getPercentage handles very small total', () {
      final summary = CategorySummary(
        category: 'Food',
        amount: 0.01,
        transactionCount: 1,
        color: Colors.blue,
      );

      final percentage = summary.getPercentage(0.1);

      expect(percentage, 10.0);
    });
  });

  group('CategorySummary - Edge Cases', () {
    test('handles zero amount with non-zero total', () {
      final summary = CategorySummary(
        category: 'Food',
        amount: 0.0,
        transactionCount: 0,
        color: Colors.blue,
      );

      final percentage = summary.getPercentage(1000.0);

      expect(percentage, 0.0);
    });

    test('handles negative amount', () {
      final summary = CategorySummary(
        category: 'Refund',
        amount: -100.0,
        transactionCount: 1,
        color: Colors.red,
      );

      expect(summary.amount, -100.0);
      
      final percentage = summary.getPercentage(1000.0);
      expect(percentage, -10.0);
    });

    test('handles very large amount', () {
      final summary = CategorySummary(
        category: 'Investment',
        amount: 999999.99,
        transactionCount: 1,
        color: Colors.green,
      );

      expect(summary.amount, 999999.99);
    });

    test('handles many transactions', () {
      final summary = CategorySummary(
        category: 'Food',
        amount: 5000.0,
        transactionCount: 1000,
        color: Colors.blue,
      );

      expect(summary.transactionCount, 1000);
    });

    test('handles different colors', () {
      final colors = [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.purple,
        Colors.orange,
        const Color(0xFF123456),
      ];

      for (final color in colors) {
        final summary = CategorySummary(
          category: 'Test',
          amount: 100.0,
          transactionCount: 1,
          color: color,
        );

        expect(summary.color, color);
      }
    });

    test('handles empty category name', () {
      final summary = CategorySummary(
        category: '',
        amount: 100.0,
        transactionCount: 1,
        color: Colors.blue,
      );

      expect(summary.category, '');
    });

    test('handles long category name', () {
      final longName = 'A' * 100;
      final summary = CategorySummary(
        category: longName,
        amount: 100.0,
        transactionCount: 1,
        color: Colors.blue,
      );

      expect(summary.category, longName);
    });

    test('handles special characters in category name', () {
      final summary = CategorySummary(
        category: 'Food & Drinks 🍕',
        amount: 100.0,
        transactionCount: 1,
        color: Colors.blue,
      );

      expect(summary.category, 'Food & Drinks 🍕');
    });

    test('percentage calculation with amount exceeding total', () {
      final summary = CategorySummary(
        category: 'Food',
        amount: 1500.0,
        transactionCount: 10,
        color: Colors.blue,
      );

      final percentage = summary.getPercentage(1000.0);

      expect(percentage, 150.0);
    });

    test('handles fractional transaction count edge case', () {
      // Even though transactionCount is int, test boundary
      final summary = CategorySummary(
        category: 'Food',
        amount: 100.0,
        transactionCount: 1,
        color: Colors.blue,
      );

      expect(summary.transactionCount, isA<int>());
      expect(summary.transactionCount, 1);
    });
  });

  group('CategorySummary - Multiple Categories', () {
    test('calculates percentages for multiple categories correctly', () {
      final summaries = [
        CategorySummary(
          category: 'Food',
          amount: 400.0,
          transactionCount: 10,
          color: Colors.blue,
        ),
        CategorySummary(
          category: 'Transport',
          amount: 300.0,
          transactionCount: 5,
          color: Colors.green,
        ),
        CategorySummary(
          category: 'Entertainment',
          amount: 200.0,
          transactionCount: 3,
          color: Colors.red,
        ),
        CategorySummary(
          category: 'Other',
          amount: 100.0,
          transactionCount: 2,
          color: Colors.orange,
        ),
      ];

      const total = 1000.0;
      final percentages = summaries.map((s) => s.getPercentage(total)).toList();

      expect(percentages[0], 40.0);
      expect(percentages[1], 30.0);
      expect(percentages[2], 20.0);
      expect(percentages[3], 10.0);
      
      // Sum should equal 100%
      final sum = percentages.reduce((a, b) => a + b);
      expect(sum, 100.0);
    });
  });
}
