import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart' show AutoDisposeRef;
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
      appLog('Fetching subscription for userId: $userId', name: 'SubscriptionProvider');
      
      final response = await supabase
          .from('subscriptions')
          .select('id, user_id, stripe_subscription_id, stripe_customer_id, plan, status, bound_to_user_id, bound_to_household_id, created_at, updated_at')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1);

      final responseList = response as List;
      appLog('Response: ${responseList.length} rows', name: 'SubscriptionProvider');
      
      if (responseList.isEmpty) {
        appLog('No subscription found - returning null', name: 'SubscriptionProvider');
        return null;
      }
      
      final subData = responseList[0] as Map<String, dynamic>;
      appLog(
        'Subscription data: plan=${subData['plan']}, status=${subData['status']}, bound_to=${subData['bound_to_user_id']}',
        name: 'SubscriptionProvider',
      );
      
      final subscription = Subscription.fromJson(subData);
      appLog(
        'Created Subscription object, isSubscribed=${subscription.isSubscribed}',
        name: 'SubscriptionProvider',
      );
      
      return subscription;
    } catch (e, stack) {
      appLog('Error fetching subscription', name: 'SubscriptionProvider', error: e, stackTrace: stack);
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
bool hasActiveSubscription(AutoDisposeRef ref) {
  final subscriptionAsync = ref.watch(subscriptionNotifierProvider);
  final result = subscriptionAsync.maybeWhen(
    data: (subscription) {
      final hasActive = subscription?.isSubscribed ?? false;
      appLog('Subscription: ${subscription?.plan}, isSubscribed: $hasActive', name: 'SubscriptionProvider');
      return hasActive;
    },
    orElse: () {
      appLog('Subscription still loading or error - returning false', name: 'SubscriptionProvider');
      return false;
    },
  );
  appLog('hasActiveSubscription result: $result', name: 'SubscriptionProvider');
  return result;
}

// Helper provider to check subscription loading state
// Returns true if subscription check is complete (loaded or error)
@riverpod
bool isSubscriptionLoaded(AutoDisposeRef ref) {
  final subscriptionAsync = ref.watch(subscriptionNotifierProvider);
  return subscriptionAsync.maybeWhen(
    data: (_) => true,
    error: (_, __) => true,
    orElse: () => false,
  );
}
