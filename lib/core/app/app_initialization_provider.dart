import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/core/resources/lib/supabase.dart';

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
          await ref
              .read(deviceRegistrationServiceProvider)
              .initialize()
              .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint(
                  '⚠️ Device registration timed out after 10s (non-critical)');
            },
          );
          debugPrint('✅ Device registration initialized');
          unawaited(ref.read(deviceRegistrationServiceProvider).clearAllNotifications());
        } catch (e) {
          debugPrint('⚠️ Device registration init failed (non-critical): $e');
        }

        final recurringNotifier =
            ref.read(recurringTransactionsProvider(null).notifier);
        unawaited(recurringNotifier.loadRecurringTransactions(auth.uid));

        // Load critical data that should block initialization
        await Future.wait([
          // Load subscription (critical for feature gating)
          _loadSubscription(),
          // Load WhatsApp binding status (critical for UI)
          _loadWhatsAppBinding(),
        ]);

        // Load analytics - this is critical for home page, so await it
        // Analytics notifier has its own retry logic and connection warmup
        await _loadAnalytics(auth.uid);

        // Now that analytics is loaded, save timezone if needed (simple, no polling)
        _saveTimezoneIfMissing(auth.uid);

        // Start household data load in background (non-blocking)
        // This can load after app is visible
        unawaited(_loadHouseholdData(auth.uid));

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
      // Record non-fatal so we can analyze initialization failures in production
      try {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
            fatal: false, reason: 'app_initialization_error');
      } catch (_) {}
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
      // Wait for the subscription provider to initialize
      await ref.read(subscriptionNotifierProvider.future);
      debugPrint('✅ Subscription loaded');
    } catch (e) {
      try {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
            fatal: false, reason: 'subscription_load_error');
      } catch (_) {}
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
      try {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
            fatal: false, reason: 'whatsapp_binding_error');
      } catch (_) {}
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
      try {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
            fatal: false, reason: 'analytics_load_error');
      } catch (_) {}
      debugPrint('❌ Error loading analytics: $e');
    }
  }

  /// Wait for a StateNotifierProvider containing AsyncValue to resolve.
  /// Polls at regular intervals until data is available, error occurs, or timeout.
  Future<T?> _waitForAsyncValue<T>(
    AsyncValue<T> Function() readState, {
    Duration timeout = const Duration(seconds: 15),
    Duration pollInterval = const Duration(milliseconds: 150),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      final state = readState();

      // If we have data and not in a loading state, return it
      if (state.hasValue && !state.isLoading) {
        return state.value;
      }

      // If there's an error and not loading, return null (caller handles)
      if (state.hasError && !state.isLoading) {
        debugPrint('⚠️ AsyncValue resolved with error: ${state.error}');
        return null;
      }

      // Still loading - wait and retry
      await Future.delayed(pollInterval);
    }

    // Timeout reached - return whatever value we have (might be null)
    final finalState = readState();
    debugPrint(
        '⚠️ Timeout (${timeout.inSeconds}s) waiting for AsyncValue, hasValue=${finalState.hasValue}, isLoading=${finalState.isLoading}');
    return finalState.valueOrNull;
  }

  /// Load household data (for "For Us" mode)
  Future<void> _loadHouseholdData(String userId) async {
    try {
      debugPrint('🏠 Loading household data...');

      // Trigger the provider to start loading (creates it if not exists)
      // The StateNotifier constructor calls load() automatically
      ref.read(userHouseholdsProvider(userId));

      // Wait for the provider to finish loading with proper polling
      final households = await _waitForAsyncValue<List<Household>>(
        () => ref.read(userHouseholdsProvider(userId)),
        timeout: const Duration(seconds: 15),
      );

      if (households == null || households.isEmpty) {
        debugPrint('📭 No households found for user (or load failed)');
        return;
      }

      // Initialize selected household
      await ref.read(selectedHouseholdProvider.notifier).initialize(userId);

      // Get the selected household
      final selectedState = ref.read(selectedHouseholdProvider);
      final household = selectedState.household ?? households.first;

      debugPrint('🏠 Preloading data for household: ${household.name}');

      // Get filter state for date range
      final filterState = ref.read(homeFilterProvider);
      final dateRange = getDateRangeFromFilter(
        filterState.dateRangeFilter,
        filterState.customStartDate,
        filterState.customEndDate,
      );
      final from = dateRange['from']!;
      final to = dateRange['to']!;
      final selectedCurrency =
          (filterState.selectedCurrency ?? household.currency).toUpperCase();

      // Preload household recurring transactions
      unawaited(ref
          .read(recurringTransactionsProvider(household.id).notifier)
          .loadRecurringTransactions(userId));

      // Preload all household data in parallel
      await Future.wait([
        // Load expenses
        ref.read(householdExpensesProvider(
          HouseholdExpensesParams(householdId: household.id, limit: 500),
        ).future),

        // Load splits
        ref.read(householdSplitsProvider(
          HouseholdSplitsParams(householdId: household.id),
        ).future),

        // Load summary
        ref.read(householdSummaryProvider(
          HouseholdSummaryParams(
            householdId: household.id,
            currency: selectedCurrency,
            startDate: from.toIso8601String(),
            endDate: to.toIso8601String(),
          ),
        ).future),
      ]);

      // Trigger budgets and members load (StateNotifierProviders)
      ref.read(householdBudgetsProvider(household.id));
      ref.read(householdMembersProvider(household.id));

      debugPrint('✅ Household data preloaded');
    } catch (e) {
      try {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
            fatal: false, reason: 'household_load_error');
      } catch (_) {}
      debugPrint('❌ Error loading household data: $e');
      // Non-critical error, continue with app initialization
    }
  }

  /// Save device timezone to user profile if not already set.
  /// This is fire-and-forget - we don't block on it.
  void _saveTimezoneIfMissing(String userId) {
    // Run in background - don't await, don't block
    unawaited(_doSaveTimezone(userId));
  }

  Future<void> _doSaveTimezone(String userId) async {
    try {
      // Check current analytics state - no polling, just read current value
      final analyticsState = ref.read(analyticsProvider);
      
      // If analytics hasn't loaded yet, skip - timezone will be saved on next launch
      if (analyticsState.hasLoadedOnce != true) {
        debugPrint('🕒 Skipping timezone save - analytics not ready yet');
        return;
      }

      // Check if timezone already exists
      final existingTimezone = analyticsState.contact?.preferredTimezone ?? '';
      if (existingTimezone.trim().isNotEmpty) {
        debugPrint('🕒 Timezone already set: $existingTimezone');
        return;
      }

      // Get device timezone
      final timezone = await _getDeviceTimezone();
      if (timezone == null || timezone.isEmpty) {
        debugPrint('🕒 Could not detect device timezone');
        return;
      }

      // Save to backend (with reasonable timeout)
      await supabase.functions
          .invoke(
            'update-preferred-timezone',
            body: {
              'userId': userId,
              'timezone': timezone,
            },
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('🕒 Timezone saved to profile: $timezone');
    } catch (e) {
      // Non-critical - just log and continue
      debugPrint('⚠️ Timezone save failed (non-critical): $e');
    }
  }

  Future<String?> _getDeviceTimezone() async {
    try {
      final now = DateTime.now();
      final name = now.timeZoneName;
      if (name.contains('/')) return name; // Already IANA-like

      final offset = now.timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final hours = offset.inHours.abs().toString().padLeft(2, '0');
      final minutes =
          (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      return 'UTC$sign$hours:$minutes';
    } catch (e) {
      debugPrint('⚠️ Failed to detect device timezone: $e');
      return null;
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
