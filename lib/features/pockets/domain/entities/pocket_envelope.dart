import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Domain model representing a single budget pocket/envelope.
class PocketEnvelope {
  PocketEnvelope({
    required this.id,
    required this.name,
    required this.budgetAmountCents,
    required this.spent,
    required this.currency,
    this.icon,
    this.color,
    this.logoUrl,
    this.budgetId,
    this.householdId,
    this.rolloverGroupId,
    this.rolloverEnabled = false,
    this.rolloverNegative = false,
    this.rolloverCapCents,
    this.openingRolloverCents = 0,
    this.rolloverFromPreviousCents = 0,
    this.hasRolloverFields = true,
    int? availableBudgetCents,
    int? remainingCents,
    required this.lastUpdated,
  })  : availableBudgetCents = availableBudgetCents ?? budgetAmountCents,
        remainingCents = remainingCents ??
            ((availableBudgetCents ?? budgetAmountCents) -
                (spent * 100).round());

  factory PocketEnvelope.fromJson(Map<String, dynamic> json) {
    final hasRolloverFields = json['has_rollover_fields'] == true ||
        json.containsKey('rollover_group_id') ||
        json.containsKey('rollover_enabled') ||
        json.containsKey('rollover_negative') ||
        json.containsKey('rollover_cap_cents') ||
        json.containsKey('opening_rollover_cents') ||
        json.containsKey('rollover_from_previous_cents');

    return PocketEnvelope(
      id: json['id'] as String,
      name: json['name'] as String,
      budgetAmountCents: (json['budget_amount_cents'] as num?)?.toInt() ?? 0,
      spent: ((json['spent_cents'] as num?) ?? 0.0).toDouble() / 100.0,
      currency: json['currency'] as String? ?? 'USD',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      logoUrl: _nullableTrimmedString(json['logo_url']),
      budgetId: json['budget_id'] as String?,
      householdId: json['household_id'] as String?,
      rolloverGroupId: json['rollover_group_id'] as String?,
      rolloverEnabled: json['rollover_enabled'] == true,
      rolloverNegative: json['rollover_negative'] == true,
      rolloverCapCents: (json['rollover_cap_cents'] as num?)?.toInt(),
      openingRolloverCents:
          (json['opening_rollover_cents'] as num?)?.toInt() ?? 0,
      rolloverFromPreviousCents:
          (json['rollover_from_previous_cents'] as num?)?.toInt() ?? 0,
      hasRolloverFields: hasRolloverFields,
      availableBudgetCents: (json['available_budget_cents'] as num?)?.toInt(),
      remainingCents: (json['remaining_cents'] as num?)?.toInt(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : DateTime.now(),
    );
  }

  final String id;
  final String name;
  final int budgetAmountCents;
  final double spent; // Spent amount in major units
  final String currency;
  final String? icon;
  final String? color;
  final String? logoUrl;
  final String? budgetId;
  final String? householdId;
  final String? rolloverGroupId;
  final bool rolloverEnabled;
  final bool rolloverNegative;
  final int? rolloverCapCents;
  final int openingRolloverCents;
  final int rolloverFromPreviousCents;
  final bool hasRolloverFields;
  final int availableBudgetCents;
  final int remainingCents;
  final DateTime lastUpdated;

  /// Calculate the actual limit based on total budget
  double getLimit(double totalBudget) {
    return availableBudgetCents / 100.0;
  }

  int getLimitFromTotalBudgetCents(int totalBudgetCents) {
    return availableBudgetCents;
  }

  double get baseBudget => budgetAmountCents / 100.0;

  double get rolloverFromPrevious => rolloverFromPreviousCents / 100.0;

  double get openingRollover => openingRolloverCents / 100.0;

  double get availableBudget => availableBudgetCents / 100.0;

  double get remaining => remainingCents / 100.0;

  bool get hasRolloverBreakdown =>
      rolloverEnabled &&
      (rolloverFromPreviousCents != 0 || openingRolloverCents != 0);

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
    if (isOverBudget(totalBudget)) return AppTheme.danger;
    if (isNearLimit(totalBudget)) return AppTheme.warning;
    return safeColor;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'budget_amount_cents': budgetAmountCents,
      'spent_cents': (spent * 100).toInt(),
      'currency': currency,
      'icon': icon,
      'color': color,
      'logo_url': logoUrl,
      'budget_id': budgetId,
      'household_id': householdId,
      'has_rollover_fields': hasRolloverFields,
      if (hasRolloverFields) ...{
        'rollover_group_id': rolloverGroupId,
        'rollover_enabled': rolloverEnabled,
        'rollover_negative': rolloverNegative,
        'rollover_cap_cents': rolloverCapCents,
        'opening_rollover_cents': openingRolloverCents,
        'rollover_from_previous_cents': rolloverFromPreviousCents,
      },
      'available_budget_cents': availableBudgetCents,
      'remaining_cents': remainingCents,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  PocketEnvelope copyWith({
    int? budgetAmountCents,
    double? spent,
    String? currency,
    String? icon,
    String? color,
    String? logoUrl,
    bool clearLogoUrl = false,
    String? budgetId,
    String? rolloverGroupId,
    bool? rolloverEnabled,
    bool? rolloverNegative,
    int? rolloverCapCents,
    bool clearRolloverCap = false,
    int? openingRolloverCents,
    int? rolloverFromPreviousCents,
    bool? hasRolloverFields,
    int? availableBudgetCents,
    int? remainingCents,
  }) {
    final nextBudgetAmountCents = budgetAmountCents ?? this.budgetAmountCents;
    final nextRolloverEnabled = rolloverEnabled ?? this.rolloverEnabled;
    final currentRolloverAdjustmentCents = availableBudgetCents != null
        ? 0
        : this.availableBudgetCents - this.budgetAmountCents;
    final nextAvailableBudgetCents = availableBudgetCents ??
        (budgetAmountCents != null
            ? nextBudgetAmountCents +
                (nextRolloverEnabled ? currentRolloverAdjustmentCents : 0)
            : this.availableBudgetCents);
    final rolloverFieldsWereUpdated = rolloverGroupId != null ||
        rolloverEnabled != null ||
        rolloverNegative != null ||
        rolloverCapCents != null ||
        clearRolloverCap ||
        openingRolloverCents != null ||
        rolloverFromPreviousCents != null;
    final nextHasRolloverFields = hasRolloverFields ??
        (this.hasRolloverFields || rolloverFieldsWereUpdated);
    return PocketEnvelope(
      id: id,
      name: name,
      budgetAmountCents: nextBudgetAmountCents,
      spent: spent ?? this.spent,
      currency: currency ?? this.currency,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
      budgetId: budgetId ?? this.budgetId,
      householdId: householdId,
      rolloverGroupId: rolloverGroupId ?? this.rolloverGroupId,
      rolloverEnabled: nextRolloverEnabled,
      rolloverNegative: rolloverNegative ?? this.rolloverNegative,
      rolloverCapCents:
          clearRolloverCap ? null : (rolloverCapCents ?? this.rolloverCapCents),
      openingRolloverCents: openingRolloverCents ?? this.openingRolloverCents,
      rolloverFromPreviousCents:
          rolloverFromPreviousCents ?? this.rolloverFromPreviousCents,
      hasRolloverFields: nextHasRolloverFields,
      availableBudgetCents: nextAvailableBudgetCents,
      remainingCents: remainingCents ??
          (availableBudgetCents != null ||
                  budgetAmountCents != null ||
                  spent != null
              ? nextAvailableBudgetCents - ((spent ?? this.spent) * 100).round()
              : this.remainingCents),
      lastUpdated: lastUpdated,
    );
  }
}

String? _nullableTrimmedString(dynamic value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}
