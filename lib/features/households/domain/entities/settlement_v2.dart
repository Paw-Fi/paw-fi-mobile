enum SettlementBreakdownDirectionV2 {
  youOwe,
  theyOweYou;

  static SettlementBreakdownDirectionV2 fromJson(String value) {
    switch (value) {
      case 'you_owe':
        return SettlementBreakdownDirectionV2.youOwe;
      case 'they_owe_you':
        return SettlementBreakdownDirectionV2.theyOweYou;
      default:
        throw ArgumentError('Unknown SettlementBreakdownDirectionV2: $value');
    }
  }
}

class SettlementPairwiseBalance {
  final String otherUserId;
  final String currency;
  final int splitToCents;
  final int splitFromCents;
  final int paidToCents;
  final int paidFromCents;
  final int netCents;

  const SettlementPairwiseBalance({
    required this.otherUserId,
    required this.currency,
    required this.splitToCents,
    required this.splitFromCents,
    required this.paidToCents,
    required this.paidFromCents,
    required this.netCents,
  });

  int get youOweCents => netCents > 0 ? netCents : 0;

  int get youAreOwedCents => netCents < 0 ? -netCents : 0;

  factory SettlementPairwiseBalance.fromJson(Map<String, dynamic> json) {
    return SettlementPairwiseBalance(
      otherUserId: json['other_user_id'] as String,
      currency: (json['currency'] as String).toUpperCase(),
      splitToCents: (json['split_to_cents'] as num?)?.toInt() ?? 0,
      splitFromCents: (json['split_from_cents'] as num?)?.toInt() ?? 0,
      paidToCents: (json['paid_to_cents'] as num?)?.toInt() ?? 0,
      paidFromCents: (json['paid_from_cents'] as num?)?.toInt() ?? 0,
      netCents: (json['net_cents'] as num?)?.toInt() ?? 0,
    );
  }
}

class SettlementBreakdownRowV2 {
  final SettlementBreakdownDirectionV2 direction;
  final String expenseId;
  final String splitGroupId;
  final String splitLineId;
  final DateTime expenseDate;
  final String? expenseDescription;
  final String? expenseCategory;
  final String? expenseRawText;
  final String? expenseType;
  final int totalAmountCents;
  final int remainingAmountCents;

  const SettlementBreakdownRowV2({
    required this.direction,
    required this.expenseId,
    required this.splitGroupId,
    required this.splitLineId,
    required this.expenseDate,
    this.expenseDescription,
    this.expenseCategory,
    this.expenseRawText,
    this.expenseType,
    required this.totalAmountCents,
    required this.remainingAmountCents,
  });

  factory SettlementBreakdownRowV2.fromJson(Map<String, dynamic> json) {
    return SettlementBreakdownRowV2(
      direction: SettlementBreakdownDirectionV2.fromJson(
        json['direction'] as String,
      ),
      expenseId: json['expense_id'] as String,
      splitGroupId: json['split_group_id'] as String,
      splitLineId: json['split_line_id'] as String,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      expenseDescription: json['expense_description'] as String?,
      expenseCategory: json['expense_category'] as String?,
      expenseRawText: json['expense_raw_text'] as String?,
      expenseType: json['expense_type'] as String?,
      totalAmountCents: (json['total_amount_cents'] as num?)?.toInt() ?? 0,
      remainingAmountCents:
          (json['remaining_amount_cents'] as num?)?.toInt() ?? 0,
    );
  }
}
