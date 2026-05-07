import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
}
