/// Member contribution entity
class MemberContribution {
  final String userId;
  final int totalSpentCents;
  final int transactionCount;
  final int splitCount;
  final int balanceCents; // Positive = owed to them, Negative = they owe
  final String? userEmail;
  final String? userName;

  const MemberContribution({
    required this.userId,
    required this.totalSpentCents,
    required this.transactionCount,
    required this.splitCount,
    required this.balanceCents,
    this.userEmail,
    this.userName,
  });

  factory MemberContribution.fromJson(Map<String, dynamic> json) {
    return MemberContribution(
      userId: json['user_id'] as String,
      totalSpentCents: json['total_spent_cents'] as int,
      transactionCount: json['transaction_count'] as int,
      splitCount: json['split_count'] as int,
      balanceCents: json['balance_cents'] as int,
      userEmail: json['user_email'] as String?,
      userName: json['user_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'total_spent_cents': totalSpentCents,
      'transaction_count': transactionCount,
      'split_count': splitCount,
      'balance_cents': balanceCents,
      'user_email': userEmail,
      'user_name': userName,
    };
  }
}

/// Category breakdown entity
class CategoryBreakdown {
  final String category;
  final int amountCents;
  final double percentage;
  final int transactionCount;

  const CategoryBreakdown({
    required this.category,
    required this.amountCents,
    required this.percentage,
    required this.transactionCount,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      category: json['category'] as String,
      amountCents: json['amount_cents'] as int,
      percentage: (json['percentage'] as num).toDouble(),
      transactionCount: json['transaction_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'amount_cents': amountCents,
      'percentage': percentage,
      'transaction_count': transactionCount,
    };
  }
}

/// Budget status entity
class BudgetStatus {
  final String budgetId;
  final String name;
  final String currency;
  final String period;
  final int amountCents;
  final int spentCents;
  final int remainingCents;
  final double percentageUsed;
  final bool isOverBudget;
  final bool isAtWarnThreshold;
  final bool isAtAlertThreshold;

  const BudgetStatus({
    required this.budgetId,
    required this.name,
    required this.currency,
    required this.period,
    required this.amountCents,
    required this.spentCents,
    required this.remainingCents,
    required this.percentageUsed,
    required this.isOverBudget,
    required this.isAtWarnThreshold,
    required this.isAtAlertThreshold,
  });

  factory BudgetStatus.fromJson(Map<String, dynamic> json) {
    return BudgetStatus(
      budgetId: json['budget_id'] as String,
      name: json['name'] as String,
      currency: json['currency'] as String,
      period: json['period'] as String,
      amountCents: json['amount_cents'] as int,
      spentCents: json['spent_cents'] as int,
      remainingCents: json['remaining_cents'] as int,
      percentageUsed: (json['percentage_used'] as num).toDouble(),
      isOverBudget: json['is_over_budget'] as bool,
      isAtWarnThreshold: json['is_at_warn_threshold'] as bool,
      isAtAlertThreshold: json['is_at_alert_threshold'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'budget_id': budgetId,
      'name': name,
      'currency': currency,
      'period': period,
      'amount_cents': amountCents,
      'spent_cents': spentCents,
      'remaining_cents': remainingCents,
      'percentage_used': percentageUsed,
      'is_over_budget': isOverBudget,
      'is_at_warn_threshold': isAtWarnThreshold,
      'is_at_alert_threshold': isAtAlertThreshold,
    };
  }
}

/// Date period for summary
class DatePeriod {
  final String startDate;
  final String endDate;

  const DatePeriod({
    required this.startDate,
    required this.endDate,
  });

  factory DatePeriod.fromJson(Map<String, dynamic> json) {
    return DatePeriod(
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start_date': startDate,
      'end_date': endDate,
    };
  }
}

/// Totals for household summary
class Totals {
  final int totalExpensesCents;
  final int totalIncomeCents;
  final int netCents;
  final int transactionCount;
  final int splitCount;

  const Totals({
    required this.totalExpensesCents,
    required this.totalIncomeCents,
    required this.netCents,
    required this.transactionCount,
    required this.splitCount,
  });

  factory Totals.fromJson(Map<String, dynamic> json) {
    return Totals(
      totalExpensesCents: json['total_expenses_cents'] as int,
      totalIncomeCents: json['total_income_cents'] as int,
      netCents: json['net_cents'] as int,
      transactionCount: json['transaction_count'] as int,
      splitCount: json['split_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_expenses_cents': totalExpensesCents,
      'total_income_cents': totalIncomeCents,
      'net_cents': netCents,
      'transaction_count': transactionCount,
      'split_count': splitCount,
    };
  }
}

/// Household summary entity
class HouseholdSummary {
  final String householdId;
  final String currency;
  final DatePeriod period;
  final Totals totals;
  final List<MemberContribution> memberContributions;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<BudgetStatus> budgets;
  final Map<String, int> balances; // userId -> balance in cents

  const HouseholdSummary({
    required this.householdId,
    required this.currency,
    required this.period,
    required this.totals,
    required this.memberContributions,
    required this.categoryBreakdown,
    required this.budgets,
    required this.balances,
  });

  factory HouseholdSummary.fromJson(Map<String, dynamic> json) {
    return HouseholdSummary(
      householdId: json['household_id'] as String,
      currency: json['currency'] as String,
      period: DatePeriod.fromJson(json['period'] as Map<String, dynamic>),
      totals: Totals.fromJson(json['totals'] as Map<String, dynamic>),
      memberContributions: (json['member_contributions'] as List)
          .map((e) => MemberContribution.fromJson(e as Map<String, dynamic>))
          .toList(),
      categoryBreakdown: (json['category_breakdown'] as List)
          .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      budgets: (json['budgets'] as List)
          .map((e) => BudgetStatus.fromJson(e as Map<String, dynamic>))
          .toList(),
      balances: Map<String, int>.from(json['balances'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'household_id': householdId,
      'currency': currency,
      'period': period.toJson(),
      'totals': totals.toJson(),
      'member_contributions':
          memberContributions.map((e) => e.toJson()).toList(),
      'category_breakdown': categoryBreakdown.map((e) => e.toJson()).toList(),
      'budgets': budgets.map((e) => e.toJson()).toList(),
      'balances': balances,
    };
  }
}
