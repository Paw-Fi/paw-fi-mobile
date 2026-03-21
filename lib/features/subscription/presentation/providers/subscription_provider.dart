import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart' show Ref;
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_management_provider.dart';
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
      appLog('Fetching subscription for userId: $userId',
          name: 'SubscriptionProvider');

      final List<dynamic> response = await supabase
          .from('subscriptions')
          .select(
              'id, user_id, stripe_subscription_id, stripe_customer_id, provider, store_product_id, billing_interval, plan, status, current_period_end, cancel_at_period_end, bound_to_user_id, bound_to_household_id, created_at, updated_at')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        appLog('No subscription found - returning null',
            name: 'SubscriptionProvider');
        return null;
      }

      final subData =
          Map<String, dynamic>.from(response.first as Map<String, dynamic>);
      appLog(
        'Subscription data: plan=${subData['plan']}, status=${subData['status']}, bound_to=${subData['bound_to_user_id']}',
        name: 'SubscriptionProvider',
      );

      final subscription = Subscription.fromJson(subData);
      appLog(
        'Created Subscription object, isSubscribed=${subscription.isSubscribed}',
        name: 'SubscriptionProvider',
      );

      // Track if user ever had a subscription for paywall mode determination
      if (_hasEverSubscribed(subscription)) {
        try {
          final prefs = ref.read(sharedPreferencesProvider);
          await prefs.setBool('ever_subscribed:$userId', true);
          appLog('Set ever_subscribed flag for user: $userId',
              name: 'SubscriptionProvider');
        } catch (e) {
          appLog('Failed to set ever_subscribed flag',
              name: 'SubscriptionProvider', error: e);
        }
      }

      return subscription;
    } catch (e, stack) {
      appLog('Error fetching subscription',
          name: 'SubscriptionProvider', error: e, stackTrace: stack);
      return null;
    }
  }

  bool _hasEverSubscribed(Subscription subscription) {
    final plan = (subscription.plan ?? '').toLowerCase();
    if (plan.isNotEmpty && plan != 'free') return true;

    final status = (subscription.status ?? '').toLowerCase();
    final hasStripeSubscriptionId =
        (subscription.stripeSubscriptionId?.isNotEmpty ?? false);
    final isIap = subscription.isIap;

    if (status == 'trialing') return true;
    if (hasStripeSubscriptionId) return true;
    if (isIap) return true;

    return false;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authProvider);
      if (user.isEmpty) return null;
      return _fetchSubscription(user.uid);
    });

    // Cross-invalidate: Mark subscriptionManagementProvider as stale
    // This ensures consistency between the two subscription providers.
    // When subscriptionManagementProvider is next watched, it will refetch.
    // This pattern maintains performance (router uses fast direct DB query)
    // while ensuring both providers stay in sync.
    ref.invalidate(subscriptionManagementProvider);
    appLog('Cross-invalidated subscriptionManagementProvider',
        name: 'SubscriptionProvider');
  }
}

// Helper provider to check if user has active subscription
@riverpod
bool hasActiveSubscription(Ref ref) {
  final subscriptionAsync = ref.watch(subscriptionNotifierProvider);
  final result = subscriptionAsync.maybeWhen(
    data: (subscription) {
      final hasActive = subscription?.isSubscribed ?? false;
      appLog('Subscription: ${subscription?.plan}, isSubscribed: $hasActive',
          name: 'SubscriptionProvider');
      return hasActive;
    },
    orElse: () {
      appLog('Subscription still loading or error - returning false',
          name: 'SubscriptionProvider');
      return false;
    },
  );
  appLog('hasActiveSubscription result: $result', name: 'SubscriptionProvider');
  return result;
}

// Helper provider to check subscription loading state
// Returns true if subscription check is complete (loaded or error)
@riverpod
bool isSubscriptionLoaded(Ref ref) {
  final subscriptionAsync = ref.watch(subscriptionNotifierProvider);
  return subscriptionAsync.maybeWhen(
    data: (_) => true,
    error: (_, __) => true,
    orElse: () => false,
  );
}
