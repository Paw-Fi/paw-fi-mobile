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
