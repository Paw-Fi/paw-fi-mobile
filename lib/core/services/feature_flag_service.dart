import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for checking feature flags from the backend
///
/// Feature flags allow for progressive rollout and A/B testing of features.
/// Flags are managed server-side and respect:
/// - Global on/off toggles
/// - Percentage-based rollout (e.g., 10% of users)
/// - User whitelists/blacklists
/// - Environment-specific flags (dev/staging/production)
class FeatureFlagService {
  final SupabaseClient _supabase;

  FeatureFlagService(this._supabase);

  /// Check if a feature is enabled for the current user
  ///
  /// Example:
  /// ```dart
  /// final householdsEnabled = await featureFlagService.isEnabled('households.enabled');
  /// if (householdsEnabled) {
  ///   // Show households feature
  /// }
  /// ```
  Future<bool> isEnabled(String featureKey) async {
    try {
      final response = await _supabase.functions.invoke(
        'feature-flags-check',
        body: {
          'feature_key': featureKey,
        },
      );

      if (response.status != 200) {
        // If there's an error, default to disabled for safety
        debugPrint('Feature flag check failed for $featureKey: ${response.status}');
        return false;
      }

      final data = response.data as Map<String, dynamic>;
      return data['enabled'] as bool? ?? false;
    } catch (e) {
      // If there's an error, default to disabled for safety
      debugPrint('Error checking feature flag $featureKey: $e');
      return false;
    }
  }

  /// Check if a feature is enabled and get its metadata
  ///
  /// Returns a map with 'enabled' (bool) and 'metadata' (Map) keys
  ///
  /// Example:
  /// ```dart
  /// final result = await featureFlagService.checkWithMetadata('households.enabled');
  /// if (result['enabled'] == true) {
  ///   final docs = result['metadata']?['documentation_url'];
  ///   // Use metadata for additional context
  /// }
  /// ```
  Future<Map<String, dynamic>> checkWithMetadata(String featureKey) async {
    try {
      final response = await _supabase.functions.invoke(
        'feature-flags-check',
        body: {
          'feature_key': featureKey,
        },
      );

      if (response.status != 200) {
        return {'enabled': false, 'metadata': null};
      }

      final data = response.data as Map<String, dynamic>;
      return {
        'enabled': data['enabled'] as bool? ?? false,
        'metadata': data['metadata'],
      };
    } catch (e) {
      debugPrint('Error checking feature flag $featureKey: $e');
      return {'enabled': false, 'metadata': null};
    }
  }

  /// Call the database function directly (faster, but requires RLS policies)
  ///
  /// This bypasses the Edge Function and calls the Postgres function directly.
  /// It's faster but requires the feature_flags table to have proper RLS policies.
  Future<bool> isEnabledDirect(String featureKey) async {
    try {
      final response = await _supabase.rpc('is_feature_enabled', params: {
        'feature_key': featureKey,
      });

      return response as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking feature flag $featureKey: $e');
      return false;
    }
  }
}

/// Provider for FeatureFlagService
final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService(Supabase.instance.client);
});

/// Cached provider for households.enabled feature flag
///
/// This provider caches the result for the app session to avoid repeated API calls.
/// Refresh the app to get updated flag values.
///
/// Usage:
/// ```dart
/// final householdsEnabled = ref.watch(householdsEnabledProvider);
/// householdsEnabled.when(
///   data: (enabled) => enabled ? HouseholdsFeature() : DisabledMessage(),
///   loading: () => LoadingIndicator(),
///   error: (err, stack) => ErrorMessage(),
/// );
/// ```
final householdsEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(featureFlagServiceProvider);
  return await service.isEnabled('households.enabled');
});

/// Generic cached provider for any feature flag
///
/// Usage:
/// ```dart
/// final exportPdfEnabled = ref.watch(featureFlagProvider('export.pdf'));
/// ```
final featureFlagProvider = FutureProvider.family<bool, String>((ref, featureKey) async {
  final service = ref.watch(featureFlagServiceProvider);
  return await service.isEnabled(featureKey);
});
