import 'package:flutter/material.dart';

/// Domain model representing a single budget pocket/envelope.
class PocketEnvelope {
  PocketEnvelope({
    required this.id,
    required this.name,
    required this.limit,
    required this.spent,
    required this.currency,
    this.icon,
    this.color,
    this.householdId,
    required this.lastUpdated,
  });

  factory PocketEnvelope.fromJson(Map<String, dynamic> json) {
    return PocketEnvelope(
      id: json['id'] as String,
      name: json['name'] as String,
      limit: (json['monthly_target_cents'] as num).toDouble() / 100.0,
      spent: (json['spent_cents'] as num).toDouble() / 100.0,
      currency: json['currency'] as String? ?? 'USD',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      householdId: json['household_id'] as String?,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  final String id;
  final String name;
  final double limit; // monthly target in major units
  final double spent; // spent amount in major units
  final String currency;
  final String? icon;
  final String? color;
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'monthly_target_cents': (limit * 100).toInt(),
      'spent_cents': (spent * 100).toInt(),
      'currency': currency,
      'icon': icon,
      'color': color,
      'household_id': householdId,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  PocketEnvelope copyWith({
    double? limit,
    double? spent,
    String? currency,
    String? icon,
    String? color,
  }) {
    return PocketEnvelope(
      id: id,
      name: name,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      currency: currency ?? this.currency,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      householdId: householdId,
      lastUpdated: lastUpdated,
    );
  }
}
