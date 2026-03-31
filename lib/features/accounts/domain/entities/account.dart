class AccountEntity {
  final String id;
  final String userId;
  final String? householdId;
  final String name;
  final String icon;
  final String color;
  final int openingBalanceCents;
  final int? goalAmountCents;
  final bool isDefault;
  final bool isSystem;
  final bool isArchived;
  final int currentBalanceCents;

  const AccountEntity({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.name,
    required this.icon,
    required this.color,
    required this.openingBalanceCents,
    required this.goalAmountCents,
    required this.isDefault,
    required this.isSystem,
    required this.isArchived,
    required this.currentBalanceCents,
  });

  factory AccountEntity.fromJson(Map<String, dynamic> json) {
    return AccountEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      householdId: json['household_id'] as String?,
      name: (json['name'] as String?)?.trim() ?? '',
      icon: (json['icon'] as String?)?.trim() ?? 'wallet',
      color: (json['color'] as String?)?.trim() ?? '#6B7280',
      openingBalanceCents:
          (json['opening_balance_cents'] as num?)?.round() ?? 0,
      goalAmountCents: (json['goal_amount_cents'] as num?)?.round(),
      isDefault: json['is_default'] == true,
      isSystem: json['is_system'] == true,
      isArchived: json['is_archived'] == true,
      currentBalanceCents:
          (json['current_balance_cents'] as num?)?.round() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'household_id': householdId,
      'name': name,
      'icon': icon,
      'color': color,
      'opening_balance_cents': openingBalanceCents,
      'goal_amount_cents': goalAmountCents,
      'is_default': isDefault,
      'is_system': isSystem,
      'is_archived': isArchived,
      'current_balance_cents': currentBalanceCents,
    };
  }
}
