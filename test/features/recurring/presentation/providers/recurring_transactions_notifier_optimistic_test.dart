import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

RecurringTransaction _recurring(
  String id, {
  String description = 'Rent',
  String? householdId,
}) {
  final date = DateTime(2026, 1, 1);
  return RecurringTransaction(
    id: id,
    userId: 'user-1',
    date: date,
    category: 'housing',
    description: description,
    amount: 1000,
    currency: 'USD',
    ownerType: 'me',
    privacyScope: 'full',
    householdId: householdId,
    recurrenceRule: RecurrenceRule(
      frequency: 'monthly',
      anchorDate: date,
    ),
    type: 'expense',
    attachments: const [],
    createdAt: date,
  );
}

void main() {
  test('addRecurring prepends new transactions and dedupes existing ids', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier =
        container.read(recurringTransactionsProvider(null).notifier);

    notifier.addRecurring(_recurring('server-1'));
    notifier.addRecurring(_recurring('optimistic-1'));
    notifier.addRecurring(_recurring('server-1', description: 'Updated rent'));

    final transactions =
        container.read(recurringTransactionsProvider(null)).data.value!;

    expect(transactions.map((t) => t.id), ['server-1', 'optimistic-1']);
    expect(transactions.first.description, 'Updated rent');
  });

  test('replaceRecurring swaps a temporary id for a saved transaction', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier =
        container.read(recurringTransactionsProvider(null).notifier);

    notifier.addRecurring(_recurring('optimistic-1'));
    notifier.replaceRecurring(
      'optimistic-1',
      _recurring('server-1', description: 'Server rent'),
    );

    final transactions =
        container.read(recurringTransactionsProvider(null)).data.value!;

    expect(transactions.map((t) => t.id), ['server-1']);
    expect(transactions.single.description, 'Server rent');
  });

  test('removeRecurring deletes a pending transaction by id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier =
        container.read(recurringTransactionsProvider(null).notifier);

    notifier.addRecurring(_recurring('optimistic-1'));
    notifier.removeRecurring('optimistic-1');

    final transactions =
        container.read(recurringTransactionsProvider(null)).data.value!;

    expect(transactions, isEmpty);
  });

  test('local hydration preserves recurrence rules for dashboard projections',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);

    await database.replaceRecurringTransactionsForScope(
      userId: 'user-1',
      householdId: null,
      entries: [
        ExpenseEntry(
          id: 'recurring-1',
          userId: 'user-1',
          date: DateTime(2026, 1, 1),
          amountCents: 10000,
          currency: 'USD',
          category: 'housing',
          createdAt: DateTime.utc(2026, 1, 1),
          rawText: 'Rent',
          type: 'expense',
          isRecurring: true,
          recurrenceRuleJson: const {
            'frequency': 'monthly',
            'anchor_date': '2026-01-01',
          },
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWith((ref) async => database),
        networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(networkReachabilityProvider.future);
    await container
        .read(recurringTransactionsProvider(null).notifier)
        .loadRecurringTransactions('user-1');

    final recurring =
        container.read(recurringTransactionsProvider(null)).data.value!;
    final projected = projectRecurringTransactionsAsExpenseEntries(
      recurringTransactions: recurring,
      rangeStart: DateTime(2026, 5, 1),
      rangeEnd: DateTime(2026, 5, 27),
      selectedCurrency: 'USD',
    );

    expect(recurring.single.recurrenceRule?.frequency, 'monthly');
    expect(projected.map((entry) => entry.id), [
      'recurring_recurring-1_20260501',
    ]);
    expect(projected.single.amountCents, 10000);
  });

  test('local cache preserves a recurrence rule when a later upsert omits it',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);

    await database.replaceRecurringTransactionsForScope(
      userId: 'user-1',
      householdId: null,
      entries: [
        ExpenseEntry(
          id: 'recurring-1',
          userId: 'user-1',
          date: DateTime(2026, 1, 1),
          amountCents: 10000,
          currency: 'USD',
          category: 'housing',
          createdAt: DateTime.utc(2026, 1, 1),
          type: 'expense',
          isRecurring: true,
          recurrenceRuleJson: const {
            'frequency': 'monthly',
            'anchor_date': '2026-01-01',
          },
        ),
      ],
    );

    await database.upsertTransactions([
      ExpenseEntry(
        id: 'recurring-1',
        userId: 'user-1',
        date: DateTime(2026, 1, 1),
        amountCents: 10000,
        currency: 'USD',
        category: 'housing',
        createdAt: DateTime.utc(2026, 1, 1),
        type: 'expense',
        isRecurring: true,
      ),
    ]);

    final rows = await database.getRecurringTransactions(
      userId: 'user-1',
      householdId: null,
    );

    expect(rows.single.recurrenceRuleJson?['frequency'], 'monthly');
  });

  test('online local hydration rejects upgraded cache rows without rules',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);

    await database.replaceRecurringTransactionsForScope(
      userId: 'user-1',
      householdId: null,
      entries: [
        ExpenseEntry(
          id: 'recurring-1',
          userId: 'user-1',
          date: DateTime(2026, 1, 1),
          amountCents: 10000,
          currency: 'USD',
          category: 'housing',
          createdAt: DateTime.utc(2026, 1, 1),
          type: 'expense',
          isRecurring: true,
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWith((ref) async => database),
        networkReachabilityProvider.overrideWith((ref) => Stream.value(true)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(networkReachabilityProvider.future);
    await container
        .read(recurringTransactionsProvider(null).notifier)
        .loadRecurringTransactions('user-1');

    final state = container.read(recurringTransactionsProvider(null));
    expect(state.data.valueOrNull, isNull);
  });

  test('online reload repairs incomplete rows hydrated while offline',
      () async {
    final database = MonekoDatabase.inMemory();
    final network = StreamController<bool>.broadcast();
    addTearDown(database.close);
    addTearDown(network.close);

    await database.replaceRecurringTransactionsForScope(
      userId: 'user-1',
      householdId: null,
      entries: [
        ExpenseEntry(
          id: 'recurring-1',
          userId: 'user-1',
          date: DateTime(2026, 1, 1),
          amountCents: 10000,
          currency: 'USD',
          category: 'housing',
          createdAt: DateTime.utc(2026, 1, 1),
          type: 'expense',
          isRecurring: true,
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWith((ref) async => database),
        networkReachabilityProvider.overrideWith((ref) => network.stream),
      ],
    );
    addTearDown(container.dispose);

    final initialNetworkState =
        container.read(networkReachabilityProvider.future);
    network.add(false);
    await initialNetworkState;
    final notifier =
        container.read(recurringTransactionsProvider(null).notifier);
    await notifier.loadRecurringTransactions('user-1');
    expect(
      container
          .read(recurringTransactionsProvider(null))
          .data
          .valueOrNull
          ?.single
          .recurrenceRule,
      isNull,
    );

    network.add(true);
    await Future<void>.delayed(Duration.zero);
    await notifier.loadRecurringTransactions('user-1');

    final state = container.read(recurringTransactionsProvider(null));
    expect(state.data.valueOrNull, isNull);
  });
}
