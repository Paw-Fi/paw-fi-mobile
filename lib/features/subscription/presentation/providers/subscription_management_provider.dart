import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import '../../data/models/subscription_details.dart';

class SubscriptionManagementNotifier
    extends AsyncNotifier<SubscriptionDetails?> {
  @override
  Future<SubscriptionDetails?> build() async {
    final user = ref.watch(authProvider);
    if (user.isEmpty) return null;

    return _fetchSubscriptionDetails(user.uid);
  }

  Future<SubscriptionDetails?> _fetchSubscriptionDetails(String userId) async {
    try {
      final response = await supabase.functions.invoke(
        // Authenticated edge function - returns subscription for current user
        'get-subscription',
        method: HttpMethod.get,
      );

      if (response.status >= 400) {
        throw Exception(
            'Failed to fetch subscription details: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;
      appLog('Subscription details received: $data',
          name: 'SubscriptionManagement');

      return SubscriptionDetails.fromJson(data);
    } catch (e, stack) {
      appLog('Error fetching subscription details',
          name: 'SubscriptionManagement', error: e, stackTrace: stack);
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authProvider);
      if (user.isEmpty) return null;
      return _fetchSubscriptionDetails(user.uid);
    });

    // Cross-invalidate: Mark subscriptionNotifierProvider as stale
    // This ensures consistency between the two subscription providers.
    // When subscriptionNotifierProvider is next watched (e.g., by router),
    // it will refetch fresh data from the database.
    ref.invalidate(subscriptionNotifierProvider);
    appLog('Cross-invalidated subscriptionNotifierProvider',
        name: 'SubscriptionManagement');
  }

  Future<Map<String, dynamic>> previewSubscriptionChange({
    required String newPlan,
    String? newBillingInterval,
  }) async {
    final user = ref.read(authProvider);
    if (user.isEmpty) throw Exception('User not logged in');

    try {
      final response = await supabase.functions.invoke(
        'preview-subscription-change',
        method: HttpMethod.post,
        body: {
          'userId': user.uid,
          'newPlan': newPlan,
          if (newBillingInterval != null)
            'newBillingInterval': newBillingInterval,
        },
      );

      if (response.status >= 400) {
        final errorMsg = response.data is Map && response.data['error'] != null
            ? response.data['error']
            : 'Failed to preview subscription change';
        throw Exception(errorMsg);
      }

      return response.data as Map<String, dynamic>;
    } catch (e, stack) {
      appLog('Error previewing subscription change',
          name: 'SubscriptionManagement', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> changePlan({
    required String plan,
    String? billingInterval,
    int? prorationDate,
  }) async {
    await _updateSubscription(
      action: 'change_plan',
      plan: plan,
      billingInterval: billingInterval,
      prorationDate: prorationDate,
    );
  }

  Future<void> cancelSubscription() async {
    await _updateSubscription(action: 'cancel');
  }

  Future<void> resumeSubscription() async {
    await _updateSubscription(action: 'resume');
  }

  Future<void> grantPaywallReturnTrial() async {
    await _updateSubscription(
      action: 'grant_paywall_return_trial',
    );
  }

  Future<void> markPaywallReturnExit({
    DateTime? exitedAtUtc,
  }) async {
    try {
      await _updateSubscription(
        action: 'mark_paywall_return_exit',
        exitedAtUtc: exitedAtUtc,
        refreshAfterUpdate: false,
      );
    } catch (e, stack) {
      appLog('Failed to mark paywall return exit',
          name: 'SubscriptionManagement', error: e, stackTrace: stack);
    }
  }

  Future<void> _updateSubscription({
    required String action,
    String? plan,
    String? billingInterval,
    int? prorationDate,
    DateTime? exitedAtUtc,
    bool refreshAfterUpdate = true,
  }) async {
    final user = ref.read(authProvider);
    if (user.isEmpty) throw Exception('User not logged in');

    try {
      final response = await supabase.functions.invoke(
        'update-subscription',
        method: HttpMethod.post,
        body: {
          'userId': user.uid,
          'action': action,
          if (plan != null) 'plan': plan,
          if (billingInterval != null) 'billingInterval': billingInterval,
          if (prorationDate != null) 'prorationDate': prorationDate,
          if (exitedAtUtc != null)
            'exitAtIso': exitedAtUtc.toUtc().toIso8601String(),
        },
      );

      if (response.status >= 400) {
        final errorMsg = response.data is Map && response.data['error'] != null
            ? response.data['error']
            : 'Failed to update subscription';
        throw Exception(errorMsg);
      }

      if (refreshAfterUpdate) {
        // Refresh state after successful update
        await refresh();
      }
    } catch (e, stack) {
      appLog('Error updating subscription',
          name: 'SubscriptionManagement', error: e, stackTrace: stack);
      rethrow;
    }
  }
}

final subscriptionManagementProvider =
    AsyncNotifierProvider<SubscriptionManagementNotifier, SubscriptionDetails?>(
  () => SubscriptionManagementNotifier(),
);
