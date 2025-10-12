class Subscription {
  final String id;
  final String userId;
  final String? stripeSubscriptionId;
  final String? plan;
  final DateTime createdAt;

  Subscription({
    required this.id,
    required this.userId,
    this.stripeSubscriptionId,
    this.plan,
    required this.createdAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      stripeSubscriptionId: json['stripe_subscription_id'] as String?,
      plan: json['plan'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// User has active paid subscription if:
  /// 1. stripe_subscription_id is not null AND
  /// 2. plan is not null AND plan is not "free"
  bool get isSubscribed {
    if (stripeSubscriptionId == null) return false;
    if (plan == null || plan == 'free') return false;
    return true;
  }

  /// Helper to check if user is on free plan
  bool get isFreePlan => plan == 'free' || plan == null;
}
