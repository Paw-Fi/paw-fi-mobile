import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/services/init_cache_manager.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/profile/domain/entities/whatsapp_binding.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';

part 'app_initialization_provider_v2.g.dart';

/// Initialization state for the app
/// 
/// States:
/// - uninitialized: Initial state, not started
/// - initializing: Currently loading data
/// - initialized: Successfully loaded (may be from cache)
/// - failed: Critical error occurred
enum AppInitState {
  uninitialized,
  initializing,
  initialized,
  failed,
}

/// Initialization data model
/// 
/// Contains all critical data needed for app startup:
/// - user: User contact information
/// - subscription: Subscription status
/// - whatsappBinding: WhatsApp integration status
/// - households: List of households user belongs to
/// - isFromCache: Whether data was loaded from cache
/// - timestamp: When data was fetched
@immutable
class InitData {
  final UserContact? user;
  final Subscription? subscription;
  final WhatsAppBinding? whatsappBinding;
  final List<Household> households;
  final bool isFromCache;
  final DateTime timestamp;
  
  const InitData({
    this.user,
    this.subscription,
    this.whatsappBinding,
    this.households = const [],
    this.isFromCache = false,
    required this.timestamp,
  });
  
  InitData copyWith({
    UserContact? user,
    Subscription? subscription,
    WhatsAppBinding? whatsappBinding,
    List<Household>? households,
    bool? isFromCache,
    DateTime? timestamp,
  }) {
    return InitData(
      user: user ?? this.user,
      subscription: subscription ?? this.subscription,
      whatsappBinding: whatsappBinding ?? this.whatsappBinding,
      households: households ?? this.households,
      isFromCache: isFromCache ?? this.isFromCache,
      timestamp: timestamp ?? this.timestamp,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'user': user?.toJson(),
      'subscription': subscription?.toJson(),
      'whatsapp_binding': whatsappBinding?.toJson(),
      'households': households.map((h) => h.toJson()).toList(),
      'is_from_cache': isFromCache,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  factory InitData.fromJson(Map<String, dynamic> json) {
    return InitData(
      user: json['user'] != null 
          ? UserContact.fromJson(json['user']) 
          : null,
      subscription: json['subscription'] != null 
          ? Subscription.fromJson(json['subscription']) 
          : null,
      whatsappBinding: json['whatsapp_binding'] != null 
          ? WhatsAppBinding.fromJson(json['whatsapp_binding']) 
          : null,
      households: (json['households'] as List<dynamic>?)
          ?.map((h) => Household.fromJson(h))
          .toList() ?? [],
      isFromCache: json['is_from_cache'] ?? false,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}

/// App initialization state container
@immutable
class AppInitializationState {
  final AppInitState state;
  final InitData? data;
  final Exception? error;
  final String? errorMessage;
  final StackTrace? errorStackTrace;
  final Duration? lastInitDuration;
  
  const AppInitializationState({
    required this.state,
    this.data,
    this.error,
    this.errorMessage,
    this.errorStackTrace,
    this.lastInitDuration,
  });
  
  AppInitializationState copyWith({
    AppInitState? state,
    InitData? data,
    Exception? error,
    String? errorMessage,
    StackTrace? errorStackTrace,
    Duration? lastInitDuration,
    bool clearError = false,
  }) {
    return AppInitializationState(
      state: state ?? this.state,
      data: data ?? this.data,
      error: clearError ? null : (error ?? this.error),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorStackTrace: clearError ? null : (errorStackTrace ?? this.errorStackTrace),
      lastInitDuration: lastInitDuration ?? this.lastInitDuration,
    );
  }
}

/// Improved app initialization provider with cache-first strategy
/// 
/// Architecture:
/// 1. Load from cache immediately (if available) → instant UI
/// 2. Fetch fresh data in background
/// 3. Update UI when fresh data arrives
/// 4. Handle errors gracefully
/// 
/// Features:
/// - Cache-first loading (instant startup)
/// - Single backend RPC call (fast & reliable)
/// - Progressive loading (no blocking splash)
/// - Proper error handling
/// - Full observability (timing metrics)
@Riverpod(keepAlive: true)
class AppInitializationV2 extends _$AppInitializationV2 {
  InitCacheManager? _cacheManager;
  String? _appVersion;
  int _operationId = 0;
  
  @override
  AppInitializationState build() {
    _initialize();
    return const AppInitializationState(
      state: AppInitState.initializing,
    );
  }
  
  /// Initialize app with cache-first strategy
  Future<void> _initialize() async {
    final operationId = ++_operationId;
    final stopwatch = Stopwatch()..start();
    
    try {
      // Get app version for cache invalidation
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      
      // Initialize cache manager
      _cacheManager ??= await InitCacheManagerProvider.getInstance();
      
      // Get auth state
      final auth = ref.read(authProvider);
      final userId = auth.isEmpty ? null : auth.uid;
      
      debugPrint('🚀 [InitV2] Starting initialization (user: $userId, version: $_appVersion)');
      
      // If not authenticated, mark as initialized immediately
      if (userId == null) {
        debugPrint('👋 [InitV2] No authenticated user, skipping data load');
        stopwatch.stop();
        state = state.copyWith(
          state: AppInitState.initialized,
          lastInitDuration: stopwatch.elapsed,
        );
        return;
      }
      
      // STEP 1: Try to load from cache first (instant UI)
      final cachedData = _cacheManager?.load(_appVersion!);
      if (cachedData != null && _operationId == operationId) {
        try {
          final initData = InitData.fromJson(cachedData).copyWith(
            isFromCache: true,
          );
          
          state = state.copyWith(
            state: AppInitState.initialized,
            data: initData,
            clearError: true,
          );
          
          debugPrint('✅ [InitV2] Loaded from cache (${stopwatch.elapsedMilliseconds}ms)');
          debugPrint('📊 [InitV2] Cache age: ${_cacheManager?.getCacheAge()?.toStringAsFixed(1)}h');
        } catch (e) {
          debugPrint('⚠️ [InitV2] Failed to parse cached data: $e');
          // Continue to fresh fetch if cache is corrupted
        }
      } else {
        debugPrint('📭 [InitV2] No valid cache found, will fetch fresh data');
      }
      
      // STEP 2: Fetch fresh data in background
      await _fetchFreshData(userId, operationId, stopwatch);
      
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      if (_operationId != operationId) {
        debugPrint('⚠️ [InitV2] Operation $operationId superseded during init');
        return;
      }
      
      _recordError(e, stackTrace, stopwatch.elapsed);
      debugPrint('❌ [InitV2] Initialization failed: $e');
    }
  }
  
  /// Fetch fresh data from backend
  Future<void> _fetchFreshData(String userId, int operationId, Stopwatch stopwatch) async {
    try {
      debugPrint('🌐 [InitV2] Fetching fresh data from backend...');
      final fetchStopwatch = Stopwatch()..start();
      
      // Single optimized RPC call for all init data
      final response = await supabase
          .rpc('initialize_app_v2', params: {'p_user_id': userId})
          .timeout(const Duration(seconds: 10));
      
      fetchStopwatch.stop();
      debugPrint('✅ [InitV2] Backend responded in ${fetchStopwatch.elapsedMilliseconds}ms');
      
      if (_operationId != operationId) {
        debugPrint('⚠️ [InitV2] Operation $operationId superseded after fetch');
        return;
      }
      
      if (response == null) {
        throw Exception('Backend returned null response');
      }
      
      // Parse response
      final data = response as Map<String, dynamic>;
      final initData = _parseInitData(data);
      
      // Update state with fresh data
      stopwatch.stop();
      state = state.copyWith(
        state: AppInitState.initialized,
        data: initData,
        lastInitDuration: stopwatch.elapsed,
        clearError: true,
      );
      
      debugPrint('✅ [InitV2] Initialization complete (${stopwatch.elapsedMilliseconds}ms total)');
      debugPrint('📊 [InitV2] User: ${initData.user?.phoneE164}, Subscription: ${initData.subscription?.plan}, Households: ${initData.households.length}');
      
      // Save to cache for next startup
      if (_cacheManager != null && _appVersion != null) {
        unawaited(_cacheManager!.save(initData.toJson(), _appVersion!));
      }
      
      // Record metrics
      _recordSuccessMetrics(stopwatch.elapsed, initData);

      debugPrint('🏠 [InitV2] Loading households and initializing selected household...');
      await ref.read(userHouseholdsProvider(userId).notifier).load();
      final householdsState = ref.read(userHouseholdsProvider(userId));
      final households = householdsState.value ?? const <Household>[];
      if (households.isEmpty) {
        debugPrint('📭 [InitV2] No households found for user after init');
        return;
      }

      await ref
          .read(selectedHouseholdProvider.notifier)
          .initialize(preloadedHouseholds: households);
      debugPrint('✅ [InitV2] Selected household initialized during app init');

      debugPrint('📊 [InitV2] Loading analytics data...');
      final analyticsStopwatch = Stopwatch()..start();
      await ref.read(analyticsProvider.notifier).loadData(userId);
      analyticsStopwatch.stop();
      debugPrint('✅ [InitV2] Analytics loaded in ${analyticsStopwatch.elapsedMilliseconds}ms');
      
    } on TimeoutException {
      stopwatch.stop();
      
      if (_operationId != operationId) return;
      
      // If we have cached data, just log the timeout and continue with cache
      if (state.data != null) {
        debugPrint('⚠️ [InitV2] Fresh fetch timed out, continuing with cached data');
        _recordTimeoutWithCache(stopwatch.elapsed);
        return;
      }
      
      // No cached data - this is a critical error
      final error = Exception('Failed to load app data: Request timed out after 10s');
      _recordError(error, StackTrace.current, stopwatch.elapsed);
      debugPrint('❌ [InitV2] Critical: Fresh fetch timed out with no cache fallback');
      
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      if (_operationId != operationId) return;
      
      // If we have cached data, log error but continue with cache
      if (state.data != null) {
        debugPrint('⚠️ [InitV2] Fresh fetch failed, continuing with cached data: $e');
        _recordFetchErrorWithCache(e, stopwatch.elapsed);
        return;
      }
      
      // No cached data - this is a critical error
      _recordError(e, stackTrace, stopwatch.elapsed);
      debugPrint('❌ [InitV2] Critical: Fresh fetch failed with no cache fallback: $e');
    }
  }
  
  /// Parse backend response into InitData
  InitData _parseInitData(Map<String, dynamic> data) {
    final userJson = data['user_contact'] as Map<String, dynamic>?;
    final subscriptionJson = data['subscription'] as Map<String, dynamic>?;
    final whatsappJson = data['whatsapp_binding'] as Map<String, dynamic>?;
    final householdsJson = data['households'] as List<dynamic>?;
    
    return InitData(
      user: userJson != null ? UserContact.fromJson(userJson) : null,
      subscription: subscriptionJson != null ? Subscription.fromJson(subscriptionJson) : null,
      whatsappBinding: whatsappJson != null ? WhatsAppBinding.fromJson(whatsappJson) : null,
      households: householdsJson
          ?.map((h) => Household.fromJson(h as Map<String, dynamic>))
          .toList() ?? [],
      isFromCache: false,
      timestamp: DateTime.now(),
    );
  }
  
  /// Record error state
  void _recordError(Object error, StackTrace stackTrace, Duration duration) {
    final exception = error is Exception ? error : Exception(error.toString());
    final message = 'App initialization failed: $error';
    
    state = state.copyWith(
      state: AppInitState.failed,
      error: exception,
      errorMessage: message,
      errorStackTrace: stackTrace,
      lastInitDuration: duration,
    );
    
    // Log to Crashlytics
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: false,
        reason: 'app_init_v2_failed',
      );
      FirebaseCrashlytics.instance.setCustomKey('init_duration_ms', duration.inMilliseconds);
      FirebaseCrashlytics.instance.setCustomKey('had_cache', state.data != null);
    } catch (_) {}
  }
  
  /// Record success metrics
  void _recordSuccessMetrics(Duration duration, InitData data) {
    try {
      FirebaseCrashlytics.instance.setCustomKey('init_success', true);
      FirebaseCrashlytics.instance.setCustomKey('init_duration_ms', duration.inMilliseconds);
      FirebaseCrashlytics.instance.setCustomKey('init_households_count', data.households.length);
      FirebaseCrashlytics.instance.setCustomKey('init_has_subscription', data.subscription != null);
    } catch (_) {}
  }
  
  /// Record timeout with cache fallback
  void _recordTimeoutWithCache(Duration duration) {
    try {
      FirebaseCrashlytics.instance.log('Init fetch timed out but had cache fallback');
      FirebaseCrashlytics.instance.setCustomKey('init_timeout_with_cache', true);
      FirebaseCrashlytics.instance.setCustomKey('init_duration_ms', duration.inMilliseconds);
    } catch (_) {}
  }
  
  /// Record fetch error with cache fallback
  void _recordFetchErrorWithCache(Object error, Duration duration) {
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        StackTrace.current,
        fatal: false,
        reason: 'init_fetch_error_with_cache',
      );
      FirebaseCrashlytics.instance.setCustomKey('init_duration_ms', duration.inMilliseconds);
    } catch (_) {}
  }
  
