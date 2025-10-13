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
      final response = await supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return Subscription.fromJson(response);
    } catch (e) {
      print('Error fetching subscription: $e');
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
  return subscriptionAsync.maybeWhen(
    data: (subscription) => subscription?.isSubscribed ?? false,
    orElse: () => false,
  );
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
