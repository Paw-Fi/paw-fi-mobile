import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/households/data/services/shared_budget_identity.dart';

void main() {
  test('outbox identity isolates personal, household, actor and currency', () {
    String key(String type,
            {String actor = 'user-1', String currency = 'EUR'}) =>
        sharedBudgetMutationId(
            householdId: 'space-1',
            userId: actor,
            budgetType: type,
            currency: currency,
            period: 'monthly');
    expect(key('household'), isNot(key('personal')));
    expect(key('personal'), isNot(key('personal', actor: 'user-2')));
    expect(key('household'), isNot(key('household', actor: 'user-2')));
    expect(key('personal'), isNot(key('personal', currency: 'USD')));
    expect(key('personal'), key('personal', currency: 'eur'));
  });

  test('offline household and personal saves retain independent SQLite intents',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    String key(String type) => sharedBudgetMutationId(
        householdId: 'space-1',
        userId: 'user-1',
        budgetType: type,
        currency: 'EUR',
        period: 'monthly');
    Future<void> queue(String type, int amount) => database.enqueueMutation(
        clientMutationId: key(type),
        entityType: 'shared_budget',
        entityId: type,
        operation: 'save_shared_budget',
        payload: {'budgetType': type, 'amountCents': amount});
    await queue('household', 10000);
    final original = (await database.getOutboxMutations()).single;
    await queue('personal', 2000);
    await queue('household', 12000);
    expect(
        await database.markMutationSyncedIfPayloadMatches(
            clientMutationId: original.clientMutationId,
            expectedPayloadJson: original.payloadJson),
        isFalse);
    final rows = await database.getOutboxMutations();
    expect(rows, hasLength(2));
    expect(
        rows.every((row) => row.status == localMutationStatusQueued), isTrue);
    expect(
        rows
            .singleWhere((row) => row.clientMutationId == key('personal'))
            .payloadJson,
        contains('2000'));
    expect(
        rows
            .singleWhere((row) => row.clientMutationId == key('household'))
            .payloadJson,
        contains('12000'));
  });
  group('sharedBudgetIdentityFilters', () {
    test('scopes household identity to Space and household budget type', () {
      expect(
        sharedBudgetIdentityFilters(
          householdId: 'space-1',
          budgetType: null,
          userId: null,
        ),
        {
          'household_id': 'space-1',
          'budget_type': 'household',
        },
      );
    });

    test('scopes personal identity to Space, user, and personal type', () {
      expect(
        sharedBudgetIdentityFilters(
          householdId: 'space-1',
          budgetType: 'personal',
          userId: 'user-1',
        ),
        {
          'household_id': 'space-1',
          'budget_type': 'personal',
          'user_id': 'user-1',
        },
      );
    });

    test('requires an owner for personal identity', () {
      expect(
        () => sharedBudgetIdentityFilters(
          householdId: 'space-1',
          budgetType: 'personal',
          userId: null,
        ),
        throwsArgumentError,
      );
    });
  });
}
