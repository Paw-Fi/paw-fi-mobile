/// Budget period enum
enum BudgetPeriod {
  daily,
  weekly,
  monthly,
  yearly;

  String toJson() {
    switch (this) {
      case BudgetPeriod.daily:
        return 'daily';
      case BudgetPeriod.weekly:
        return 'weekly';
      case BudgetPeriod.monthly:
        return 'monthly';
      case BudgetPeriod.yearly:
        return 'yearly';
    }
  }

  static BudgetPeriod fromJson(String value) {
    switch (value) {
      case 'daily':
        return BudgetPeriod.daily;
      case 'weekly':
        return BudgetPeriod.weekly;
      case 'monthly':
        return BudgetPeriod.monthly;
      case 'yearly':
        return BudgetPeriod.yearly;
      default:
        throw ArgumentError('Unknown BudgetPeriod: $value');
    }
  }
}

/// Budget type enum
enum BudgetType {
  household,
  personal;

  String toJson() {
    switch (this) {
      case BudgetType.household:
        return 'household';
      case BudgetType.personal:
        return 'personal';
    }
  }

  static BudgetType fromJson(String value) {
    switch (value) {
      case 'household':
        return BudgetType.household;
      case 'personal':
        return BudgetType.personal;
      default:
        throw ArgumentError('Unknown BudgetType: $value');
    }
  }
}

