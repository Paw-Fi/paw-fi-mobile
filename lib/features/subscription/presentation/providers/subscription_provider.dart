import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import '../../data/models/subscription.dart';

part 'subscription_provider.g.dart';

@riverpod
class SubscriptionNotifier extends _$SubscriptionNotifier {
  @override
  Future<Subscription?> build() async {
    final user = ref.watch(authProvider);
    if (user.isEmpty) return null;

    return _fetchSubscription(user.uid);
  }

  Future<Subscription?> _fetchSubscription(String userId) async {
    try {
      print('🔍 [SubscriptionProvider] Fetching subscription for userId: $userId');
      
      final response = await supabase
          .from('subscriptions')
          .select('id, user_id, stripe_subscription_id, stripe_customer_id, plan, status, bound_to_user_id, bound_to_household_id, created_at, updated_at')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1);

      final responseList = response as List;
      print('📊 [SubscriptionProvider] Response: ${responseList.length} rows');
      
      if (responseList.isEmpty) {
        print('❌ [SubscriptionProvider] No subscription found - returning null');
        return null;
      }
      
      final subData = responseList[0] as Map<String, dynamic>;
      print('📦 [SubscriptionProvider] Subscription data: plan=${subData['plan']}, status=${subData['status']}, bound_to=${subData['bound_to_user_id']}');
      
      final subscription = Subscription.fromJson(subData);
      print('✅ [SubscriptionProvider] Created Subscription object, isSubscribed=${subscription.isSubscribed}');
      
      return subscription;
    } catch (e) {
      print('❌ [SubscriptionProvider] Error fetching subscription: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authProvider);
      if (user.isEmpty) return null;
      return _fetchSubscription(user.uid);
    });
  }
}

// Helper provider to check if user has active subscription
@riverpod
bool hasActiveSubscription(HasActiveSubscriptionRef ref) {
  final subscriptionAsync = ref.watch(subscriptionNotifierProvider);
  final result = subscriptionAsync.maybeWhen(
    data: (subscription) {
      final hasActive = subscription?.isSubscribed ?? false;
      print('🎯 [hasActiveSubscription] Subscription: ${subscription?.plan}, isSubscribed: $hasActive');
      return hasActive;
    },
    orElse: () {
      print('⏳ [hasActiveSubscription] Subscription still loading or error - returning false');
      return false;
    },
  );
  print('🎯 [hasActiveSubscription] Final result: $result');
  return result;
}

// Helper provider to check subscription loading state
// Returns true if subscription check is complete (loaded or error)
@riverpod
bool isSubscriptionLoaded(IsSubscriptionLoadedRef ref) {
  final subscriptionAsync = ref.watch(subscriptionNotifierProvider);
  return subscriptionAsync.maybeWhen(
    data: (_) => true,
    error: (_, __) => true,
    orElse: () => false,
  );
}
