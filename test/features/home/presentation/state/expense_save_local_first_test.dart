import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_database/app_database.dart';
import 'package:moneko/core/sync/application/sync_queue_controller.dart';
import 'package:moneko/core/sync/data/sync_providers.dart';
import 'package:moneko/core/sync/data/sync_queue_service.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/transactions/data/transaction_providers.dart';
import 'package:moneko/features/transactions/domain/transaction_command.dart';
import 'package:moneko/features/transactions/domain/transaction_repository.dart';

class _FakeAuth extends Auth {
  _FakeAuth(this.user);

  final AppUser user;

  @override
  AppUser build() => user;

  @override
  void dispose() {}
}

class _FakeTransactionRepository implements TransactionRepository {
  final commands = <CreateTransactionCommand>[];

  @override
  Future<String> createLocalTransaction(
      CreateTransactionCommand command) async {
    commands.add(command);
    return 'local-tx-1';
  }

  @override
  Future<List<LocalTransactionRecord>> needsReviewTransactions({
    required String userId,
    String? householdId,
    int limit = 50,
  }) async {
    return const [];
  }

  @override
  Future<void> markTransactionReviewed(String transactionId) async {}

  @override
  Future<void> updateReviewCategory({
    required String transactionId,
    required String category,
  }) async {}
}

class _FakeSyncQueueProcessor implements SyncQueueProcessor {
  var callCount = 0;

  @override
  Future<SyncQueueProcessResult> processPendingOperations({
    int limit = 20,
  }) async {
    callCount += 1;
    return const SyncQueueProcessResult(
      processed: 1,
      succeeded: 1,
      failed: 0,
    );
  }
}

void main() {
  test('saveExpense writes local transaction before background sync', () async {
    final repository = _FakeTransactionRepository();
    final syncProcessor = _FakeSyncQueueProcessor();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => _FakeAuth(
            const AppUser(uid: 'user-1', email: 'user@example.com'),
          ),
        ),
        transactionRepositoryProvider.overrideWithValue(repository),
        syncConnectivityProvider.overrideWith((ref) => const Stream.empty()),
        syncQueueProcessorProvider.overrideWithValue(syncProcessor),
      ],
    );
    addTearDown(container.dispose);

    await container.read(expenseSaveNotifierProvider.notifier).saveExpense(
          expense: ParsedExpense(
            isIncome: false,
            amount: 12.99,
            category: 'dining',
            currency: 'eur',
            currencySymbol: '€',
            date: DateTime.utc(2026, 4, 30),
            description: 'Lunch',
            merchant: 'Cafe Nero',
          ),
          accountId: 'wallet-1',
          invalidateProviders: false,
        );

    expect(repository.commands, hasLength(1));
    final command = repository.commands.single;
    expect(command.userId, 'user-1');
    expect(command.walletId, 'wallet-1');
    expect(command.amountCents, 1299);
    expect(command.currency, 'eur');
    expect(command.category, 'dining');
    expect(command.merchant, 'Cafe Nero');
    expect(command.description, 'Lunch');
    expect(command.captureSource, TransactionCaptureSource.manual);
    expect(command.reviewReasons, isEmpty);

    await container.pump();
    expect(syncProcessor.callCount, 1);
    expect(
      container.read(expenseSaveNotifierProvider),
      const AsyncData<void>(null),
    );
  });

  test(
      'saveExpense records missing wallet as review instead of blocking capture',
      () async {
    final repository = _FakeTransactionRepository();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => _FakeAuth(
            const AppUser(uid: 'user-1', email: 'user@example.com'),
          ),
        ),
        transactionRepositoryProvider.overrideWithValue(repository),
        syncConnectivityProvider.overrideWith((ref) => const Stream.empty()),
        syncQueueProcessorProvider.overrideWithValue(
          _FakeSyncQueueProcessor(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(expenseSaveNotifierProvider.notifier).saveExpense(
          expense: ParsedExpense(
            isIncome: false,
            amount: 12,
            category: 'dining',
            currency: 'EUR',
            currencySymbol: '€',
            date: DateTime.utc(2026, 4, 30),
          ),
          invalidateProviders: false,
        );

    final command = repository.commands.single;
    expect(command.walletId, isNull);
    expect(command.reviewReasons, contains('missingWallet'));
  });
}