  /// Reset and re-initialize (e.g., after login/logout)
  void reset() {
    debugPrint('🔄 [InitV2] Resetting initialization');
    _operationId++;
    state = const AppInitializationState(state: AppInitState.initializing);
    _initialize();
  }
  
  /// Clear cache and re-initialize
  Future<void> clearCacheAndReset() async {
    debugPrint('🗑️ [InitV2] Clearing cache and resetting');
    await _cacheManager?.clear();
    reset();
  }
  
  /// Clear cache on logout
  Future<void> onLogout() async {
    debugPrint('👋 [InitV2] User logged out, clearing cache');
    await _cacheManager?.clear();
    _operationId++;
    state = const AppInitializationState(state: AppInitState.uninitialized);
  }
  
  /// Get cache metadata for debugging
  Map<String, dynamic> getCacheMetadata() {
    return _cacheManager?.getMetadata() ?? {
      'exists': false,
      'error': 'Cache manager not initialized',
    };
  }
  
  /// Get the last initialization exception (for ErrorPage)
  Exception? get lastInitException => state.error;
  
  /// Get the last initialization error message (for ErrorPage)
  String? get lastErrorMessage => state.errorMessage;
  
  /// Get the last initialization error stack trace (for ErrorPage)
  StackTrace? get lastErrorStackTrace => state.errorStackTrace;
}
