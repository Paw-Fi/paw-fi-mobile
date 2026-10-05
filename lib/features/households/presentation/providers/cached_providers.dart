import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'household_providers.dart';
import 'household_optimistic_providers.dart';
import '../../../home/presentation/models/expense_entry.dart';
import '../../../home/presentation/state/transactions_feed_provider.dart';
import '../../domain/entities/expense_split.dart';
import '../../domain/entities/household.dart';
import '../../data/services/device_registration_service.dart';
import 'package:moneko/core/monitoring/performance_monitor.dart';
import 'package:moneko/features/auth/auth.dart';

/// Request deduplication helper to prevent multiple simultaneous requests
class RequestDeduplicator<T> {
  final Map<String, Future<T>> _pending = {};
  final Map<String, (T, DateTime)> _cache = {};
  final Duration cacheDuration;

  RequestDeduplicator({this.cacheDuration = const Duration(seconds: 30)});

  Future<T> deduplicate(
    String key,
    Future<T> Function() fetch,
  ) async {
    final now = DateTime.now();
    _cache.removeWhere(
      (_, entry) => now.difference(entry.$2) >= cacheDuration,
    );

    // Check cache first
    final cached = _cache[key];
    if (cached != null) {
      final (data, timestamp) = cached;
      final age = DateTime.now().difference(timestamp);
      if (age < cacheDuration) {
        debugPrint(
            '✅ [CACHE HIT] Returning cached data for $key (age: ${age.inSeconds}s)');
        return data;
      }
      debugPrint(
          '⏰ [CACHE EXPIRED] Cache expired for $key (age: ${age.inSeconds}s > ${cacheDuration.inSeconds}s)');
      _cache.remove(key);
    } else {
      debugPrint('❌ [CACHE MISS] No cache found for $key');
    }

    // Check if request is already pending
    final pending = _pending[key];
    if (pending != null) {
      debugPrint('⏳ [DEDUP] Request already pending for $key, waiting...');
      return pending;
    }

    // Start new request
    debugPrint('🔄 [FETCH] Starting new request for $key');
    // Every caller observes the same future, including the initiating caller.
    // An invalidation changes cache ownership, not whether existing reads settle.
    late final Future<T> request;
    request = Future<T>.sync(fetch).then((result) {
      final isCurrent = _pending[key] == request;
      if (isCurrent) {
        _cache[key] = (result, DateTime.now());
        debugPrint('✅ [FETCH SUCCESS] Cached result for $key');
      } else {
        debugPrint('⚠️ [FETCH STALE] Ignoring stale result for $key');
      }
      return result;
    }).whenComplete(() {
      if (_pending[key] == request) {
        _pending.remove(key);
      }
    });
    _pending[key] = request;
    return request;
  }

  void invalidate(String key) {
    final hadCache = _cache.containsKey(key);
    _cache.remove(key);
    final hadPending = _pending.remove(key) != null;
    if (hadCache) {
      debugPrint('🗑️ [INVALIDATE] Removed cache for: $key');
    }
    if (hadPending) {
      debugPrint('🗑️ [INVALIDATE] Dropped pending request for: $key');
    }
  }

  void invalidateAll() {
    final count = _cache.length;
    _cache.clear();
    final pendingCount = _pending.length;
    _pending.clear();
    debugPrint(
        '🗑️ [INVALIDATE ALL] Cleared $count cache entries and $pendingCount pending requests');
  }

  void invalidateByPrefix(String prefix) {
    final keysToRemove =
        _cache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
    final pendingToRemove =
        _pending.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in pendingToRemove) {
      _pending.remove(key);
    }
    if (keysToRemove.isNotEmpty || pendingToRemove.isNotEmpty) {
      debugPrint(
          '🗑️ [INVALIDATE PREFIX] Cleared ${keysToRemove.length} cache entries and ${pendingToRemove.length} pending requests for prefix: $prefix');
    }
  }
}

/// Global deduplicators for household data
final _expensesDeduplicator = RequestDeduplicator<List<ExpenseEntry>>(
  cacheDuration: const Duration(seconds: 30),
);

final _splitsDeduplicator = RequestDeduplicator<List<ExpenseSplitGroup>>(
  cacheDuration: const Duration(seconds: 30),
);

