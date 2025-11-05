class GoalContribution {
  final String id;
  final String goalId;
  final String userId;
  final String? householdId;
  final double amount;
  final String currency;
  final String contributionType; // 'contribution', 'withdrawal', 'interest', 'adjustment'
  final double? normalizedAmount;
  final double? fxRate;
  final String? baseCurrency;
  final String privacyScope;
  final String ownerType;
  final List<String> acknowledgedBy;
  final String source; // 'manual', 'automatic', 'recurring', 'interest'
  final String? note;
  final List<String>? attachmentUrls;
  final DateTime contributionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Client-side computed fields
  final bool isOwner;
  final bool isAcknowledged;
  final bool privacyRedacted;

  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.userId,
    this.householdId,
    required this.amount,
    required this.currency,
    required this.contributionType,
    this.normalizedAmount,
    this.fxRate,
    this.baseCurrency,
    required this.privacyScope,
    required this.ownerType,
    required this.acknowledgedBy,
    required this.source,
    this.note,
    this.attachmentUrls,
    required this.contributionDate,
    required this.createdAt,
    required this.updatedAt,
    this.isOwner = false,
    this.isAcknowledged = false,
    this.privacyRedacted = false,
  });

  factory GoalContribution.fromJson(Map<String, dynamic> json) {
    return GoalContribution(
      id: json['id'] as String,
      goalId: json['goal_id'] as String,
      userId: json['user_id'] as String,
      householdId: json['household_id'] as String?,
      amount: (json['amount_cents'] as num) / 100,
      currency: json['currency'] as String,
      contributionType: json['contribution_type'] as String,
      normalizedAmount: json['normalized_amount_cents'] != null
          ? (json['normalized_amount_cents'] as num) / 100
          : null,
      fxRate: json['fx_rate'] != null ? (json['fx_rate'] as num).toDouble() : null,
      baseCurrency: json['base_currency'] as String?,
      privacyScope: json['privacy_scope'] as String? ?? 'full',
      ownerType: json['owner_type'] as String? ?? 'me',
      acknowledgedBy: (json['acknowledged_by'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      source: json['source'] as String? ?? 'manual',
      note: json['note'] as String?,
      attachmentUrls: (json['attachment_urls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      contributionDate: DateTime.parse(json['contribution_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isOwner: json['isOwner'] as bool? ?? false,
      isAcknowledged: json['isAcknowledged'] as bool? ?? false,
      privacyRedacted: json['privacyRedacted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goal_id': goalId,
      'user_id': userId,
      'household_id': householdId,
      'amount_cents': (amount * 100).round(),
      'currency': currency,
      'contribution_type': contributionType,
      'normalized_amount_cents': normalizedAmount != null
          ? (normalizedAmount! * 100).round()
          : null,
      'fx_rate': fxRate,
      'base_currency': baseCurrency,
      'privacy_scope': privacyScope,
      'owner_type': ownerType,
      'acknowledged_by': acknowledgedBy,
      'source': source,
      'note': note,
      'attachment_urls': attachmentUrls,
      'contribution_date': contributionDate.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'isOwner': isOwner,
      'isAcknowledged': isAcknowledged,
      'privacyRedacted': privacyRedacted,
    };
  }

  bool get isContribution => contributionType == 'contribution';
  bool get isWithdrawal => contributionType == 'withdrawal';
  bool get isInterest => contributionType == 'interest';
  bool get isAdjustment => contributionType == 'adjustment';
}
