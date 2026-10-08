import 'package:hooks_riverpod/hooks_riverpod.dart';

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
        return data;
      }

      _cache.remove(key);
    }

    // Check if request is already pending
    final pending = _pending[key];
    if (pending != null) {
      return pending;
    }

    // Start new request

    // Every caller observes the same future, including the initiating caller.
    // An invalidation changes cache ownership, not whether existing reads settle.
    late final Future<T> request;
    request = Future<T>.sync(fetch).then((result) {
      final isCurrent = _pending[key] == request;
      if (isCurrent) {
        _cache[key] = (result, DateTime.now());
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
    _cache.remove(key);
  }

  void invalidateAll() {
    _cache.clear();

    _pending.clear();
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
        return splitsFuture.trackPerformance('household_splits',
            details: 'household=${params.householdId}');
      },
    );
    final deletedIds = await deletedIdsFuture;

    final merged = mergeHouseholdSplits(result, optimistic)
        .where((split) => !deletedIds.contains(split.expenseId))
        .toList(growable: false);

    return merged;
  },
);

/// Provider to invalidate caches when needed
final cacheInvalidatorProvider = Provider((ref) => CacheInvalidator());

class CacheInvalidator {
  void invalidateHouseholdData(String householdId) {
    // Only invalidate cached keys for the specific household
    _expensesDeduplicator.invalidateByPrefix('expenses_${householdId}_');
    _splitsDeduplicator.invalidateByPrefix('splits_${householdId}_');
  }

  void invalidateAll() {
    _expensesDeduplicator.invalidateAll();
    _splitsDeduplicator.invalidateAll();
  }
}