/// Cached household expenses provider
final cachedHouseholdExpensesProvider =
    FutureProvider.family<List<ExpenseEntry>, HouseholdExpensesParams>(
  (ref, params) async {
    final userId = ref.watch(authProvider.select((user) => user.uid));
    final remoteGeneration = ref.watch(
        householdRemoteMutationRefreshSignalProvider(params.householdId));
    final feedGeneration = ref.watch(transactionsFeedRefreshSignalProvider);
    if (userId.isEmpty || !isBackendHouseholdId(params.householdId)) {
      return const <ExpenseEntry>[];
    }
    final key = 'expenses_${params.householdId}_${params.limit}_'
        '${params.startDate?.millisecondsSinceEpoch}_'
        '${params.endDate?.millisecondsSinceEpoch}_'
        '${remoteGeneration}_${feedGeneration}_$userId';

    debugPrint('📊 [CACHED_EXPENSES] Provider called for key: $key');

    final optimistic = ref.watch(
      householdOptimisticExpensesProvider
          .select((state) => state[params.householdId] ?? const []),
    );
    // Keep the auto-disposed base read subscribed while its future is pending.
    final expensesFuture = ref.watch(householdExpensesProvider(params).future);
    final deletedIdsFuture = ref.watch(
      householdDeletedExpenseIdsProvider(params.householdId).future,
    );

    final result = await _expensesDeduplicator.deduplicate(
      key,
      () {
        debugPrint(
            '🌐 [CACHED_EXPENSES] Fetching from base provider for: $key');
        return expensesFuture.trackPerformance('household_expenses',
            details: 'household=${params.householdId}');
      },
    );
    final deletedIds = await deletedIdsFuture;

    final merged = mergeHouseholdExpenses(
      result.where((entry) => !entry.isRecurring).toList(growable: false),
      optimistic.where((entry) => !entry.isRecurring).toList(growable: false),
      deletedIds: deletedIds,
    );
    final deduped = <ExpenseEntry>[];
    final seen = <String>{};
    for (final entry in merged) {
      if (entry.id.isEmpty) continue;
      if (seen.add(entry.id)) {
        deduped.add(entry);
      }
    }

    debugPrint(
        '✅ [CACHED_EXPENSES] Returning ${deduped.length} expenses for key: $key');
    return deduped;
  },
);

/// Cached household splits provider
final cachedHouseholdSplitsProvider =
    FutureProvider.family<List<ExpenseSplitGroup>, HouseholdSplitsParams>(
  (ref, params) async {
    final userId = ref.watch(authProvider.select((user) => user.uid));
    final remoteGeneration = ref.watch(
        householdRemoteMutationRefreshSignalProvider(params.householdId));
    final feedGeneration = ref.watch(transactionsFeedRefreshSignalProvider);
    if (userId.isEmpty || !isBackendHouseholdId(params.householdId)) {
      return const <ExpenseSplitGroup>[];
    }
    final key = 'splits_${params.householdId}_${params.dateRange}_'
        '${remoteGeneration}_${feedGeneration}_$userId';

    debugPrint('📊 [CACHED_SPLITS] Provider called for key: $key');

    final optimistic = ref.watch(
      householdOptimisticSplitsProvider
          .select((state) => state[params.householdId] ?? const []),
    );

    final splitsFuture = ref.watch(householdSplitsProvider(params).future);
    final deletedIdsFuture = ref.watch(
      householdDeletedExpenseIdsProvider(params.householdId).future,
    );

    final result = await _splitsDeduplicator.deduplicate(
      key,
      () {
        debugPrint('🌐 [CACHED_SPLITS] Fetching from base provider for: $key');
        return splitsFuture.trackPerformance('household_splits',
            details: 'household=${params.householdId}');
      },
    );
    final deletedIds = await deletedIdsFuture;

    final merged = mergeHouseholdSplits(result, optimistic)
        .where((split) => !deletedIds.contains(split.expenseId))
        .toList(growable: false);

    debugPrint(
        '✅ [CACHED_SPLITS] Returning ${merged.length} splits for key: $key');
    return merged;
  },
);

/// Provider to invalidate caches when needed
final cacheInvalidatorProvider = Provider((ref) => CacheInvalidator());

class CacheInvalidator {
  void invalidateHouseholdData(String householdId) {
    debugPrint(
        '🗑️ [CACHE_INVALIDATOR] Invalidating cache for household $householdId');
    // Only invalidate cached keys for the specific household
    _expensesDeduplicator.invalidateByPrefix('expenses_${householdId}_');
    _splitsDeduplicator.invalidateByPrefix('splits_${householdId}_');
    debugPrint(
        '✅ [CACHE_INVALIDATOR] Cache invalidated for household $householdId');
  }

  void invalidateAll() {
    debugPrint('🗑️ [CACHE_INVALIDATOR] Invalidating ALL caches');
    _expensesDeduplicator.invalidateAll();
    _splitsDeduplicator.invalidateAll();
    debugPrint('✅ [CACHE_INVALIDATOR] All caches invalidated');
  }
}
