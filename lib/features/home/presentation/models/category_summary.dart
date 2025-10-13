import 'package:flutter/material.dart';

/// Category summary for charts
class CategorySummary {
  final String category;
  final double amount;
  final int transactionCount;
  final Color color;

  CategorySummary({
    required this.category,
    required this.amount,
    required this.transactionCount,
    required this.color,
  });

  double getPercentage(double total) => total > 0 ? (amount / total) * 100 : 0;
}
