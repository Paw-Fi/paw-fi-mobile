import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_database/app_database.dart';
import 'package:moneko/core/local_database/app_database_provider.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/local_recent_transactions_provider.dart';
import 'package:moneko/features/transactions/data/transaction_repository_impl.dart';
import 'package:moneko/features/transactions/domain/transaction_command.dart';

ExpenseEntry _entry({
  required String id,
  required DateTime date,
  required DateTime createdAt,
}) {
  return ExpenseEntry(
    id: id,
    date: date,
    createdAt: createdAt,
    amountCents: 100,
    currency: 'EUR',
    type: 'expense',
  );
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('localRecentTransactionsProvider streams local transaction rows',
      () async {
    final repository = TransactionRepositoryImpl(
      database: database,
      clock: () => DateTime.utc(2026, 4, 30, 12),
      idFactory: () => 'local-tx-1',
      mutationIdFactory: () => 'mutation-1',
      syncOpIdFactory: () => 'sync-op-1',
    );
    await repository.createLocalTransaction(
      CreateTransactionCommand(
        userId: 'user-1',
        householdId: null,
        walletId: null,
        type: TransactionCommandType.expense,
        amountCents: 1299,
        currency: 'EUR',
        category: 'dining',
        merchant: 'Cafe Nero',
        description: 'Lunch',
        date: DateTime.utc(2026, 4, 30),
        captureSource: TransactionCaptureSource.manual,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(container.dispose);

    final entries = await container.read(
      localRecentTransactionsProvider(
        const LocalRecentTransactionsRequest(
          userId: 'user-1',
          limit: 5,
        ),
      ).future,
    );

    expect(entries, hasLength(1));
    expect(entries.single.id, 'local-tx-1');
    expect(entries.single.amountCents, 1299);
    expect(entries.single.category, 'dining');
    expect(entries.single.merchant, 'Cafe Nero');
    expect(entries.single.date, DateTime.utc(2026, 4, 30));
    expect(entries.single.syncStatus, 'localOnly');
  });

  test('mergeRecentTransactions sorts, dedupes, and limits results', () {
    final merged = mergeRecentTransactions(
      remote: [
        _entry(
          id: 'server-1',
          date: DateTime.utc(2026, 4, 28),
          createdAt: DateTime.utc(2026, 4, 28, 10),
        ),
        _entry(
          id: 'server-2',
          date: DateTime.utc(2026, 4, 29),
          createdAt: DateTime.utc(2026, 4, 29, 10),
        ),
      ],
      local: [
        _entry(
          id: 'local-1',
          date: DateTime.utc(2026, 4, 30),
          createdAt: DateTime.utc(2026, 4, 30, 10),
        ),
        _entry(
          id: 'server-2',
          date: DateTime.utc(2026, 4, 29),
          createdAt: DateTime.utc(2026, 4, 29, 11),
        ),
      ],
      limit: 2,
    );

    expect(merged.map((entry) => entry.id), ['local-1', 'server-2']);
    expect(merged.singleWhere((entry) => entry.id == 'server-2').createdAt,
        DateTime.utc(2026, 4, 29, 11));
  });

  test('home transaction overlay exposes optimistic entries immediately', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(analyticsProvider.notifier).addOptimisticTransaction(
          ExpenseEntry(
            id: 'optimistic-ai-1',
            userId: 'user-1',
            householdId: null,
            date: DateTime.utc(2026, 4, 30),
            amountCents: 420,
            currency: 'EUR',
            category: 'coffee',
            createdAt: DateTime.utc(2026, 4, 30, 12),
            rawText: 'Flat white',
            type: 'expense',
          ),
        );

    final entries = container.read(
      homeTransactionOverlayProvider(
        const HomeTransactionOverlayRequest(
          userId: 'user-1',
          currency: 'EUR',
          startDate: '2026-04-01',
          endDate: '2026-04-30',
        ),
      ),
    );

    expect(entries, hasLength(1));
    expect(entries.single.id, 'optimistic-ai-1');
    expect(entries.single.amountCents, 420);
  });
}
