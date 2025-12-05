import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'household_providers.dart';
import '../../../home/presentation/models/expense_entry.dart';
import '../../domain/entities/expense_split.dart';
import 'package:moneko/core/monitoring/performance_monitor.dart';

/// Request deduplication helper to prevent multiple simultaneous requests
class RequestDeduplicator<T> {
  final Map<String, Completer<T>> _pending = {};
  final Map<String, (T, DateTime)> _cache = {};
  final Duration cacheDuration;
  
  RequestDeduplicator({this.cacheDuration = const Duration(seconds: 30)});
  
  Future<T> deduplicate(
    String key,
    Future<T> Function() fetch,
  ) async {
    // Check cache first
    final cached = _cache[key];
    if (cached != null) {
      final (data, timestamp) = cached;
      final age = DateTime.now().difference(timestamp);
      if (age < cacheDuration) {
        debugPrint('✅ [CACHE HIT] Returning cached data for $key (age: ${age.inSeconds}s)');
        return data;
      }
      debugPrint('⏰ [CACHE EXPIRED] Cache expired for $key (age: ${age.inSeconds}s > ${cacheDuration.inSeconds}s)');
      _cache.remove(key);
    } else {
      debugPrint('❌ [CACHE MISS] No cache found for $key');
    }
    
    // Check if request is already pending
    final pending = _pending[key];
    if (pending != null && !pending.isCompleted) {
      debugPrint('⏳ [DEDUP] Request already pending for $key, waiting...');
      return pending.future;
    }
    
    // Start new request
    debugPrint('🔄 [FETCH] Starting new request for $key');
    final completer = Completer<T>();
    _pending[key] = completer;
    
    try {
      final result = await fetch();
      _cache[key] = (result, DateTime.now());
      debugPrint('✅ [FETCH SUCCESS] Cached result for $key');
      completer.complete(result);
      return result;
    } catch (e) {
      debugPrint('❌ [FETCH ERROR] Failed to fetch $key: $e');
      completer.completeError(e);
      rethrow;
    } finally {
      _pending.remove(key);
    }
  }
  
  void invalidate(String key) {
    final hadCache = _cache.containsKey(key);
    _cache.remove(key);
    if (hadCache) {
      debugPrint('🗑️ [INVALIDATE] Removed cache for: $key');
    }
  }
  
  void invalidateAll() {
    final count = _cache.length;
    _cache.clear();
    debugPrint('🗑️ [INVALIDATE ALL] Cleared $count cache entries');
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
    final key = 'expenses_${params.householdId}_${params.limit}_'
        '${params.startDate?.millisecondsSinceEpoch}_'
        '${params.endDate?.millisecondsSinceEpoch}';
    
    debugPrint('📊 [CACHED_EXPENSES] Provider called for key: $key');
    
    final result = await _expensesDeduplicator.deduplicate(
      key,
      () {
        debugPrint('🌐 [CACHED_EXPENSES] Fetching from base provider for: $key');
        return ref.read(householdExpensesProvider(params).future)
            .trackPerformance('household_expenses', details: 'household=${params.householdId}');
      },
    );
    
    debugPrint('✅ [CACHED_EXPENSES] Returning ${result.length} expenses for key: $key');
    return result;
  },
);

/// Cached household splits provider
final cachedHouseholdSplitsProvider =
    FutureProvider.family<List<ExpenseSplitGroup>, HouseholdSplitsParams>(
  (ref, params) async {
    final key = 'splits_${params.householdId}_${params.dateRange}';
    
    debugPrint('📊 [CACHED_SPLITS] Provider called for key: $key');
    
    final result = await _splitsDeduplicator.deduplicate(
      key,
      () {
        debugPrint('🌐 [CACHED_SPLITS] Fetching from base provider for: $key');
        return ref.read(householdSplitsProvider(params).future)
            .trackPerformance('household_splits', details: 'household=${params.householdId}');
      },
    );
    
    debugPrint('✅ [CACHED_SPLITS] Returning ${result.length} splits for key: $key');
    return result;
  },
);

/// Provider to invalidate caches when needed
final cacheInvalidatorProvider = Provider((ref) => CacheInvalidator());

class CacheInvalidator {
  void invalidateHouseholdData(String householdId) {
    debugPrint('🗑️ [CACHE_INVALIDATOR] Invalidating cache for household $householdId');
    // Invalidate all cached keys for this household
    _expensesDeduplicator.invalidateAll();
    _splitsDeduplicator.invalidateAll();
    debugPrint('✅ [CACHE_INVALIDATOR] Cache invalidated for household $householdId');
  }
  
  void invalidateAll() {
    debugPrint('🗑️ [CACHE_INVALIDATOR] Invalidating ALL caches');
    _expensesDeduplicator.invalidateAll();
    _splitsDeduplicator.invalidateAll();
    debugPrint('✅ [CACHE_INVALIDATOR] All caches invalidated');
  }
}
