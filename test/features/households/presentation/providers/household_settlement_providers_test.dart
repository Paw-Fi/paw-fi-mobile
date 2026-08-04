import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/utils/settlement_net_calculator.dart';
import 'package:moneko/features/households/data/services/household_service.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_derived_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_optimistic_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:mocktail/mocktail.dart';

const _householdId = '00000000-0000-0000-0000-000000000001';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'me', email: 'me@example.com');
}

class _MockHouseholdService extends Mock implements HouseholdService {}

void main() {
  test('deleted expense IDs merge persisted and in-memory tombstones',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final deletedExpense = ExpenseEntry(
      id: 'persisted-delete',
      userId: 'me',
      householdId: _householdId,
      date: DateTime(2026, 7, 13),
      amountCents: 1000,
      currency: 'USD',
      createdAt: DateTime(2026, 7, 13),
      type: 'expense',
    );
    await database.writeOptimisticTransactionDelete(
      entries: [deletedExpense],
      clientMutationId: 'delete-1',
      payload: const {},
      actingUserId: 'me',
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_TestAuth.new),
        localDatabaseProvider.overrideWith((ref) async => database),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(householdOptimisticDeletedExpenseIdsProvider.notifier)
        .markDeleted(_householdId, const ['in-memory-delete']);

    final deletedIds = await container.read(
      householdDeletedExpenseIdsProvider(_householdId).future,
    );

    expect(deletedIds, {'persisted-delete', 'in-memory-delete'});
  });

  test('pairwise balance excludes locally deleted split obligations', () async {
    final container = _settlementContainer(
      splits: [
        _split('kept-expense', 2500),
        _split('deleted-expense', 10000),
      ],
      deletedExpenseIds: const {'deleted-expense'},
    );
    addTearDown(container.dispose);

    final balances = await container.read(
      householdPairwiseSettlementBalancesV2Provider(
        PairwiseSettlementBalancesParams(
          householdId: _householdId,
          currency: 'USD',
        ),
      ).future,
    );

    expect(balances.single.otherUserId, 'alex');
    expect(balances.single.splitToCents, 2500);
    expect(balances.single.netCents, 2500);
  });

  test('pairwise balance reaches zero with server settlement direction',
      () async {
    final container = _settlementContainer(
      splits: [_split('expense-1', 10000)],
      deletedExpenseIds: const {'unrelated-tombstone'},
      payments: const [
        SettlementPaymentRecord(
          payerUserId: 'alex',
          participantUserId: 'me',
          amountCents: 10000,
          currency: 'USD',
        ),
      ],
    );
    addTearDown(container.dispose);

    final balances = await container.read(
      householdPairwiseSettlementBalancesV2Provider(
        PairwiseSettlementBalancesParams(
          householdId: _householdId,
          currency: 'USD',
        ),
      ).future,
    );

    expect(balances.single.netCents, 0);
    expect(balances.single.paidToCents, 10000);
  });

  test('optimistic split updates pairwise balance before server refresh',
      () async {
    final container = _settlementContainer(
      splits: const [],
      deletedExpenseIds: const {},
    );
    addTearDown(container.dispose);
    container
        .read(householdOptimisticSplitsProvider.notifier)
        .addSplitGroup(_householdId, _split('optimistic-expense', 4000));

    final balances = await container.read(
      householdPairwiseSettlementBalancesV2Provider(
        PairwiseSettlementBalancesParams(
          householdId: _householdId,
          currency: 'USD',
        ),
      ).future,
    );

    expect(balances.single.otherUserId, 'alex');
    expect(balances.single.netCents, 4000);
  });

  test('settlement overview includes and removes pending settlement payment',
      () async {
    final container = _settlementContainer(
      splits: [_split('expense-1', 10000)],
      deletedExpenseIds: const {},
    );
    addTearDown(container.dispose);
    const pendingPayment = SettlementPaymentRecord(
      payerUserId: 'alex',
      participantUserId: 'me',
      amountCents: 4000,
      currency: 'USD',
    );

    container
        .read(optimisticSettlementPaymentsProvider.notifier)
        .addPayment(_householdId, pendingPayment);
    final overviewSubscription = container.listen(
      settlementOverviewProvider(_householdId),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(overviewSubscription.close);
    await Future.wait([
      container.read(
        cachedHouseholdSplitsProvider(
          const HouseholdSplitsParams(householdId: _householdId),
        ).future,
      ),
      container.read(householdSettlementPaymentsProvider(_householdId).future),
    ]);
    await Future<void>.delayed(Duration.zero);
    final pendingOverview = overviewSubscription.read().requireValue;
    final pendingNets = computeSettlementNets(
      splits: pendingOverview.splits,
      currentUserId: 'me',
      currencyFilter: 'USD',
      settlementPayments: pendingOverview.payments,
    );

    expect(pendingOverview.payments, contains(pendingPayment));
    expect(pendingNets['alex']!.netCents, 6000);

    container
        .read(optimisticSettlementPaymentsProvider.notifier)
        .removePayment(_householdId, pendingPayment);
    await Future<void>.delayed(Duration.zero);
    final restoredOverview = overviewSubscription.read().requireValue;
    final restoredNets = computeSettlementNets(
      splits: restoredOverview.splits,
      currentUserId: 'me',
      currencyFilter: 'USD',
      settlementPayments: restoredOverview.payments,
    );

    expect(restoredOverview.payments, isEmpty);
    expect(restoredNets['alex']!.netCents, 10000);
  });

  test(
      'settlement overview keeps confirmed data while split refresh is pending',
      () async {
    final refreshGate = Completer<List<ExpenseSplitGroup>>();
    var splitLoads = 0;
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_TestAuth.new),
        cachedHouseholdSplitsProvider.overrideWith((ref, params) async {
          splitLoads += 1;
          if (splitLoads == 1) return [_split('expense-1', 10000)];
          return refreshGate.future;
        }),
        householdSettlementPaymentsProvider.overrideWith(
          (ref, householdId) async => const <SettlementPaymentRecord>[],
        ),
        pendingHouseholdSettlementPaymentsProvider.overrideWith(
          (ref, householdId) async => const <SettlementPaymentRecord>[],
        ),
      ],
    );
    addTearDown(() {
      if (!refreshGate.isCompleted) refreshGate.complete(const []);
      container.dispose();
    });
    final subscription = container.listen(
      settlementOverviewProvider(_householdId),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(
      cachedHouseholdSplitsProvider(
        const HouseholdSplitsParams(householdId: _householdId),
      ).future,
    );
    await Future<void>.delayed(Duration.zero);
    expect(subscription.read().requireValue.splits, hasLength(1));

    container.invalidate(
      cachedHouseholdSplitsProvider(
        const HouseholdSplitsParams(householdId: _householdId),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final refreshing = subscription.read();
    expect(refreshing.hasValue, isTrue);
    expect(refreshing.requireValue.splits.single.expenseId, 'expense-1');
  });

  test('durable queued settlement is restored after a fresh provider container',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.enqueueHouseholdSettlementMutation(
      householdId: _householdId,
      memberUserId: 'alex',
      mode: 'to_member',
      amountCents: 2500,
      currency: 'USD',
      note: null,
      expectedSnapshotToken:
          'v1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      clientMutationId: 'settlement-restart-1',
    );
    final freshContainer = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_TestAuth.new),
        localDatabaseProvider.overrideWith((ref) async => database),
      ],
    );
    addTearDown(freshContainer.dispose);

    final restored = await freshContainer.read(
      pendingHouseholdSettlementPaymentsProvider(_householdId).future,
    );

    expect(restored, hasLength(1));
    expect(restored.single.payerUserId, 'me');
    expect(restored.single.participantUserId, 'alex');
    expect(restored.single.amountCents, 2500);
  });

  test('settlement overview fails closed when payment data is unavailable',
      () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_TestAuth.new),
        cachedHouseholdSplitsProvider.overrideWith(
          (ref, params) async => [_split('expense-1', 10000)],
        ),
        householdSettlementPaymentsProvider.overrideWith(
          (ref, householdId) async => throw StateError('payments unavailable'),
        ),
        pendingHouseholdSettlementPaymentsProvider.overrideWith(
          (ref, householdId) async => const <SettlementPaymentRecord>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    final failedState = Completer<AsyncValue<SettlementOverviewData>>();
    final subscription = container.listen(
      settlementOverviewProvider(_householdId),
      (_, next) {
        if (next.hasError && !failedState.isCompleted) {
          failedState.complete(next);
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final result = await failedState.future.timeout(const Duration(seconds: 1));
    expect(result.error, isA<StateError>());
  });

  test('removing a pending settlement preserves an identical newer payment',
      () {
    final notifier = OptimisticSettlementPaymentsNotifier();
    const payment = SettlementPaymentRecord(
      payerUserId: 'alex',
      participantUserId: 'me',
      amountCents: 4000,
      currency: 'USD',
    );
    notifier.addPayment(_householdId, payment);
    notifier.addPayment(_householdId, payment);

    notifier.removePayment(_householdId, payment);

    expect(notifier.state[_householdId], [payment]);
  });

  test('atomic settlement provider filters optimistic deletion tombstones',
      () async {
    final service = _MockHouseholdService();
    when(
      () => service.getSettlementCalculationV3(
        householdId: _householdId,
        memberUserId: 'alex',
        currency: 'USD',
      ),
    ).thenAnswer(
      (_) async => {
        'split_to_cents': 11223,
        'split_from_cents': 4612,
        'paid_to_cents': 0,
        'paid_from_cents': 0,
        'net_cents': 6611,
        'rows': [
          _breakdownRowJson('deleted-expense', 'you_owe', 11223),
          _breakdownRowJson('kept-expense', 'they_owe_you', 4612),
        ],
      },
    );
    final container = ProviderContainer(
      overrides: [
        householdServiceProvider.overrideWithValue(service),
        householdDeletedExpenseIdsProvider.overrideWith(
          (ref, householdId) async => const {'deleted-expense'},
        ),
      ],
    );
    addTearDown(container.dispose);

    final calculation = await container.read(
      householdSettlementCalculationV3Provider(
        SettlementBreakdownV2Params(
          householdId: _householdId,
          memberUserId: 'alex',
          currency: 'usd',
        ),
      ).future,
    );

    expect(calculation.netCents, -4612);
    expect(calculation.rows.single.expenseId, 'kept-expense');
    expect(calculation.rows.single.remainingAmountCents, 4612);
  });
}

Map<String, dynamic> _breakdownRowJson(
  String expenseId,
  String direction,
  int amountCents,
) {
  return {
    'direction': direction,
    'expense_id': expenseId,
    'split_group_id': 'group-$expenseId',
    'split_line_id': 'line-$expenseId',
    'expense_date': '2026-07-16T00:00:00.000Z',
    'expense_description': expenseId,
    'expense_category': 'Other',
    'expense_raw_text': expenseId,
    'expense_type': 'expense',
    'total_amount_cents': amountCents,
    'remaining_amount_cents': amountCents,
  };
}

ProviderContainer _settlementContainer({
  required List<ExpenseSplitGroup> splits,
  required Set<String> deletedExpenseIds,
  List<SettlementPaymentRecord> payments = const [],
}) {
  return ProviderContainer(
    overrides: [
      authProvider.overrideWith(_TestAuth.new),
      householdDeletedExpenseIdsProvider.overrideWith(
        (ref, householdId) async => deletedExpenseIds,
      ),
      cachedHouseholdSplitsProvider.overrideWith(
        (ref, params) async => splits,
      ),
      householdSettlementPaymentsProvider.overrideWith(
        (ref, householdId) async => payments,
      ),
      pendingHouseholdSettlementPaymentsProvider.overrideWith(
        (ref, householdId) async => const <SettlementPaymentRecord>[],
      ),
    ],
  );
}

ExpenseSplitGroup _split(String expenseId, int amountCents) {
  final now = DateTime(2026, 7, 13);
  return ExpenseSplitGroup(
    id: 'group-$expenseId',
    householdId: _householdId,
    expenseId: expenseId,
    payerUserId: 'alex',
    splitType: SplitType.equal,
    currency: 'USD',
    totalAmountCents: amountCents,
    createdAt: now,
    updatedAt: now,
    splitLines: [
      ExpenseSplitLine(
        id: 'line-$expenseId',
        splitGroupId: 'group-$expenseId',
        userId: 'me',
        amountCents: amountCents,
        isSettled: false,
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
}
