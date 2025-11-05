import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:functions_client/functions_client.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import '../../data/models/subscription_details.dart';

class SubscriptionManagementNotifier extends AsyncNotifier<SubscriptionDetails?> {
  @override
  Future<SubscriptionDetails?> build() async {
    final user = ref.watch(authProvider);
    if (user.isEmpty) return null;

    return _fetchSubscriptionDetails(user.uid);
  }

  Future<SubscriptionDetails?> _fetchSubscriptionDetails(String userId) async {
    try {
      // Use GET method with query parameters, similar to web version
      final response = await supabase.functions.invoke(
        'get-subscription?userId=${Uri.encodeComponent(userId)}',
        method: HttpMethod.get,
      );

      if (response.status >= 400) {
        throw Exception('Failed to fetch subscription details: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;
      appLog('Subscription details received: $data', name: 'SubscriptionManagement');

      return SubscriptionDetails.fromJson(data);
    } catch (e, stack) {
      appLog('Error fetching subscription details', name: 'SubscriptionManagement', error: e, stackTrace: stack);
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
  }
}

final subscriptionManagementProvider = AsyncNotifierProvider<SubscriptionManagementNotifier, SubscriptionDetails?>(
  () => SubscriptionManagementNotifier(),
);
