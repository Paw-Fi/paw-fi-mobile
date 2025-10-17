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

  /// Subscription logic:
  /// 1. No row in DB → Provider returns null → hasActiveSubscription = false (FREE)
  /// 2. Row exists + stripe_subscription_id is null + plan is NOT "lifetime" → FREE
  /// 3. Row exists + stripe_subscription_id is null + plan IS "lifetime" → SUBSCRIBED
  /// 4. Row exists + stripe_subscription_id is NOT null → SUBSCRIBED (plus/premium)
  bool get isSubscribed {
    print('🔍 [Subscription] Checking isSubscribed: plan=$plan, stripeSubId=$stripeSubscriptionId');
    
    // Case 3: Lifetime plan (one-time payment, no recurring subscription)
    if (plan == 'lifetime') {
      print('✅ [Subscription] LIFETIME plan - subscribed=true');
      return true;
    }
    
    // Case 2: No Stripe subscription ID means free plan
    // (unless it's lifetime which was checked above)
    if (stripeSubscriptionId == null) {
      print('❌ [Subscription] No stripe_subscription_id and not lifetime - subscribed=false (FREE)');
      return false;
    }
    
    // Case 4: Has Stripe subscription ID - check it's not explicitly free
    if (plan == null || plan == 'free') {
      print('❌ [Subscription] Plan is null or "free" - subscribed=false (FREE)');
      return false;
    }
    
    // Case 4: Valid recurring subscription (plus, premium)
    print('✅ [Subscription] Has stripe_subscription_id and valid plan - subscribed=true');
    return true;
  }

  /// Helper to check if user is on free plan
  bool get isFreePlan => plan == 'free' || plan == null;
}
