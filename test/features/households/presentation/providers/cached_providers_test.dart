import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';

import 'package:moneko/core/monitoring/performance_monitor.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';

const _householdId = '00000000-0000-0000-0000-000000000001';

class _TestAuth extends Auth {
  _TestAuth(this.userId);
  final String userId;

  @override
  AppUser build() => AppUser(uid: userId, email: 'test@example.com');
}

class _NoNetworkRepository implements HouseholdRepository {
  @override
  Future<List<ExpenseSplitGroup>> getHouseholdSplits(
          {required String householdId, String? startDate, String? endDate}) =>
      throw StateError('No network should be used for this offline read');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingRepository implements HouseholdRepository {
  final pending = Completer<List<ExpenseSplitGroup>>();
  final dispatched = Completer<void>();
  @override
  Future<List<ExpenseSplitGroup>> getHouseholdSplits(
      {required String householdId, String? startDate, String? endDate}) {
    if (!dispatched.isCompleted) dispatched.complete();
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ExpenseEntry _expense(String id) {
  final now = DateTime(2024, 1, 1);
  return ExpenseEntry(
    id: id,
    householdId: _householdId,
    date: now,
    amountCents: 100,
    currency: 'USD',
    createdAt: now,
  );
}

ExpenseSplitGroup _splitGroup(String id, {String? expenseId}) {
  final now = DateTime(2024, 1, 1);
  return ExpenseSplitGroup(
    id: id,
    householdId: _householdId,
    expenseId: expenseId ?? 'e$id',
    payerUserId: 'u1',
    splitType: SplitType.equal,
    currency: 'USD',
    totalAmountCents: 100,
    createdAt: now,
    updatedAt: now,
    splitLines: const [],
  );
}

void main() {
  test('an actor retains its own offline split snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    const params = HouseholdSplitsParams(householdId: _householdId);
    await cacheHouseholdSplitsSnapshot(
        userId: 'user', params: params, splits: [_splitGroup('cached')]);
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(() => _TestAuth('user')),
      householdRepositoryProvider.overrideWith((ref) => _NoNetworkRepository()),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
      householdDeletedExpenseIdsProvider.overrideWith((ref, id) async => {}),
    ]);
    addTearDown(container.dispose);
    await container.read(networkReachabilityProvider.future);
    expect(
        (await container.read(householdSplitsProvider(params).future))
            .single
            .id,
        'cached');
    await clearHouseholdTransactionPersistentCacheForHousehold(_householdId);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getKeys().where((key) => key.startsWith('households:splits:v2:')),
        isEmpty);
  });

  test('an invalidated background split read cannot repopulate its cache',
      () async {
    SharedPreferences.setMockInitialValues({});
    const params = HouseholdSplitsParams(householdId: _householdId);
    await cacheHouseholdSplitsSnapshot(
        userId: 'user', params: params, splits: [_splitGroup('cached')]);
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().single;
    final payload = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
    payload['cached_at'] = DateTime(2020).toIso8601String();
    await prefs.setString(key, jsonEncode(payload));
    final repository = _PendingRepository();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(() => _TestAuth('user')),
      householdRepositoryProvider.overrideWith((ref) => repository),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(true)),
      householdDeletedExpenseIdsProvider.overrideWith((ref, id) async => {}),
    ]);
    addTearDown(container.dispose);
    await container.read(networkReachabilityProvider.future);
    expect(
        (await container.read(householdSplitsProvider(params).future))
            .single
            .id,
        'cached');
    await repository.dispatched.future;
    container.invalidate(householdSplitsProvider(params));
    await clearHouseholdTransactionPersistentCacheForHousehold(_householdId);
    repository.pending.complete([_splitGroup('late')]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(key), isNull);
  });

  test('a persisted split snapshot cannot cross an actor boundary', () async {
    SharedPreferences.setMockInitialValues({});
    const params = HouseholdSplitsParams(householdId: _householdId);
    await cacheHouseholdSplitsSnapshot(
        userId: 'first-user',
        params: params,
        splits: [_splitGroup('first-user')]);
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(() => _TestAuth('second-user')),
      householdRepositoryProvider.overrideWith((ref) => _NoNetworkRepository()),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
      householdDeletedExpenseIdsProvider.overrideWith((ref, id) async => {}),
    ]);
    addTearDown(container.dispose);
    await container.read(networkReachabilityProvider.future);
    expect(
        await container.read(householdSplitsProvider(params).future), isEmpty);
  });

  test('household deduplication cannot reuse a different actor cache',
      () async {
    for (final userId in ['first-user', 'second-user']) {
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(() => _TestAuth(userId)),
        householdExpensesProvider
            .overrideWith((ref, params) async => [_expense(userId)]),
        householdSplitsProvider
            .overrideWith((ref, params) async => [_splitGroup(userId)]),
      ]);
      addTearDown(container.dispose);
      expect(
        (await container.read(cachedHouseholdExpensesProvider(
                    const HouseholdExpensesParams(householdId: _householdId))
                .future))
            .single
            .id,
        userId,
      );
      expect(
        (await container.read(cachedHouseholdSplitsProvider(
                    const HouseholdSplitsParams(householdId: _householdId))
                .future))
            .single
            .id,
        userId,
      );
    }
  });

  test('a single deduplicated failure has no orphan error future', () async {
    final deduplicator = RequestDeduplicator<int>();
    await expectLater(
      deduplicator.deduplicate('read', () async => throw StateError('failed')),
      throwsStateError,
    );
    await Future<void>.delayed(Duration.zero);
  });

  test('invalidated failed reads settle all existing waiters', () async {
    final deduplicator = RequestDeduplicator<int>();
    final pending = Completer<int>();
    final first = deduplicator.deduplicate('read', () => pending.future);
    final second = deduplicator.deduplicate('read', () async => 999);
    final assertions = Future.wait([
      expectLater(first.timeout(const Duration(seconds: 1)), throwsStateError),
      expectLater(second.timeout(const Duration(seconds: 1)), throwsStateError),
    ]);
    deduplicator.invalidate('read');
    pending.completeError(StateError('failed'));
    await assertions;
    expect(await deduplicator.deduplicate('read', () async => 42), 42);
  });

  test('an early deletion-read error is consumed while expenses are pending',
      () async {
    final pending = Completer<List<ExpenseEntry>>();
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(() => _TestAuth('user')),
      householdExpensesProvider.overrideWith((ref, params) => pending.future),
      householdDeletedExpenseIdsProvider.overrideWith(
        (ref, householdId) async => throw StateError('deletion read failed'),
      ),
    ]);
    addTearDown(container.dispose);
    const params = HouseholdExpensesParams(householdId: _householdId);
    final assertion = expectLater(
        container.read(cachedHouseholdExpensesProvider(params).future),
        throwsStateError);
    await container.pump();
    pending.complete([]);
    await assertion;
  });

  setUp(() {
    PerformanceMonitor.reset();
    CacheInvalidator().invalidateAll();
  });

  test('cached expenses keep an unmounted base request alive until completion',
      () async {
    final pending = Completer<List<ExpenseEntry>>();
    var disposed = false;
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(() => _TestAuth('user')),
      householdExpensesProvider.overrideWith((ref, params) {
        ref.onDispose(() => disposed = true);
        return pending.future;
      }),
    ]);
    addTearDown(container.dispose);
    const params = HouseholdExpensesParams(householdId: _householdId);
    final result =
        container.read(cachedHouseholdExpensesProvider(params).future);
    await container.pump();
    expect(disposed, isFalse);
    pending.complete([_expense('loaded')]);
    expect((await result).single.id, 'loaded');
  });

  test('recognizes only missing recurring occurrence columns for fallback', () {
    expect(
      isMissingRecurringOccurrenceColumnError(
        const PostgrestException(
          message: 'column expenses.scheduled_occurrence_date does not exist',
          code: '42703',
        ),
      ),
      isTrue,
    );
    expect(
      isMissingRecurringOccurrenceColumnError(
        const PostgrestException(
          message: 'column expenses.category does not exist',
          code: '42703',
        ),
      ),
      isFalse,
    );
  });

  test(
      'cachedHouseholdExpensesProvider refreshes after invalidate even with an in-flight request',
      () async {
    final firstCompleter = Completer<List<ExpenseEntry>>();
    var fetchCount = 0;

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _TestAuth('user')),
        householdExpensesProvider.overrideWith((ref, params) async {
          fetchCount += 1;
          if (fetchCount == 1) {
            return firstCompleter.future;
          }
          return [_expense('new')];
        }),
      ],
    );
    addTearDown(container.dispose);

    const params = HouseholdExpensesParams(householdId: _householdId);
    // Start in-flight request. Suppress its error — disposing the underlying
    // provider mid-load is expected to throw.
    final future1 = container
        .read(cachedHouseholdExpensesProvider(params).future)
        .catchError((_) => <ExpenseEntry>[]);

    container
        .read(cacheInvalidatorProvider)
        .invalidateHouseholdData(_householdId);
    container.invalidate(householdExpensesProvider);
    container.invalidate(cachedHouseholdExpensesProvider);
    await Future<void>.delayed(Duration.zero);

    final result2 = await container
        .read(cachedHouseholdExpensesProvider(params).future)
        .timeout(const Duration(seconds: 1));
    expect(result2.map((e) => e.id).toList(), ['new']);

    firstCompleter.complete([_expense('old')]);
    await future1;

    final result3 =
        await container.read(cachedHouseholdExpensesProvider(params).future);
    expect(result3.map((e) => e.id).toList(), ['new']);
    expect(fetchCount, 2);
  });

  test(
      'cachedHouseholdSplitsProvider refreshes after invalidate even with an in-flight request',
      () async {
    final firstCompleter = Completer<List<ExpenseSplitGroup>>();
    var fetchCount = 0;

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _TestAuth('user')),
        householdSplitsProvider.overrideWith((ref, params) async {
          fetchCount += 1;
          if (fetchCount == 1) {
            return firstCompleter.future;
          }
          return [_splitGroup('new')];
        }),
      ],
    );
    addTearDown(container.dispose);

    const params = HouseholdSplitsParams(householdId: _householdId);
    // Start in-flight request. Suppress its error — disposing the underlying
    // provider mid-load is expected to throw.
    final future1 = container
        .read(cachedHouseholdSplitsProvider(params).future)
        .catchError((_) => <ExpenseSplitGroup>[]);

    container
        .read(cacheInvalidatorProvider)
        .invalidateHouseholdData(_householdId);
    container.invalidate(householdSplitsProvider);
    container.invalidate(cachedHouseholdSplitsProvider);
    await Future<void>.delayed(Duration.zero);

    final result2 = await container
        .read(cachedHouseholdSplitsProvider(params).future)
        .timeout(const Duration(seconds: 1));
    expect(result2.map((e) => e.id).toList(), ['new']);

    firstCompleter.complete([_splitGroup('old')]);
    await future1;

    final result3 =
        await container.read(cachedHouseholdSplitsProvider(params).future);
    expect(result3.map((e) => e.id).toList(), ['new']);
    expect(fetchCount, 2);
  });

  test(
      'cachedHouseholdSplitsProvider does not prune an optimistic split returned by its merged source',
      () async {
    final provisional = _splitGroup(
      'optimistic_split_optimistic-expense',
      expenseId: 'optimistic-expense',
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _TestAuth('user')),
        householdSplitsProvider.overrideWith((ref, params) async {
          // The base provider intentionally overlays this same provisional
          // group onto its remote/cache result.
          return [provisional];
        }),
      ],
    );
    addTearDown(container.dispose);

    const params = HouseholdSplitsParams(householdId: _householdId);
    container
        .read(householdOptimisticSplitsProvider.notifier)
        .addSplitGroup(_householdId, provisional);

    final result = await container.read(
      cachedHouseholdSplitsProvider(params).future,
    );

    expect(result, [provisional]);
    expect(
      container.read(householdOptimisticSplitsProvider)[_householdId],
      [provisional],
    );
  });

  test(
      'cachedHouseholdExpensesProvider does not prune an optimistic entry returned by its merged source',
      () async {
    final provisional = _expense('optimistic-expense');
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _TestAuth('user')),
        householdExpensesProvider.overrideWith((ref, params) async {
          // The base provider intentionally overlays this same provisional
          // entry onto its remote/cache result.
          return [provisional];
        }),
      ],
    );
    addTearDown(container.dispose);

    const params = HouseholdExpensesParams(householdId: _householdId);
    container
        .read(householdOptimisticExpensesProvider.notifier)
        .addExpense(_householdId, provisional);

    final result = await container.read(
      cachedHouseholdExpensesProvider(params).future,
    );

    expect(result, [provisional]);
    expect(
      container.read(householdOptimisticExpensesProvider)[_householdId],
      [provisional],
    );
  });

  test('cached providers exclude persisted transaction tombstones', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _TestAuth('user')),
        householdDeletedExpenseIdsProvider.overrideWith(
          (ref, householdId) async => const {'deleted-expense'},
        ),
        householdExpensesProvider.overrideWith(
          (ref, params) async => [
            _expense('kept-expense'),
            _expense('deleted-expense'),
          ],
        ),
        householdSplitsProvider.overrideWith(
          (ref, params) async => [
            _splitGroup('kept-expense', expenseId: 'kept-expense'),
            _splitGroup('deleted-expense', expenseId: 'deleted-expense'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    const expenseParams = HouseholdExpensesParams(householdId: _householdId);
    const splitParams = HouseholdSplitsParams(householdId: _householdId);
    final expenses = await container.read(
      cachedHouseholdExpensesProvider(expenseParams).future,
    );
    final splits = await container.read(
      cachedHouseholdSplitsProvider(splitParams).future,
    );

    expect(expenses.map((expense) => expense.id), ['kept-expense']);
    expect(splits.map((split) => split.expenseId), ['kept-expense']);
  });
}
