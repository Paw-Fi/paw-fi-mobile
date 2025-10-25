class Subscription {
  final String id;
  final String userId;
  final String? stripeSubscriptionId;
  final String? stripeCustomerId;
  final String? plan;
  final String? status;
  final DateTime? currentPeriodEnd;
  final DateTime? nextPaymentDate;
  final bool? cancelAtPeriodEnd;
  final String? boundToUserId;
  final String? boundToHouseholdId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    this.stripeSubscriptionId,
    this.stripeCustomerId,
    this.plan,
    this.status,
    this.currentPeriodEnd,
    this.nextPaymentDate,
    this.cancelAtPeriodEnd,
    this.boundToUserId,
    this.boundToHouseholdId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      stripeSubscriptionId: json['stripe_subscription_id'] as String?,
      stripeCustomerId: json['stripe_customer_id'] as String?,
      plan: json['plan'] as String?,
      status: json['status'] as String?,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.tryParse(json['current_period_end'].toString())
          : null,
      nextPaymentDate: json['next_payment_date'] != null
          ? DateTime.tryParse(json['next_payment_date'].toString())
          : null,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool?,
      boundToUserId: json['bound_to_user_id'] as String?,
      boundToHouseholdId: json['bound_to_household_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  /// Subscription logic (with household binding support):
  /// 1. No row in DB → Provider returns null → hasActiveSubscription = false (FREE)
  /// 2. Row exists + stripe_subscription_id is null + plan is NOT "lifetime" + status is NOT "trialing" + NOT bound to household → FREE
  /// 3. Row exists + plan IS "lifetime" + status = "active" → SUBSCRIBED
  /// 4. Row exists + status = "trialing" → SUBSCRIBED (trial period)
  /// 5. Row exists + status = "active" + stripe_subscription_id is NOT null → SUBSCRIBED (active subscription)
  /// 6. Row exists + status = "active" + bound_to_user_id is NOT null → SUBSCRIBED (household member with shared access)
  bool get isSubscribed {
    print('🔍 [Subscription] Checking isSubscribed: plan=$plan, status=$status, boundTo=$boundToUserId');
    
    // Case 3: Lifetime plan with active status
    if (plan == 'lifetime' && status == 'active') {
      print('✅ [Subscription] LIFETIME plan with active status - subscribed=true');
      return true;
    }
    
    // Case 4: Trialing status - user is in trial period
    if (status == 'trialing') {
      print('✅ [Subscription] TRIALING status - subscribed=true');
      return true;
    }
    
    // Case 6: Active status with household binding (shared subscription access)
    if (status == 'active' && boundToUserId != null) {
      print('✅ [Subscription] ACTIVE status with household binding - subscribed=true (shared access)');
      return true;
    }
    
    // Case 5: Active status with Stripe subscription ID
    if (status == 'active' && stripeSubscriptionId != null) {
      // Additional check: plan should not be explicitly free
      if (plan == 'free') {
        print('❌ [Subscription] Active status but plan is "free" - subscribed=false');
        return false;
      }
      print('✅ [Subscription] ACTIVE status with stripe_subscription_id - subscribed=true');
      return true;
    }
    
    // Case 2: All other cases mean free/inactive
    print('❌ [Subscription] No matching active/trialing subscription - subscribed=false (FREE)');
    return false;
  }

  /// Helper to check if user is on free plan
  bool get isFreePlan => plan == 'free' || plan == null;
}
