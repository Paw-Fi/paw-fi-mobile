export 'analytics_data.dart';
export 'analytics_notifier.dart';
export 'analytics_provider.dart';
export 'processing_state.dart';
export 'expense_processing_notifier.dart';
export 'expense_processing_provider.dart';
export 'period_filter_provider.dart';
export 'period_selection.dart';
export 'date_range_utils.dart';
export 'home_filter_provider.dart';
export 'bank_sync_result_provider.dart';
export 'bank_connections_provider.dart';
export 'home_card_filter_provider.dart';
export 'derived_selectors.dart';
export 'currency_transaction_counts_provider.dart';
export 'dashboard_user_context_provider.dart';
export 'transaction_edit_state.dart';
export 'transaction_edit_notifier.dart';
export 'view_mode_provider.dart';
export 'transactions_feed_provider.dart';

// Data services
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/data/services/currency_preference_service.dart';

/// Provider for currency preference service
final currencyPreferenceServiceProvider = Provider<CurrencyPreferenceService>(
  (ref) => CurrencyPreferenceService(),
);

/// Simple counter used to force widget sync when pockets configuration
/// changes (e.g. budgets or envelope category mappings). Incrementing this
/// will cause [WidgetSyncManager] to recompute widget data.
final widgetSyncVersionProvider = StateProvider<int>((ref) => 0);

/// Widget sync state management
///
/// Tracks the state of home screen widget synchronization to prevent
/// duplicate/concurrent syncs and implement circuit breaker patterns.
class WidgetSyncState {
  /// Whether a sync is currently in progress
  final bool isSyncing;

  /// Timestamp of the last successful sync
  final DateTime? lastSyncTime;

  /// Timestamp of the last sync attempt (success or failure)
  final DateTime? lastAttemptTime;

  /// Currency used by the last sync attempt.
  final String? lastAttemptedCurrency;

  /// Map of failed scope:currency combinations to their failure timestamps
  /// Used for circuit breaker pattern - skip scopes that failed recently
  final Map<String, DateTime> failedScopes;

  /// App startup timestamp for grace period logic
  final DateTime appStartTime;

  /// Number of consecutive sync failures (reset on success)
  final int consecutiveFailures;

  const WidgetSyncState({
    this.isSyncing = false,
    this.lastSyncTime,
    this.lastAttemptTime,
    this.lastAttemptedCurrency,
    this.failedScopes = const {},
    required this.appStartTime,
    this.consecutiveFailures = 0,
  });

  WidgetSyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    DateTime? lastAttemptTime,
    String? lastAttemptedCurrency,
    Map<String, DateTime>? failedScopes,
    DateTime? appStartTime,
    int? consecutiveFailures,
  }) {
    return WidgetSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastAttemptTime: lastAttemptTime ?? this.lastAttemptTime,
      lastAttemptedCurrency:
          lastAttemptedCurrency ?? this.lastAttemptedCurrency,
      failedScopes: Map.unmodifiable(failedScopes ?? this.failedScopes),
      appStartTime: appStartTime ?? this.appStartTime,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    );
  }

  /// Check if we're in the startup grace period (first 15 seconds)
  /// During this time, we suppress error logging for transient failures
  bool get isInStartupGracePeriod {
    return DateTime.now().difference(appStartTime).inSeconds < 15;
  }

  /// Minimum interval between sync attempts (30 seconds)
  static const minSyncInterval = Duration(seconds: 30);

  /// Cooldown period for failed scopes (5 minutes)
  static const failedScopeCooldown = Duration(minutes: 5);

  /// Check if enough time has passed since last sync attempt
  bool get canSync {
    if (lastAttemptTime == null) return true;
    return DateTime.now().difference(lastAttemptTime!) >= minSyncInterval;
  }

  /// Allows header currency changes to update widgets immediately while still
  /// debouncing repeated syncs for the same currency.
  bool canSyncForCurrency(String currency) {
    final normalized = currency.trim().toUpperCase();
    if (normalized.isNotEmpty && normalized != lastAttemptedCurrency) {
      return true;
    }
    return canSync;
  }

  /// Check if a specific scope is in cooldown due to recent failure
  bool isScopeInCooldown(String scopeKey) {
    final failureTime = failedScopes[scopeKey];
    if (failureTime == null) return false;
    return DateTime.now().difference(failureTime) < failedScopeCooldown;
  }
}

/// Notifier for managing widget sync state
class WidgetSyncStateNotifier extends StateNotifier<WidgetSyncState> {
  WidgetSyncStateNotifier()
      : super(WidgetSyncState(appStartTime: DateTime.now()));

  /// Mark sync as started
  void startSync({required String currency}) {
    state = state.copyWith(
      isSyncing: true,
      lastAttemptTime: DateTime.now(),
      lastAttemptedCurrency: currency.trim().toUpperCase(),
    );
  }

  /// Mark sync as completed successfully
  void completeSync() {
    state = state.copyWith(
      isSyncing: false,
      lastSyncTime: DateTime.now(),
      consecutiveFailures: 0,
    );
  }

  /// Mark sync as failed
  void failSync() {
    state = state.copyWith(
      isSyncing: false,
      consecutiveFailures: state.consecutiveFailures + 1,
    );
  }

  /// Record a failed scope for circuit breaker
  void recordScopeFailure(String scopeId, String currency) {
    final scopeKey = '$scopeId:$currency';
    state = state.copyWith(
      failedScopes: {...state.failedScopes, scopeKey: DateTime.now()},
    );
  }

  /// Clear a scope from the failure list (e.g., on manual retry)
  void clearScopeFailure(String scopeId, String currency) {
    final scopeKey = '$scopeId:$currency';
    final newFailedScopes = Map<String, DateTime>.from(state.failedScopes);
    newFailedScopes.remove(scopeKey);
    state = state.copyWith(failedScopes: newFailedScopes);
  }

  /// Clear all failed scopes (e.g., on user-initiated refresh)
  void clearAllFailures() {
    state = state.copyWith(
      failedScopes: {},
      consecutiveFailures: 0,
    );
  }

  /// Reset sync state on logout
  void reset() {
    state = WidgetSyncState(appStartTime: DateTime.now());
  }
}

/// Provider for widget sync state
final widgetSyncStateProvider =
    StateNotifierProvider<WidgetSyncStateNotifier, WidgetSyncState>((ref) {
  return WidgetSyncStateNotifier();
});
