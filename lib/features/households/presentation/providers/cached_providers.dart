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
      if (DateTime.now().difference(timestamp) < cacheDuration) {
        debugPrint('✅ [CACHE HIT] Returning cached data for $key');
        return data;
      }
      _cache.remove(key);
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
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pending.remove(key);
    }
  }
  
  void invalidate(String key) {
    _cache.remove(key);
  }
  
  void invalidateAll() {
    _cache.clear();
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
    
    return _expensesDeduplicator.deduplicate(
      key,
      () => ref.read(householdExpensesProvider(params).future)
          .trackPerformance('household_expenses', details: 'household=${params.householdId}'),
    );
  },
);

/// Cached household splits provider
final cachedHouseholdSplitsProvider =
    FutureProvider.family<List<ExpenseSplitGroup>, HouseholdSplitsParams>(
  (ref, params) async {
    final key = 'splits_${params.householdId}_${params.dateRange}';
    
    return _splitsDeduplicator.deduplicate(
      key,
      () => ref.read(householdSplitsProvider(params).future)
          .trackPerformance('household_splits', details: 'household=${params.householdId}'),
    );
  },
);

/// Provider to invalidate caches when needed
final cacheInvalidatorProvider = Provider((ref) => CacheInvalidator());

class CacheInvalidator {
  void invalidateHouseholdData(String householdId) {
    debugPrint('🗑️ Invalidating cache for household $householdId');
    // Invalidate all cached keys for this household
    _expensesDeduplicator.invalidateAll();
    _splitsDeduplicator.invalidateAll();
  }
  
  void invalidateAll() {
    debugPrint('🗑️ Invalidating all caches');
    _expensesDeduplicator.invalidateAll();
    _splitsDeduplicator.invalidateAll();
  }
}
