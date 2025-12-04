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
      final initStopwatch = Stopwatch()..start();
      debugPrint('🚀 [INIT] Starting app initialization...');
      
      // CRITICAL: Wrap entire initialization in timeout to prevent hanging
      // With small dataset, init should complete in <3s, 10s is generous safety margin
      await _performInitialization().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('❌ [INIT] CRITICAL: Initialization timed out after 10s!');
          debugPrint('⚠️ [INIT] This indicates a serious issue - small dataset should load in <3s');
          try {
            FirebaseCrashlytics.instance.recordError(
              TimeoutException('App initialization timeout after 10s'),
              StackTrace.current,
              fatal: false,
              reason: 'app_initialization_timeout',
            );
          } catch (_) {}
        },
      );
      
      initStopwatch.stop();
      debugPrint('✅ [INIT] Total initialization time: ${initStopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      // Record non-fatal so we can analyze initialization failures in production
      try {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
            fatal: false, reason: 'app_initialization_error');
      } catch (_) {}
      debugPrint('❌ Error during app initialization: $e');
    } finally {
      // CRITICAL: Always mark as initialized in finally block
      // This guarantees we never hang on splash screen, regardless of what happens
      state = AppInitState.initialized;
      debugPrint('🎉 App initialization complete (state set to initialized)');
    }
  }

  /// Perform the actual initialization work
  /// Separated so we can wrap it in timeout and finally block
  Future<void> _performInitialization() async {
    // Check if user is authenticated
    final auth = ref.read(authProvider);
    debugPrint('🔐 Auth loaded: ${!auth.isEmpty}');

    if (!auth.isEmpty) {
      // User is authenticated - load all user-specific data
      debugPrint('👤 Loading user data...');

      // Initialize device registration (push notifications)
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

      // Start recurring transactions load in background
      final recurringNotifier =
          ref.read(recurringTransactionsProvider(null).notifier);
      unawaited(recurringNotifier.loadRecurringTransactions(auth.uid));

      // Warm up Supabase connection before making RPC calls
      // This prevents cold-start issues on fresh installs
      await _warmupSupabaseConnection(auth.uid);

      // Load critical data with aggressive timeout (should be <1s)
      debugPrint('⏱️ [INIT] Loading critical data (subscription + WhatsApp)...');
      final criticalStopwatch = Stopwatch()..start();
      
      try {
        await Future.wait([
          // Load subscription (critical for feature gating)
          _loadSubscription(),
          // Load WhatsApp binding status (critical for UI)
          _loadWhatsAppBinding(),
        ]).timeout(const Duration(seconds: 5));
        
        criticalStopwatch.stop();
        debugPrint('✅ [INIT] Critical data loaded in ${criticalStopwatch.elapsedMilliseconds}ms');
      } on TimeoutException {
        criticalStopwatch.stop();
        debugPrint('❌ [INIT] CRITICAL: Data load timed out after 5s - this should never happen with small dataset!');
      }

      // Load analytics in background - do NOT block initialization
      // Analytics has its own 45s RPC timeout which is too long for init phase
      // Let it load in background and home page will show loading state
      debugPrint('📊 Starting analytics load in background (non-blocking)...');
      unawaited(_loadAnalytics(auth.uid));

      // Save timezone if needed (fire-and-forget)
      _saveTimezoneIfMissing(auth.uid);

      // Start household data load in background (non-blocking)
      unawaited(_loadHouseholdData(auth.uid));

      debugPrint('✅ All user data loaded');
    } else {
      debugPrint('👋 User not authenticated, skipping data load');
    }

    // IMPORTANT: Version check happens AFTER initialization
    _checkAppVersion();
  }

  /// Warm up Supabase connection to prevent cold-start timeouts
  /// This is critical for fresh installs where the first RPC call may hang
  Future<void> _warmupSupabaseConnection(String userId) async {
    try {
      debugPrint('🔥 Warming up Supabase connection...');
      final stopwatch = Stopwatch()..start();
      
      // Make a lightweight query to establish connection
      // This prevents the main RPC call from timing out on fresh installs
      await supabase
          .from('user_contacts')
          .select('id')
          .eq('user_id', userId)
          .limit(1)
          .timeout(const Duration(seconds: 10));
      
      // Small delay to let connection stabilize
      await Future.delayed(const Duration(milliseconds: 100));
      
      stopwatch.stop();
      debugPrint('✅ Connection warmed up in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      // Non-critical - if warmup fails, main query will still attempt
      debugPrint('⚠️ Connection warmup failed (non-critical): $e');
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
      debugPrint('💳 [INIT] Loading subscription...');
      final stopwatch = Stopwatch()..start();
      
      // Wait for the subscription provider to initialize
      await ref.read(subscriptionNotifierProvider.future);
      
      stopwatch.stop();
      debugPrint('✅ [INIT] Subscription loaded in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      try {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
            fatal: false, reason: 'subscription_load_error');
      } catch (_) {}
      debugPrint('❌ [INIT] Error loading subscription: $e');
    }
  }

  /// Load WhatsApp binding status
  Future<void> _loadWhatsAppBinding() async {
    try {
      debugPrint('💬 [INIT] Loading WhatsApp binding...');
      final stopwatch = Stopwatch()..start();
      
      // This will trigger the provider to load
      final bindingAsync = ref.read(whatsAppBindingProvider.future);
      await bindingAsync;
      
      stopwatch.stop();
      debugPrint('✅ [INIT] WhatsApp binding loaded in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      try {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
            fatal: false, reason: 'whatsapp_binding_error');
      } catch (_) {}
      debugPrint('❌ [INIT] Error loading WhatsApp binding: $e');
    }
  }

  /// Load analytics/dashboard data
  /// This is called in background and should not block initialization
  Future<void> _loadAnalytics(String userId) async {
    try {
      debugPrint('📊 [BACKGROUND] Loading analytics...');
      final stopwatch = Stopwatch()..start();
      
      // Load analytics data which includes user contact and expenses
      await ref.read(analyticsProvider.notifier).loadData(userId);
      
      stopwatch.stop();
      debugPrint('✅ [BACKGROUND] Analytics loaded in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      try {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
            fatal: false, reason: 'analytics_load_error');
      } catch (_) {}
      debugPrint('❌ [BACKGROUND] Error loading analytics: $e');
    }
  }

  /// Load household data (for "For Us" mode)
  Future<void> _loadHouseholdData(String userId) async {
    try {
      debugPrint('🏠 Loading household data...');

      // Ensure the user households provider has loaded at least once.
      // This calls the repository and waits for completion without any
      // arbitrary polling/timeouts; network timeouts are handled by Supabase.
      await ref.read(userHouseholdsProvider(userId).notifier).load();

      final householdsAsync = ref.read(userHouseholdsProvider(userId));
      final households = householdsAsync.value ?? <Household>[];

      if (households.isEmpty) {
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
