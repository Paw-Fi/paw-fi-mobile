import 'package:flutter/material.dart';

/// Domain model representing a single budget pocket/envelope.
class PocketEnvelope {
  PocketEnvelope({
    required this.id,
    required this.name,
    required this.limit,
    required this.spent,
    this.householdId,
    required this.lastUpdated,
  });

  final String id;
  final String name;
  final double limit; // monthly target in major units
  final double spent; // spent amount in major units
  final String? householdId;
  final DateTime lastUpdated;

  double get progress => limit == 0 ? 1.0 : (spent / limit).clamp(0.0, 1.0);

  bool get isOverBudget => spent > limit;

  bool get isNearLimit => !isOverBudget && spent >= limit * 0.85;

  Color statusColor(Color safeColor) {
    if (isOverBudget) return Colors.redAccent;
    if (isNearLimit) return Colors.orangeAccent;
    return safeColor;
  }

  PocketEnvelope copyWith({
    double? limit,
    double? spent,
  }) {
    return PocketEnvelope(
      id: id,
      name: name,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      householdId: householdId,
      lastUpdated: lastUpdated,
    );
  }
}