/// Shared budget entity
class SharedBudget {
  final String id;
  final String householdId;
  final String name;
  final BudgetPeriod period;
  final String currency;
  final int amountCents;
  final double warnThreshold; // 0.0 - 1.0
  final double alertThreshold; // 0.0 - 1.0
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final bool isActive;
  final BudgetType budgetType;
  final String? userId;
  final bool countSplitPortionOnly;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SharedBudget({
    required this.id,
    required this.householdId,
    required this.name,
    required this.period,
    required this.currency,
    required this.amountCents,
    required this.warnThreshold,
    required this.alertThreshold,
    this.periodStart,
    this.periodEnd,
    required this.isActive,
    required this.budgetType,
    this.userId,
    required this.countSplitPortionOnly,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SharedBudget.fromJson(Map<String, dynamic> json) {
    return SharedBudget(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      period: BudgetPeriod.fromJson(json['period'] as String),
      currency: json['currency'] as String,
      amountCents: json['amount_cents'] as int,
      warnThreshold: (json['warn_threshold'] as num).toDouble(),
      alertThreshold: (json['alert_threshold'] as num).toDouble(),
      periodStart: json['period_start'] != null
          ? DateTime.parse(json['period_start'] as String)
          : null,
      periodEnd: json['period_end'] != null
          ? DateTime.parse(json['period_end'] as String)
          : null,
      isActive: json['is_active'] as bool,
      budgetType:
          BudgetType.fromJson(json['budget_type'] as String? ?? 'household'),
      userId: json['user_id'] as String?,
      countSplitPortionOnly: json['count_split_portion_only'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'period': period.toJson(),
      'currency': currency,
      'amount_cents': amountCents,
      'warn_threshold': warnThreshold,
      'alert_threshold': alertThreshold,
      'period_start': periodStart?.toIso8601String(),
      'period_end': periodEnd?.toIso8601String(),
      'is_active': isActive,
      'budget_type': budgetType.toJson(),
      'user_id': userId,
      'count_split_portion_only': countSplitPortionOnly,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SharedBudget copyWith({
    String? id,
    String? householdId,
    String? name,
    BudgetPeriod? period,
    String? currency,
    int? amountCents,
    double? warnThreshold,
    double? alertThreshold,
    DateTime? periodStart,
    DateTime? periodEnd,
    bool? isActive,
    BudgetType? budgetType,
    String? userId,
    bool? countSplitPortionOnly,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SharedBudget(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      period: period ?? this.period,
      currency: currency ?? this.currency,
      amountCents: amountCents ?? this.amountCents,
      warnThreshold: warnThreshold ?? this.warnThreshold,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      isActive: isActive ?? this.isActive,
      budgetType: budgetType ?? this.budgetType,
      userId: userId ?? this.userId,
      countSplitPortionOnly:
          countSplitPortionOnly ?? this.countSplitPortionOnly,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SharedBudget &&
        other.id == id &&
        other.householdId == householdId &&
        other.name == name &&
        other.period == period &&
        other.currency == currency &&
        other.amountCents == amountCents &&
        other.warnThreshold == warnThreshold &&
        other.alertThreshold == alertThreshold &&
        other.periodStart == periodStart &&
        other.periodEnd == periodEnd &&
        other.isActive == isActive &&
        other.budgetType == budgetType &&
        other.userId == userId &&
        other.countSplitPortionOnly == countSplitPortionOnly &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      householdId,
      name,
      period,
      currency,
      amountCents,
      warnThreshold,
      alertThreshold,
      periodStart,
      periodEnd,
      isActive,
      budgetType,
      userId,
      countSplitPortionOnly,
      createdAt,
      updatedAt,
    );
  }
}

/// Transaction share scope enum
enum ShareScope {
  private,
  household,
  custom;

  String toJson() {
    switch (this) {
      case ShareScope.private:
        return 'private';
      case ShareScope.household:
        return 'household';
      case ShareScope.custom:
        return 'custom';
    }
  }

  static ShareScope fromJson(String value) {
    switch (value) {
      case 'private':
        return ShareScope.private;
      case 'household':
        return ShareScope.household;
      case 'custom':
        return ShareScope.custom;
      default:
        throw ArgumentError('Unknown ShareScope: $value');
    }
  }
}

/// Sharing preferences entity
class SharingPreferences {
  final String id;
  final String userId;
  final String householdId;
  final ShareScope defaultTransactionShareScope;
  final ShareScope defaultAccountShareScope;
  final Map<String, String> perCategoryOverrides;
  final bool enableNudges;
  final String? nudgeQuietHoursStart; // Time as string "HH:mm"
  final String? nudgeQuietHoursEnd; // Time as string "HH:mm"
  final DateTime createdAt;
  final DateTime updatedAt;

  const SharingPreferences({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.defaultTransactionShareScope,
    required this.defaultAccountShareScope,
    required this.perCategoryOverrides,
    required this.enableNudges,
    this.nudgeQuietHoursStart,
    this.nudgeQuietHoursEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SharingPreferences.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['created_at'] as String?;
    final updatedAtStr = json['updated_at'] as String?;
    return SharingPreferences(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      householdId: json['household_id'] as String,
      defaultTransactionShareScope: ShareScope.fromJson(
          (json['default_transaction_share_scope'] as String?) ?? 'private'),
      defaultAccountShareScope: ShareScope.fromJson(
          (json['default_account_share_scope'] as String?) ?? 'private'),
      perCategoryOverrides: Map<String, String>.from(
          (json['per_category_overrides'] as Map?) ?? <String, String>{}),
      enableNudges: (json['enable_nudges'] as bool?) ?? true,
      nudgeQuietHoursStart: json['nudge_quiet_hours_start'] as String?,
      nudgeQuietHoursEnd: json['nudge_quiet_hours_end'] as String?,
      createdAt: createdAtStr != null
          ? DateTime.parse(createdAtStr)
          : DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: updatedAtStr != null
          ? DateTime.parse(updatedAtStr)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'household_id': householdId,
      'default_transaction_share_scope': defaultTransactionShareScope.toJson(),
      'default_account_share_scope': defaultAccountShareScope.toJson(),
      'per_category_overrides': perCategoryOverrides,
      'enable_nudges': enableNudges,
      'nudge_quiet_hours_start': nudgeQuietHoursStart,
      'nudge_quiet_hours_end': nudgeQuietHoursEnd,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
