/// Split type enum
enum SplitType {
  equal,
  percentage,
  amount,
  shares;

  String toJson() {
    switch (this) {
      case SplitType.equal:
        return 'equal';
      case SplitType.percentage:
        return 'percentage';
      case SplitType.amount:
        return 'amount';
      case SplitType.shares:
        return 'shares';
    }
  }

  static SplitType fromJson(String value) {
    switch (value) {
      case 'equal':
        return SplitType.equal;
      case 'percentage':
        return SplitType.percentage;
      case 'amount':
        return SplitType.amount;
      case 'shares':
        return SplitType.shares;
      default:
        throw ArgumentError('Unknown SplitType: $value');
    }
  }
}

/// Expense split group entity
class ExpenseSplitGroup {
  final String id;
  final String householdId;
  final String transactionId;
  final String payerUserId;
  final SplitType splitType;
  final String currency;
  final int totalAmountCents;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? payerEmail;
  final List<ExpenseSplitLine>? splitLines;

  const ExpenseSplitGroup({
    required this.id,
    required this.householdId,
    required this.transactionId,
    required this.payerUserId,
    required this.splitType,
    required this.currency,
    required this.totalAmountCents,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.payerEmail,
    this.splitLines,
  });

  factory ExpenseSplitGroup.fromJson(Map<String, dynamic> json) {
    return ExpenseSplitGroup(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      transactionId: json['transaction_id'] as String,
      payerUserId: json['payer_user_id'] as String,
      splitType: SplitType.fromJson(json['split_type'] as String),
      currency: json['currency'] as String,
      totalAmountCents: json['total_amount_cents'] as int,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      payerEmail: json['payer_email'] as String?,
      splitLines: json['split_lines'] != null
          ? (json['split_lines'] as List)
              .map((e) => ExpenseSplitLine.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'transaction_id': transactionId,
      'payer_user_id': payerUserId,
      'split_type': splitType.toJson(),
      'currency': currency,
      'total_amount_cents': totalAmountCents,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'payer_email': payerEmail,
      'split_lines': splitLines?.map((e) => e.toJson()).toList(),
    };
  }
}

/// Expense split line entity
class ExpenseSplitLine {
  final String id;
  final String splitGroupId;
  final String userId;
  final int? amountCents;
  final double? percentage;
  final int? shares;
  final bool isSettled;
  final DateTime? settledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userEmail;
  final String? userName;

  const ExpenseSplitLine({
    required this.id,
    required this.splitGroupId,
    required this.userId,
    this.amountCents,
    this.percentage,
    this.shares,
    required this.isSettled,
    this.settledAt,
    required this.createdAt,
    required this.updatedAt,
    this.userEmail,
    this.userName,
  });

  factory ExpenseSplitLine.fromJson(Map<String, dynamic> json) {
    return ExpenseSplitLine(
      id: json['id'] as String,
      splitGroupId: json['split_group_id'] as String,
      userId: json['user_id'] as String,
      amountCents: json['amount_cents'] as int?,
      percentage: json['percentage'] != null
          ? (json['percentage'] as num).toDouble()
          : null,
      shares: json['shares'] as int?,
      isSettled: json['is_settled'] as bool,
      settledAt: json['settled_at'] != null
          ? DateTime.parse(json['settled_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userEmail: json['user_email'] as String?,
      userName: json['user_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'split_group_id': splitGroupId,
      'user_id': userId,
      'amount_cents': amountCents,
      'percentage': percentage,
      'shares': shares,
      'is_settled': isSettled,
      'settled_at': settledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_email': userEmail,
      'user_name': userName,
    };
  }
}

/// Split creation request
class SplitRequest {
  final String transactionId;
  final String householdId;
  final String payerUserId;
  final SplitType splitType;
  final String currency;
  final int totalAmountCents;
  final String? description;
  final List<SplitLineRequest> splits;

  const SplitRequest({
    required this.transactionId,
    required this.householdId,
    required this.payerUserId,
    required this.splitType,
    required this.currency,
    required this.totalAmountCents,
    this.description,
    required this.splits,
  });

  factory SplitRequest.fromJson(Map<String, dynamic> json) {
    return SplitRequest(
      transactionId: json['transaction_id'] as String,
      householdId: json['household_id'] as String,
      payerUserId: json['payer_user_id'] as String,
      splitType: SplitType.fromJson(json['split_type'] as String),
      currency: json['currency'] as String,
      totalAmountCents: json['total_amount_cents'] as int,
      description: json['description'] as String?,
      splits: (json['splits'] as List)
          .map((e) => SplitLineRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'household_id': householdId,
      'payer_user_id': payerUserId,
      'split_type': splitType.toJson(),
      'currency': currency,
      'total_amount_cents': totalAmountCents,
      'description': description,
      'splits': splits.map((e) => e.toJson()).toList(),
    };
  }
}

/// Split line request
class SplitLineRequest {
  final String userId;
  final int? amountCents;
  final double? percentage;
  final int? shares;

  const SplitLineRequest({
    required this.userId,
    this.amountCents,
    this.percentage,
    this.shares,
  });

  factory SplitLineRequest.fromJson(Map<String, dynamic> json) {
    return SplitLineRequest(
      userId: json['user_id'] as String,
      amountCents: json['amount_cents'] as int?,
      percentage: json['percentage'] != null
          ? (json['percentage'] as num).toDouble()
          : null,
      shares: json['shares'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'amount_cents': amountCents,
      'percentage': percentage,
      'shares': shares,
    };
  }
}
