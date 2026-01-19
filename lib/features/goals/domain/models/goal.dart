class Goal {
  final String id;
  final String userId;
  final String? householdId;
  final String title;
  final String? description;
  final String goalType;
  final String category; // 'savings' or 'paydown'
  final double targetAmount;
  final double currentAmount;
  final String currency;
  final String targetDate;
  final String startDate;
  final String status;
  final double progressPercentage;
  final bool isOnTrack;
  final String privacyScope;
  final String ownerType;
  final List<String> acknowledgedBy;
  final String? baseCurrency;
  final double? fxRate;
  final double? normalizedTargetAmount;
  final double? normalizedCurrentAmount;
  final String? icon;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  // Client-side computed fields
  final bool isOwner;
  final bool isAcknowledged;
  final bool privacyRedacted;

  const Goal({
    required this.id,
    required this.userId,
    this.householdId,
    required this.title,
    this.description,
    required this.goalType,
    required this.category,
    required this.targetAmount,
    required this.currentAmount,
    required this.currency,
    required this.targetDate,
    required this.startDate,
    required this.status,
    required this.progressPercentage,
    required this.isOnTrack,
    required this.privacyScope,
    required this.ownerType,
    required this.acknowledgedBy,
    this.baseCurrency,
    this.fxRate,
    this.normalizedTargetAmount,
    this.normalizedCurrentAmount,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.isOwner = false,
    this.isAcknowledged = false,
    this.privacyRedacted = false,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      householdId: json['household_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      goalType: json['goal_type'] as String,
      category: json['category'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      currency: json['currency'] as String,
      targetDate: json['target_date'] as String,
      startDate: json['start_date'] as String,
      status: json['status'] as String,
      progressPercentage: (json['progress_percentage'] as num).toDouble(),
      isOnTrack: json['is_on_track'] as bool? ?? false,
      privacyScope: json['privacy_scope'] as String? ?? 'full',
      ownerType: json['owner_type'] as String? ?? 'me',
      acknowledgedBy: (json['acknowledged_by'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      baseCurrency: json['base_currency'] as String?,
      fxRate:
          json['fx_rate'] != null ? (json['fx_rate'] as num).toDouble() : null,
      normalizedTargetAmount: json['normalized_target_amount'] != null
          ? (json['normalized_target_amount'] as num) / 100
          : null,
      normalizedCurrentAmount: json['normalized_current_amount'] != null
          ? (json['normalized_current_amount'] as num) / 100
          : null,
      icon: json['icon'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      isOwner: json['isOwner'] as bool? ?? false,
      isAcknowledged: json['isAcknowledged'] as bool? ?? false,
      privacyRedacted: json['privacyRedacted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'household_id': householdId,
      'title': title,
      'description': description,
      'goal_type': goalType,
      'category': category,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'currency': currency,
      'target_date': targetDate,
      'start_date': startDate,
      'status': status,
      'progress_percentage': progressPercentage,
      'is_on_track': isOnTrack,
      'privacy_scope': privacyScope,
      'owner_type': ownerType,
      'acknowledged_by': acknowledgedBy,
      'base_currency': baseCurrency,
      'fx_rate': fxRate,
      'normalized_target_amount': normalizedTargetAmount != null
          ? (normalizedTargetAmount! * 100).round()
          : null,
      'normalized_current_amount': normalizedCurrentAmount != null
          ? (normalizedCurrentAmount! * 100).round()
          : null,
      'icon': icon,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'isOwner': isOwner,
      'isAcknowledged': isAcknowledged,
      'privacyRedacted': privacyRedacted,
    };
  }

  Goal copyWith({
    String? id,
    String? userId,
    String? householdId,
    String? title,
    String? description,
    String? goalType,
    String? category,
    double? targetAmount,
    double? currentAmount,
    String? currency,
    String? targetDate,
    String? startDate,
    String? status,
    double? progressPercentage,
    bool? isOnTrack,
    String? privacyScope,
    String? ownerType,
    List<String>? acknowledgedBy,
    String? baseCurrency,
    double? fxRate,
    double? normalizedTargetAmount,
    double? normalizedCurrentAmount,
    String? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool? isOwner,
    bool? isAcknowledged,
    bool? privacyRedacted,
  }) {
    return Goal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      description: description ?? this.description,
      goalType: goalType ?? this.goalType,
      category: category ?? this.category,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      currency: currency ?? this.currency,
      targetDate: targetDate ?? this.targetDate,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      isOnTrack: isOnTrack ?? this.isOnTrack,
      privacyScope: privacyScope ?? this.privacyScope,
      ownerType: ownerType ?? this.ownerType,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      fxRate: fxRate ?? this.fxRate,
      normalizedTargetAmount:
          normalizedTargetAmount ?? this.normalizedTargetAmount,
      normalizedCurrentAmount:
          normalizedCurrentAmount ?? this.normalizedCurrentAmount,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      isOwner: isOwner ?? this.isOwner,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      privacyRedacted: privacyRedacted ?? this.privacyRedacted,
    );
  }

  double get amountRemaining => targetAmount - currentAmount;

  bool get isHouseholdGoal => householdId != null;

  bool get isSavings => category == 'savings';

  bool get isPaydown => category == 'paydown';

  bool get isActive => status == 'active';

  bool get isCompleted => status == 'completed';
}
