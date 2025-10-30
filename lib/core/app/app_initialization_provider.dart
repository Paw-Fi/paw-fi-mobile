import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

part 'app_initialization_provider.g.dart';

/// Represents the initialization state of the app
enum AppInitState {
  uninitialized,
  initializing,
  initialized,
}

/// Provider that manages app initialization
/// Ensures auth, subscription, WhatsApp binding, and analytics are loaded before routing
@Riverpod(keepAlive: true)
class AppInitialization extends _$AppInitialization {
  @override
  AppInitState build() {
    _initialize();
    return AppInitState.initializing;
  }

  Future<void> _initialize() async {
    try {
      debugPrint('🚀 Starting app initialization...');
      
      // Wait a moment for auth to settle
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Check if user is authenticated
      final auth = ref.read(authProvider);
      debugPrint('🔐 Auth loaded: ${!auth.isEmpty}');
      
      if (!auth.isEmpty) {
        // User is authenticated - load all user-specific data in parallel
        debugPrint('👤 Loading user data...');
        
        // Initialize device registration (push notifications)
        // Keep all app init calls centralized here for consistency
        try {
          debugPrint('🔔 Initializing device registration...');
          await ref.read(deviceRegistrationServiceProvider).initialize();
          debugPrint('✅ Device registration initialized');
        } catch (e) {
          debugPrint('⚠️ Device registration init failed (non-critical): $e');
        }

        await Future.wait([
          // Load subscription
          _loadSubscription(),
          // Load WhatsApp binding status
          _loadWhatsAppBinding(),
          // Load analytics/dashboard data
          _loadAnalytics(auth.uid),
        ]);
        
        debugPrint('✅ All user data loaded');
      } else {
        debugPrint('👋 User not authenticated, skipping data load');
      }
      
      // Mark as initialized
      state = AppInitState.initialized;
      debugPrint('🎉 App initialization complete');
      
      // IMPORTANT: Version check happens AFTER initialization
      // This ensures the splash screen doesn't block on version check
      // The force update dialog will show on top of the app if needed
      _checkAppVersion();
    } catch (e) {
      debugPrint('❌ Error during app initialization: $e');
      // Even if there's an error, mark as initialized to avoid stuck splash screen
      state = AppInitState.initialized;
    }
  }
  
  /// Check app version (non-blocking)
  Future<void> _checkAppVersion() async {
    try {
      // This will be handled by a separate version check in the main app widget
      // We don't want to block initialization on version check
      debugPrint('📱 Version check will be performed by version provider');
    } catch (e) {
      debugPrint('❌ Error checking version: $e');
    }
  }

  /// Load subscription data
  Future<void> _loadSubscription() async {
    try {
      debugPrint('💳 Loading subscription...');
      final subscriptionAsync = ref.read(subscriptionNotifierProvider);
      
      await subscriptionAsync.when(
        data: (_) {
          debugPrint('✅ Subscription loaded');
          return Future.value();
        },
        loading: () async {
          // Wait for subscription to load
          await Future.delayed(const Duration(milliseconds: 500));
          debugPrint('⏳ Subscription still loading...');
        },
        error: (error, _) {
          debugPrint('❌ Subscription error: $error');
          return Future.value();
        },
      );
    } catch (e) {
      debugPrint('❌ Error loading subscription: $e');
    }
  }

  /// Load WhatsApp binding status
  Future<void> _loadWhatsAppBinding() async {
    try {
      debugPrint('💬 Loading WhatsApp binding...');
      // This will trigger the provider to load
      final bindingAsync = ref.read(whatsAppBindingProvider.future);
      await bindingAsync;
      debugPrint('✅ WhatsApp binding loaded');
    } catch (e) {
      debugPrint('❌ Error loading WhatsApp binding: $e');
    }
  }

  /// Load analytics/dashboard data
  Future<void> _loadAnalytics(String userId) async {
    try {
      debugPrint('📊 Loading analytics...');
      // Load analytics data which includes user contact and expenses
      await ref.read(analyticsProvider.notifier).loadData(userId);
      debugPrint('✅ Analytics loaded');
    } catch (e) {
      debugPrint('❌ Error loading analytics: $e');
    }
  }

  /// Force re-initialization (useful after login/logout)
  void reset() {
    debugPrint('🔄 Resetting app initialization...');
    state = AppInitState.initializing;
    _initialize();
  }
  
  /// Clear all cached data (on logout)
  void clearCache() {
    debugPrint('🗑️ Clearing all cached user data...');
    // Unregister device on logout
    try {
      ref.read(deviceRegistrationServiceProvider).unregisterDevice();
    } catch (e) {
      debugPrint('⚠️ Failed to unregister device (non-critical): $e');
    }
    
    // Clear WhatsApp binding (keepAlive provider)
    ref.read(whatsAppBindingProvider.notifier).clear();
    
    // Clear analytics data (StateNotifierProvider - auto-dispose but needs clearing)
    ref.read(analyticsProvider.notifier).clear();
    
    // Clear expense processing state
    ref.read(expenseProcessingProvider.notifier).clear();
    
    // Subscription provider is auto-dispose and will be cleared automatically
    // Auth provider maintains only auth state, no user-specific data to clear
    
    debugPrint('✅ All cached user data cleared');
  }
}
