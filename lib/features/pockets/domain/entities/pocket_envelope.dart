import 'package:flutter/material.dart';

/// Domain model representing a single budget pocket/envelope.
class PocketEnvelope {
  PocketEnvelope({
    required this.id,
    required this.name,
    required this.percentage,
    required this.spent,
    required this.currency,
    this.icon,
    this.color,
    this.budgetId,
    this.householdId,
    required this.lastUpdated,
  });

  factory PocketEnvelope.fromJson(Map<String, dynamic> json) {
    return PocketEnvelope(
      id: json['id'] as String,
      name: json['name'] as String,
      percentage: (json['budget_percentage'] as num?)?.toDouble() ?? 0.0,
      spent: ((json['spent_cents'] as num?) ?? 0.0).toDouble() / 100.0,
      currency: json['currency'] as String? ?? 'USD',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      budgetId: json['budget_id'] as String?,
      householdId: json['household_id'] as String?,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : DateTime.now(),
    );
  }

  final String id;
  final String name;
  final double percentage; // Budget allocation as percentage (0-100)
  final double spent; // Spent amount in major units
  final String currency;
  final String? icon;
  final String? color;
  final String? budgetId;
  final String? householdId;
  final DateTime lastUpdated;

  /// Calculate the actual limit based on total budget
  double getLimit(double totalBudget) {
    // Preserve cent-level accuracy for large budgets by rounding to cents
    final cents = (totalBudget * percentage / 100) * 100;
    return (cents.roundToDouble() / 100);
  }

  double getProgress(double totalBudget) {
    final limit = getLimit(totalBudget);
    return limit == 0 ? 1.0 : (spent / limit).clamp(0.0, 1.0);
  }

  bool isOverBudget(double totalBudget) => spent > getLimit(totalBudget);

  bool isNearLimit(double totalBudget) {
    final limit = getLimit(totalBudget);
    return !isOverBudget(totalBudget) && spent >= limit * 0.85;
  }

  Color statusColor(Color safeColor, double totalBudget) {
    if (isOverBudget(totalBudget)) return Colors.redAccent;
    if (isNearLimit(totalBudget)) return Colors.orangeAccent;
    return safeColor;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'budget_percentage': percentage,
      'spent_cents': (spent * 100).toInt(),
      'currency': currency,
      'icon': icon,
      'color': color,
      'budget_id': budgetId,
      'household_id': householdId,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  PocketEnvelope copyWith({
    double? percentage,
    double? spent,
    String? currency,
    String? icon,
    String? color,
    String? budgetId,
  }) {
    return PocketEnvelope(
      id: id,
      name: name,
      percentage: percentage ?? this.percentage,
      spent: spent ?? this.spent,
      currency: currency ?? this.currency,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      budgetId: budgetId ?? this.budgetId,
      householdId: householdId,
      lastUpdated: lastUpdated,
    );
  }
}
