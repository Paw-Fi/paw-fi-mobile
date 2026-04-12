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
import 'package:moneko/features/home/presentation/state/state.dart';

part 'app_initialization_provider_v2.g.dart';

String? _normalizeCurrencyCode(String? currency) {
  final normalized = currency?.trim().toUpperCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

@visibleForTesting
HomeFilterState resolveInitializedCurrencyFilterState({
  required HomeFilterState existingState,
  required String? storedCurrency,
  required String? preferredCurrency,
  required bool preferExistingState,
}) {
  if (existingState.hasExplicitCurrency) {
    return existingState;
  }

  final existingNormalized =
      _normalizeCurrencyCode(existingState.selectedCurrency);
  final storedNormalized = _normalizeCurrencyCode(storedCurrency);
  final preferredNormalized = _normalizeCurrencyCode(preferredCurrency);

  if (storedNormalized != null) {
    return HomeFilterState(
      selectedCurrency: storedNormalized,
      hasExplicitCurrency: true,
    );
  }

  if (preferExistingState && existingNormalized != null) {
    return existingState;
  }

  return HomeFilterState(
    selectedCurrency: preferredNormalized ?? existingNormalized ?? 'USD',
    hasExplicitCurrency: false,
  );
}

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
      user: json['user'] != null ? UserContact.fromJson(json['user']) : null,
      subscription: json['subscription'] != null
          ? Subscription.fromJson(json['subscription'])
          : null,
      whatsappBinding: json['whatsapp_binding'] != null
          ? WhatsAppBinding.fromJson(json['whatsapp_binding'])
          : null,
      households: (json['households'] as List<dynamic>?)
              ?.map((h) => Household.fromJson(h))
              .toList() ??
          [],
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
      errorStackTrace:
          clearError ? null : (errorStackTrace ?? this.errorStackTrace),
      lastInitDuration: lastInitDuration ?? this.lastInitDuration,
    );
  }

  /// Whether the app is fully initialized and ready for feature providers
  /// to start their work (like widget sync, analytics refresh, etc.)
  ///
  /// Returns true when:
  /// - State is initialized (not initializing or failed)
  /// - We have data available (either from cache or fresh)
  bool get isReady => state == AppInitState.initialized && data != null;

  /// Whether we have fresh (non-cached) data
  /// Use this when you need to ensure the backend data is current
  bool get hasFreshData => isReady && data?.isFromCache == false;

  /// Whether we only have cached data (backend fetch pending or failed)
  bool get hasCachedDataOnly => isReady && data?.isFromCache == true;

  /// Whether initialization failed without any fallback data
  bool get isFailedWithoutData => state == AppInitState.failed && data == null;

  /// Whether the app is still initializing
  bool get isInitializing =>
      state == AppInitState.initializing || state == AppInitState.uninitialized;
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

  int? _lastRpcAttemptsUsed;
  int? _lastRpcAttemptMs;
  int? _lastRpcTotalMs;
  String? _lastRpcLastErrorType;
  String? _lastRpcLastErrorMessage;
  bool? _lastRpcLastErrorIsNetwork;
  String? _lastRpcStartedAt;
  String? _lastRpcFinishedAt;

  static const Duration _initRpcTimeout = Duration(seconds: 10);
  static const int _initRpcMaxAttempts = 2;
  static const Duration _initRpcBaseRetryDelay = Duration(milliseconds: 600);

  @override
  AppInitializationState build() {
    _initialize();
    return const AppInitializationState(
      state: AppInitState.initializing,
    );
  }

  Future<void> _initializeSelectedCurrency(
    UserContact? user, {
    required bool preferExistingState,
  }) async {
    final existingState = ref.read(homeFilterProvider);
    final service = ref.read(currencyPreferenceServiceProvider);
    String? storedCurrency;

    try {
      final normalized =
          (await service.getSelectedCurrency())?.trim().toUpperCase();
      if (normalized != null && normalized.isNotEmpty) {
        storedCurrency = normalized;
      }
    } catch (e) {
      debugPrint('⚠️ [InitV2] Failed to load stored currency: $e');
    }

    final latestFilterState = ref.read(homeFilterProvider);
    final resolvedState = resolveInitializedCurrencyFilterState(
      existingState: existingState,
      storedCurrency: storedCurrency,
      preferredCurrency: user?.preferredCurrency,
      preferExistingState: preferExistingState,
    );

    if (latestFilterState.hasExplicitCurrency) {
      return;
    }

    if (resolvedState.selectedCurrency == latestFilterState.selectedCurrency &&
        resolvedState.hasExplicitCurrency ==
            latestFilterState.hasExplicitCurrency) {
      return;
    }

    if (resolvedState.hasExplicitCurrency) {
      ref
          .read(homeFilterProvider.notifier)
          .setSelectedCurrency(resolvedState.selectedCurrency);
      return;
    }

    final selectedCurrency = resolvedState.selectedCurrency;
    if (selectedCurrency != null && selectedCurrency.isNotEmpty) {
      ref
          .read(homeFilterProvider.notifier)
          .bootstrapSelectedCurrency(selectedCurrency);
    }
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

      debugPrint(
          '🚀 [InitV2] Starting initialization (user: ${userId != null ? 'present' : 'null'}, version: $_appVersion)');

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
      var cachedData = _cacheManager?.load(_appVersion!);
      // Best-effort fallback: if app version changed, still try using a fresh
      // cache to avoid hard failures on cold start right after updates.
      cachedData ??= _cacheManager?.loadBestEffort(_appVersion!);
      // Stale fallback: if user hasn't opened the app recently and the 24h cache
      // expired, allow a limited stale cache to avoid hard failures.
      cachedData ??= _cacheManager?.loadStaleBestEffort(_appVersion!);
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

          await _initializeSelectedCurrency(
            initData.user,
            preferExistingState: true,
          );

          ref.read(preloadedUserHouseholdsProvider(userId).notifier).state =
              initData.households;
          if (initData.households.isNotEmpty) {
            unawaited(
              ref
                  .read(selectedHouseholdProvider.notifier)
                  .initialize(preloadedHouseholds: initData.households),
            );
          }

          debugPrint(
              '✅ [InitV2] Loaded from cache (${stopwatch.elapsedMilliseconds}ms)');
          debugPrint(
              '📊 [InitV2] Cache age: ${_cacheManager?.getCacheAge()?.toStringAsFixed(1)}h');
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
  Future<void> _fetchFreshData(
      String userId, int operationId, Stopwatch stopwatch) async {
    try {
      debugPrint('🌐 [InitV2] Fetching fresh data from backend...');
      final fetchStopwatch = Stopwatch()..start();

      // Single optimized RPC call for all init data
      final response = await _initializeRpcWithRetry(userId, operationId);

      fetchStopwatch.stop();
      debugPrint(
          '✅ [InitV2] Backend responded in ${fetchStopwatch.elapsedMilliseconds}ms');

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
      await _initializeSelectedCurrency(
        initData.user,
        preferExistingState: false,
      );

      // Update state with fresh data
      stopwatch.stop();
      state = state.copyWith(
        state: AppInitState.initialized,
        data: initData,
        lastInitDuration: stopwatch.elapsed,
        clearError: true,
      );

      debugPrint(
          '✅ [InitV2] Initialization complete (${stopwatch.elapsedMilliseconds}ms total)');
      debugPrint(
          '📊 [InitV2] User: ${initData.user != null ? 'present' : 'null'}, Subscription: ${initData.subscription?.plan}, Households: ${initData.households.length}');

      // Save to cache for next startup
      if (_cacheManager != null && _appVersion != null) {
        unawaited(_cacheManager!.save(initData.toJson(), _appVersion!));
      }

      // Record metrics
      _recordSuccessMetrics(stopwatch.elapsed, initData);

      debugPrint(
          '🏠 [InitV2] Loading households and initializing selected household...');
      ref.read(preloadedUserHouseholdsProvider(userId).notifier).state =
          initData.households;
      ref
          .read(userHouseholdsProvider(userId).notifier)
          .hydrate(initData.households);
      final householdsState = ref.read(userHouseholdsProvider(userId));
      final households = initData.households;
      if (!householdsState.hasError && households.isEmpty) {
        debugPrint('📭 [InitV2] No households found for user after init');
        // Ensure scope defaults to personal when there are no spaces/accounts.
        // This prevents filtering out personal data due to a persisted household view mode.
        await ref.read(selectedHouseholdProvider.notifier).clearSelection();
        ref.read(viewModeProvider.notifier).setPersonalMode();
      } else {
        if (households.isNotEmpty) {
          final selectedState = ref.read(selectedHouseholdProvider);
          final selectedId =
              selectedState.householdId ?? selectedState.household?.id;
          final selectedStillExists = selectedId != null &&
              households.any((household) => household.id == selectedId);
          if (!selectedStillExists || selectedState.household == null) {
            await ref
                .read(selectedHouseholdProvider.notifier)
                .initialize(preloadedHouseholds: households);
            debugPrint(
                '✅ [InitV2] Selected household initialized during app init');
          } else {
            debugPrint(
                '✅ [InitV2] Selected household already valid, skipping re-init');
          }
        } else {
          debugPrint(
              '⚠️ [InitV2] Households failed to load; keeping previous scope');
        }
      }

      _warmAnalyticsDataInBackground(userId);
    } on TimeoutException {
      stopwatch.stop();

      if (_operationId != operationId) return;

      // If we have cached data, just log the timeout and continue with cache
      if (state.data != null) {
        debugPrint(
            '⚠️ [InitV2] Fresh fetch timed out, continuing with cached data');
        _recordTimeoutWithCache(stopwatch.elapsed);
        return;
      }

      // No cached data - move to failed state but don't record as Crashlytics error
      // Timeouts are common on cold start; treat as non-fatal to avoid noise.
      _setFailedState(
        Exception(
          'Failed to load app data: Request timed out after ${_initRpcTimeout.inSeconds}s'
          ' (attempt ${_lastRpcAttemptsUsed ?? _initRpcMaxAttempts}/$_initRpcMaxAttempts, total ${_lastRpcTotalMs ?? stopwatch.elapsedMilliseconds}ms)',
        ),
        StackTrace.current,
        stopwatch.elapsed,
      );
      debugPrint(
          '❌ [InitV2] Critical: Fresh fetch timed out with no cache fallback');
    } catch (e, stackTrace) {
      stopwatch.stop();

      if (_operationId != operationId) return;

      // If we have cached data, log error but continue with cache
      if (state.data != null) {
        debugPrint(
            '⚠️ [InitV2] Fresh fetch failed, continuing with cached data: $e');
        _recordFetchErrorWithCache(e, stopwatch.elapsed);
        return;
      }

      // No cached data - move to failed state but avoid Crashlytics for network errors
      if (_isNetworkError(e)) {
        _setFailedState(e, stackTrace, stopwatch.elapsed);
        debugPrint(
            '❌ [InitV2] Critical (network): Fresh fetch failed with no cache fallback: $e');
        return;
      }

      _recordError(e, stackTrace, stopwatch.elapsed);
      debugPrint(
          '❌ [InitV2] Critical: Fresh fetch failed with no cache fallback: $e');
    }
  }

  void _warmAnalyticsDataInBackground(String userId) {
    unawaited(Future<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (ref.read(authProvider).uid != userId) {
        return;
      }

      final analyticsState = ref.read(analyticsProvider);
      if (analyticsState.hasLoadedOnce == true || analyticsState.isLoading) {
        return;
      }

      debugPrint('📊 [InitV2] Warming analytics data in background...');
      final analyticsStopwatch = Stopwatch()..start();

      try {
        await ref.read(analyticsProvider.notifier).loadData(userId);
        analyticsStopwatch.stop();
        debugPrint(
            '✅ [InitV2] Background analytics warm-up finished in ${analyticsStopwatch.elapsedMilliseconds}ms');
      } catch (error) {
        analyticsStopwatch.stop();
        debugPrint('⚠️ [InitV2] Background analytics warm-up failed: $error');
      }
    }));
  }

  Future<dynamic> _initializeRpcWithRetry(
      String userId, int operationId) async {
    Object? lastError;

    final totalStopwatch = Stopwatch()..start();
    _lastRpcAttemptsUsed = 0;
    _lastRpcAttemptMs = null;
    _lastRpcTotalMs = null;
    _lastRpcLastErrorType = null;
    _lastRpcLastErrorMessage = null;
    _lastRpcLastErrorIsNetwork = null;
    _lastRpcStartedAt = DateTime.now().toIso8601String();
    _lastRpcFinishedAt = null;

    for (var attempt = 1; attempt <= _initRpcMaxAttempts; attempt++) {
      if (_operationId != operationId) {
        throw Exception('Init operation superseded');
      }

      try {
        if (attempt > 1) {
          debugPrint(
              '🔁 [InitV2] Retrying initialize_app_v2 (attempt $attempt/$_initRpcMaxAttempts)');
        }

        final attemptStopwatch = Stopwatch()..start();

        final response = await supabase.rpc('initialize_app_v2',
            params: {'p_user_id': userId}).timeout(_initRpcTimeout);

        attemptStopwatch.stop();
        totalStopwatch.stop();
        _lastRpcAttemptsUsed = attempt;
        _lastRpcAttemptMs = attemptStopwatch.elapsedMilliseconds;
        _lastRpcTotalMs = totalStopwatch.elapsedMilliseconds;
        _lastRpcFinishedAt = DateTime.now().toIso8601String();
        return response;
      } on TimeoutException catch (e) {
        totalStopwatch.stop();
        lastError = e;
        _lastRpcAttemptsUsed = attempt;
        _lastRpcAttemptMs = _initRpcTimeout.inMilliseconds;
        _lastRpcTotalMs = totalStopwatch.elapsedMilliseconds;
        _lastRpcLastErrorType = e.runtimeType.toString();
        _lastRpcLastErrorMessage = e.toString();
        _lastRpcLastErrorIsNetwork = true;
        _lastRpcFinishedAt = DateTime.now().toIso8601String();
        if (attempt >= _initRpcMaxAttempts) rethrow;
        totalStopwatch.start();
      } catch (e) {
        totalStopwatch.stop();
        lastError = e;
        final isNetwork = _isNetworkError(e);
        _lastRpcAttemptsUsed = attempt;
        _lastRpcTotalMs = totalStopwatch.elapsedMilliseconds;
        _lastRpcLastErrorType = e.runtimeType.toString();
        _lastRpcLastErrorMessage = e.toString();
        _lastRpcLastErrorIsNetwork = isNetwork;
        _lastRpcFinishedAt = DateTime.now().toIso8601String();
        if (!_isNetworkError(e) || attempt >= _initRpcMaxAttempts) {
          rethrow;
        }
        totalStopwatch.start();
      }

      final jitterMs =
          DateTime.now().microsecondsSinceEpoch.remainder(250); // 0..249
      final backoff = _initRpcBaseRetryDelay * (1 << (attempt - 1));
      final delay = backoff + Duration(milliseconds: jitterMs);
      debugPrint(
          '⏳ [InitV2] Waiting ${delay.inMilliseconds}ms before retry (last error: ${lastError.runtimeType})');
      await Future.delayed(delay);
    }

    // Should be unreachable, but keep a safe fallback.
    throw Exception('initialize_app_v2 failed: $lastError');
  }

  /// Parse backend response into InitData
  InitData _parseInitData(Map<String, dynamic> data) {
    final userJson = data['user_contact'] as Map<String, dynamic>?;
    final subscriptionJson = data['subscription'] as Map<String, dynamic>?;
    final whatsappJson = data['whatsapp_binding'] as Map<String, dynamic>?;
    final householdsJson = data['households'] as List<dynamic>?;

    return InitData(
      user: userJson != null ? UserContact.fromJson(userJson) : null,
      subscription: subscriptionJson != null
          ? Subscription.fromJson(subscriptionJson)
          : null,
      whatsappBinding:
          whatsappJson != null ? WhatsAppBinding.fromJson(whatsappJson) : null,
      households: householdsJson
              ?.map((h) => Household.fromJson(h as Map<String, dynamic>))
              .toList() ??
          [],
      isFromCache: false,
      timestamp: DateTime.now(),
    );
  }

  void _setFailedState(Object error, StackTrace stackTrace, Duration duration) {
    final exception = error is Exception ? error : Exception(error.toString());
    final message = 'App initialization failed: $error';

    state = state.copyWith(
      state: AppInitState.failed,
      error: exception,
      errorMessage: message,
      errorStackTrace: stackTrace,
      lastInitDuration: duration,
    );
  }

  bool _isNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('handshakeexception') ||
        message.contains('connection reset') ||
        message.contains('connection terminated') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('clientexception');
  }

  /// Record error state
  void _recordError(Object error, StackTrace stackTrace, Duration duration) {
    _setFailedState(error, stackTrace, duration);
    // Log to Crashlytics
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: false,
        reason: 'app_init_v2_failed',
      );
      FirebaseCrashlytics.instance
          .setCustomKey('init_duration_ms', duration.inMilliseconds);
      FirebaseCrashlytics.instance
          .setCustomKey('had_cache', state.data != null);
    } catch (_) {}
  }

  /// Record success metrics
  void _recordSuccessMetrics(Duration duration, InitData data) {
    try {
      FirebaseCrashlytics.instance.setCustomKey('init_success', true);
      FirebaseCrashlytics.instance
          .setCustomKey('init_duration_ms', duration.inMilliseconds);
      FirebaseCrashlytics.instance
          .setCustomKey('init_households_count', data.households.length);
      FirebaseCrashlytics.instance
          .setCustomKey('init_has_subscription', data.subscription != null);
    } catch (_) {}
  }

  /// Record timeout with cache fallback
  void _recordTimeoutWithCache(Duration duration) {
    try {
      FirebaseCrashlytics.instance
          .log('Init fetch timed out but had cache fallback');
      FirebaseCrashlytics.instance
          .setCustomKey('init_timeout_with_cache', true);
      FirebaseCrashlytics.instance
          .setCustomKey('init_duration_ms', duration.inMilliseconds);
    } catch (_) {}
  }

  /// Record fetch error with cache fallback
  void _recordFetchErrorWithCache(Object error, Duration duration) {
    try {
      if (_isNetworkError(error)) {
        FirebaseCrashlytics.instance
            .log('Init fetch network error with cache fallback');
        FirebaseCrashlytics.instance
            .setCustomKey('init_duration_ms', duration.inMilliseconds);
        return;
      }
      FirebaseCrashlytics.instance.recordError(
        error,
        StackTrace.current,
        fatal: false,
        reason: 'init_fetch_error_with_cache',
      );
      FirebaseCrashlytics.instance
          .setCustomKey('init_duration_ms', duration.inMilliseconds);
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
    return _cacheManager?.getMetadata() ??
        {
          'exists': false,
          'error': 'Cache manager not initialized',
        };
  }

  /// Debug snapshot for support screenshots.
  ///
  /// Keep this free of secrets (no tokens/headers). OK to include userId.
  Map<String, dynamic> getDebugSnapshot() {
    final auth = ref.read(authProvider);
    final userId = auth.isEmpty ? null : auth.uid;

    return {
      'provider': 'AppInitializationV2',
      'operation_id': _operationId,
      'user_id': userId,
      'app_version': _appVersion,
      'init_state': state.state.name,
      'had_data': state.data != null,
      'data_is_from_cache': state.data?.isFromCache,
      'last_init_duration_ms': state.lastInitDuration?.inMilliseconds,
      'rpc_timeout_s': _initRpcTimeout.inSeconds,
      'rpc_max_attempts': _initRpcMaxAttempts,
      'rpc_base_retry_delay_ms': _initRpcBaseRetryDelay.inMilliseconds,
      'rpc_last_started_at': _lastRpcStartedAt,
      'rpc_last_finished_at': _lastRpcFinishedAt,
      'rpc_last_attempts_used': _lastRpcAttemptsUsed,
      'rpc_last_attempt_ms': _lastRpcAttemptMs,
      'rpc_last_total_ms': _lastRpcTotalMs,
      'rpc_last_error_type': _lastRpcLastErrorType,
      'rpc_last_error_is_network': _lastRpcLastErrorIsNetwork,
      'rpc_last_error_message': _lastRpcLastErrorMessage,
      'cache': getCacheMetadata(),
      'error_type': state.error?.runtimeType.toString(),
      'error_message': state.errorMessage,
    };
  }

  /// Get the last initialization exception (for ErrorPage)
  Exception? get lastInitException => state.error;

  /// Get the last initialization error message (for ErrorPage)
  String? get lastErrorMessage => state.errorMessage;

  /// Get the last initialization error stack trace (for ErrorPage)
  StackTrace? get lastErrorStackTrace => state.errorStackTrace;
}
