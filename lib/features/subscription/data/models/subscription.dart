import 'package:moneko/core/core.dart';

class Subscription {
  final String id;
  final String userId;
  final String? stripeSubscriptionId;
  final String? stripeCustomerId;
  final String? provider; // stripe | app_store | play_store
  final String? storeProductId;
  final String? plan;
  final String? status;
  final DateTime? currentPeriodEnd;
  final DateTime? nextPaymentDate;
  final bool? cancelAtPeriodEnd;
  final String? boundToUserId;
  final String? boundToHouseholdId;
  final String? billingInterval; // Added field
  final DateTime createdAt;
  final DateTime? updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    this.stripeSubscriptionId,
    this.stripeCustomerId,
    this.provider,
    this.storeProductId,
    this.plan,
    this.status,
    this.currentPeriodEnd,
    this.nextPaymentDate,
    this.cancelAtPeriodEnd,
    this.boundToUserId,
    this.boundToHouseholdId,
    this.billingInterval, // Added param
    required this.createdAt,
    this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      stripeSubscriptionId: json['stripe_subscription_id'] as String?,
      stripeCustomerId: json['stripe_customer_id'] as String?,
      provider: json['provider'] as String?,
      storeProductId: json['store_product_id'] as String?,
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
      billingInterval: json['billing_interval'] as String?, // Added mapping
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'stripe_subscription_id': stripeSubscriptionId,
      'stripe_customer_id': stripeCustomerId,
      'provider': provider,
      'store_product_id': storeProductId,
      'plan': plan,
      'status': status,
      'current_period_end': currentPeriodEnd?.toIso8601String(),
      'next_payment_date': nextPaymentDate?.toIso8601String(),
      'cancel_at_period_end': cancelAtPeriodEnd,
      'bound_to_user_id': boundToUserId,
      'bound_to_household_id': boundToHouseholdId,
      'billing_interval': billingInterval, // Added mapping
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Subscription logic (with household binding support):
  /// 1. No row in DB → Provider returns null → hasActiveSubscription = false (FREE)
  /// 2. Row exists + stripe_subscription_id is null + plan is NOT "lifetime" + status is NOT "trialing" + NOT bound to household → FREE
  /// 3. Row exists + plan IS "lifetime" + status = "active" → SUBSCRIBED
  /// 4. Row exists + status = "trialing" → SUBSCRIBED (trial period)
  /// 5. Row exists + status = "active" + stripe_subscription_id is NOT null → SUBSCRIBED (active subscription)
  /// 6. Row exists + status = "active" + bound_to_user_id is NOT null → SUBSCRIBED (household member with shared access)
  /// 7. Row exists + status = "canceled" → NOT SUBSCRIBED (cancelled subscription)
  bool get isSubscribed {
    appLog(
        'Checking isSubscribed: plan=$plan, status=$status, boundTo=$boundToUserId',
        name: 'Subscription');

    // Case 7: Cancelled status - subscription is cancelled, not active
    if (status == 'canceled') {
      appLog('CANCELED status - subscribed=false', name: 'Subscription');
      return false;
    }

    // Case 3: Lifetime plan with active status
    if (plan == 'lifetime' && status == 'active') {
      appLog('LIFETIME plan with active status - subscribed=true',
          name: 'Subscription');
      return true;
    }

    // Case 4: Trialing status - user is in trial period
    if (status == 'trialing') {
      if (currentPeriodEnd == null) {
        appLog(
            'TRIALING status but no current_period_end - subscribed=false (FAIL-SAFE)',
            name: 'Subscription');
        return false;
      }
      final isTrialValid = currentPeriodEnd!.isAfter(DateTime.now());
      appLog('TRIALING status - expires=$currentPeriodEnd valid=$isTrialValid',
          name: 'Subscription');
      return isTrialValid;
    }

    // Case 5/6: Active status with valid entitlement window
    if (status == 'active') {
      if (plan == 'free') {
        appLog('Active status but plan is "free" - subscribed=false',
            name: 'Subscription');
        return false;
      }

      if (plan == 'lifetime') {
        appLog('ACTIVE status with lifetime plan - subscribed=true',
            name: 'Subscription');
        return true;
      }

      if (currentPeriodEnd == null) {
        appLog(
            'ACTIVE status missing current_period_end - subscribed=false (FAIL-SAFE)',
            name: 'Subscription');
        return false;
      }

      final isValid = currentPeriodEnd!.isAfter(DateTime.now());
      appLog('ACTIVE status - expires=$currentPeriodEnd valid=$isValid',
          name: 'Subscription');
      return isValid;
    }

    if (status == 'past_due') {
      if (plan == 'free') {
        appLog('PAST_DUE status but plan is "free" - subscribed=false',
            name: 'Subscription');
        return false;
      }

      if (currentPeriodEnd == null) {
        appLog(
            'PAST_DUE status missing current_period_end - subscribed=false (FAIL-SAFE)',
            name: 'Subscription');
        return false;
      }

      final isStillEntitled = currentPeriodEnd!.isAfter(DateTime.now());
      appLog(
          'PAST_DUE status - entitlement expires=$currentPeriodEnd valid=$isStillEntitled',
          name: 'Subscription');
      return isStillEntitled;
    }

    // Case 2: All other cases mean free/inactive
    appLog('No matching access-granting subscription - subscribed=false (FREE)',
        name: 'Subscription');
    return false;
  }

  /// Helper to check if user is on free plan
  bool get isFreePlan => plan == 'free' || plan == null;

  bool get isIap => provider == 'app_store' || provider == 'play_store';
}
