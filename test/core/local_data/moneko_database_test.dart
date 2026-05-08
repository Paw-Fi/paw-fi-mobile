import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';

void main() {
  late MonekoDatabase database;

  setUp(() {
    database = MonekoDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  group('MonekoDatabase transaction cache', () {
    test('upserts transactions and keeps recent rows sorted for a scope',
        () async {
      final older = _entry(
        id: 'expense_1',
        userId: 'user_1',
        amountCents: 1200,
        date: DateTime(2026, 4, 1),
        createdAt: DateTime.utc(2026, 4, 1, 8),
      );
      final newer = _entry(
        id: 'expense_2',
        userId: 'user_1',
        amountCents: 3400,
        date: DateTime(2026, 4, 2),
        createdAt: DateTime.utc(2026, 4, 2, 8),
      );

      await database.upsertTransactions([older, newer]);
      await database.upsertTransactions([
        older.copyWith(amountCents: 1500),
      ]);

      final rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );

      expect(rows.map((entry) => entry.id), ['expense_2', 'expense_1']);
      expect(rows.last.amountCents, 1500);
    });

    test('maintains precomputed monthly summary on local writes', () async {
      await database.upsertTransactions([
        _entry(
          id: 'expense_1',
          userId: 'user_1',
          amountCents: 2500,
          type: 'expense',
          date: DateTime(2026, 4, 3),
        ),
        _entry(
          id: 'income_1',
          userId: 'user_1',
          amountCents: 9000,
          type: 'income',
          date: DateTime(2026, 4, 4),
        ),
      ]);

      final summary = await database.getMonthlySummary(
        scopeKey: localScopeKey(userId: 'user_1', householdId: null),
        month: DateTime(2026, 4),
        currency: 'EUR',
      );

      expect(summary, isNotNull);
      expect(summary!.expenseCents, 2500);
      expect(summary.incomeCents, 9000);
      expect(summary.transactionCount, 2);
    });

    test('stores optimistic write and idempotent outbox mutation together',
        () async {
      final entry = _entry(
        id: 'optimistic_1',
        userId: 'user_1',
        amountCents: 1800,
        date: DateTime(2026, 4, 5),
      );

      await database.writeOptimisticTransaction(
        entry: entry,
        clientMutationId: 'mobile:optimistic_1',
        operation: 'create',
        payload: {'amount': 18},
      );
      await database.writeOptimisticTransaction(
        entry: entry.copyWith(amountCents: 1900),
        clientMutationId: 'mobile:optimistic_1',
        operation: 'create',
        payload: {'amount': 19},
      );

      final mutations = await database.getOutboxMutations();
      final rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );

      expect(mutations, hasLength(1));
      expect(mutations.single.clientMutationId, 'mobile:optimistic_1');
      expect(jsonDecode(mutations.single.payloadJson), {'amount': 19});
      expect(rows.single.amountCents, 1900);
      expect(rows.single.id, 'optimistic_1');
    });

    test('returns only retryable outbox rows in creation order', () async {
      final now = DateTime.utc(2026, 4, 6, 12);

      await database.enqueueMutation(
        clientMutationId: 'later',
        entityType: 'transaction',
        entityId: 'expense_later',
        operation: 'create',
        payload: {'id': 'expense_later'},
        createdAt: now,
      );
      await database.markMutationFailed(
        clientMutationId: 'later',
        error: 'offline',
        retryAfter: now.add(const Duration(minutes: 5)),
      );
      await database.enqueueMutation(
        clientMutationId: 'ready',
        entityType: 'transaction',
        entityId: 'expense_ready',
        operation: 'create',
        payload: {'id': 'expense_ready'},
        createdAt: now.subtract(const Duration(minutes: 1)),
      );

      final next = await database.nextRetryableMutation(now);

      expect(next, isNotNull);
      expect(next!.clientMutationId, 'ready');
    });

    test('replaces optimistic transaction with server row and marks synced',
        () async {
      await database.writeOptimisticTransaction(
        entry: _entry(id: 'optimistic_1', userId: 'user_1'),
        clientMutationId: 'mobile:optimistic_1',
        operation: 'create',
        payload: {'id': 'optimistic_1'},
      );

      await database.replaceOptimisticTransaction(
        optimisticId: 'optimistic_1',
        savedEntry: _entry(id: 'expense_1', userId: 'user_1'),
        clientMutationId: 'mobile:optimistic_1',
      );

      final rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );
      final mutations = await database.getOutboxMutations();

      expect(rows.map((entry) => entry.id), ['expense_1']);
      expect(mutations.single.status, localMutationStatusSynced);
    });

    test('removes failed optimistic transaction and cancels mutation',
        () async {
      await database.writeOptimisticTransaction(
        entry: _entry(id: 'optimistic_1', userId: 'user_1'),
        clientMutationId: 'mobile:optimistic_1',
        operation: 'create',
        payload: {'id': 'optimistic_1'},
      );

      await database.rollbackOptimisticTransaction(
        optimisticId: 'optimistic_1',
        clientMutationId: 'mobile:optimistic_1',
        error: 'network failed',
      );

      final rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );
      final mutations = await database.getOutboxMutations();

      expect(rows, isEmpty);
      expect(mutations.single.status, localMutationStatusCancelled);
      expect(mutations.single.lastError, 'network failed');
      expect(mutations.single.retryAfter, isNull);
    });

    test('optimistic update rewrites summaries and can roll back', () async {
      final original = _entry(
        id: 'expense_1',
        userId: 'user_1',
        amountCents: 1200,
      );
      await database.upsertTransactions([original]);

      final updated = original.copyWith(
        amountCents: 1800,
        category: 'groceries',
      );

      await database.writeOptimisticTransactionUpdate(
        originalEntry: original,
        updatedEntry: updated,
        clientMutationId: 'mobile:update_1',
        payload: {
          'expenseId': original.id,
          'updates': {'amount_cents': 1800},
        },
      );

      var rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );
      var summary = await database.getMonthlySummary(
        scopeKey: localScopeKey(userId: 'user_1', householdId: null),
        month: DateTime(2026, 4),
        currency: 'EUR',
      );

      expect(rows.single.amountCents, 1800);
      expect(summary?.expenseCents, 1800);

      await database.rollbackOptimisticTransactionUpdate(
        originalEntry: original,
        clientMutationId: 'mobile:update_1',
        error: 'network failed',
      );

      rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );
      summary = await database.getMonthlySummary(
        scopeKey: localScopeKey(userId: 'user_1', householdId: null),
        month: DateTime(2026, 4),
        currency: 'EUR',
      );
      final mutations = await database.getOutboxMutations();

      expect(rows.single.amountCents, 1200);
      expect(summary?.expenseCents, 1200);
      expect(mutations.single.operation, 'update_transaction');
      expect(mutations.single.status, localMutationStatusCancelled);
    });

    test('optimistic delete removes rows and can roll back', () async {
      final entry = _entry(
        id: 'expense_1',
        userId: 'user_1',
        amountCents: 1200,
      );
      await database.upsertTransactions([entry]);

      await database.writeOptimisticTransactionDelete(
        entries: [entry],
        clientMutationId: 'mobile:delete_1',
        payload: {'expenseIds': entry.id},
      );

      var rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );
      var summary = await database.getMonthlySummary(
        scopeKey: localScopeKey(userId: 'user_1', householdId: null),
        month: DateTime(2026, 4),
        currency: 'EUR',
      );

      expect(rows, isEmpty);
      expect(summary?.expenseCents, 0);

      await database.rollbackOptimisticTransactionDelete(
        entries: [entry],
        clientMutationId: 'mobile:delete_1',
        error: 'network failed',
      );

      rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );
      summary = await database.getMonthlySummary(
        scopeKey: localScopeKey(userId: 'user_1', householdId: null),
        month: DateTime(2026, 4),
        currency: 'EUR',
      );
      final mutations = await database.getOutboxMutations();

      expect(rows.single.id, entry.id);
      expect(summary?.expenseCents, 1200);
      expect(mutations.single.operation, 'delete_transaction');
      expect(mutations.single.status, localMutationStatusCancelled);
    });

    test('stores sync cursors by entity and scope', () async {
      final cursor = DateTime.utc(2026, 4, 8, 9, 30);

      await database.setSyncCursor(
        entityName: 'mobile_delta_v1',
        scopeKey: 'user_1:all',
        cursor: cursor,
      );

      expect(
        await database.getSyncCursor(
          entityName: 'mobile_delta_v1',
          scopeKey: 'user_1:all',
        ),
        cursor,
      );
      expect(
        await database.getSyncCursor(
          entityName: 'mobile_delta_v1',
          scopeKey: 'other:all',
        ),
        isNull,
      );
    });

    test('applies server deleted ids and updates summaries', () async {
      await database.upsertTransactions([
        _entry(id: 'expense_1', userId: 'user_1', amountCents: 2500),
      ]);

      await database.deleteTransactionsByIds(['expense_1']);

      final rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );
      final summary = await database.getMonthlySummary(
        scopeKey: localScopeKey(userId: 'user_1', householdId: null),
        month: DateTime(2026, 4),
        currency: 'EUR',
      );

      expect(rows, isEmpty);
      expect(summary?.expenseCents, 0);
      expect(summary?.transactionCount, 0);
    });

    test('returns filtered transaction feed pages from local cache', () async {
      await database.upsertTransactions([
        _entry(
          id: 'coffee_new',
          userId: 'user_1',
          amountCents: 750,
          category: 'coffee',
          merchant: 'Cafe Nero',
          rawText: 'morning flat white',
          date: DateTime(2026, 4, 4),
          createdAt: DateTime.utc(2026, 4, 4, 9),
          walletId: 'wallet_1',
        ),
        _entry(
          id: 'coffee_old',
          userId: 'user_1',
          amountCents: 650,
          category: 'coffee',
          merchant: 'Cafe Nero',
          rawText: 'flat white',
          date: DateTime(2026, 4, 3),
          createdAt: DateTime.utc(2026, 4, 3, 9),
          walletId: 'wallet_1',
        ),
        _entry(
          id: 'groceries',
          userId: 'user_1',
          amountCents: 4200,
          category: 'groceries',
          merchant: 'Market',
          rawText: 'weekly shop',
          date: DateTime(2026, 4, 2),
          createdAt: DateTime.utc(2026, 4, 2, 9),
          walletId: 'wallet_2',
        ),
      ]);

      final firstPage = await database.getTransactionsFeedPage(
        LocalTransactionsFeedQuery(
          userId: 'user_1',
          householdId: null,
          currency: 'EUR',
          categories: const ['coffee'],
          accountId: 'wallet_1',
          type: 'expense',
          searchQuery: 'flat',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 30),
          pageSize: 1,
        ),
      );

      expect(firstPage.items.map((entry) => entry.id), ['coffee_new']);
      expect(firstPage.hasMore, isTrue);
      expect(firstPage.nextCursor?.id, 'coffee_new');

      final secondPage = await database.getTransactionsFeedPage(
        LocalTransactionsFeedQuery(
          userId: 'user_1',
          householdId: null,
          currency: 'EUR',
          categories: const ['coffee'],
          accountId: 'wallet_1',
          type: 'expense',
          searchQuery: 'flat',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 30),
          pageSize: 1,
          cursor: firstPage.nextCursor,
        ),
      );

      expect(secondPage.items.map((entry) => entry.id), ['coffee_old']);
      expect(secondPage.hasMore, isFalse);
    });

    test('household scope includes rows from every household member', () async {
      await database.upsertTransactions([
        _entry(
          id: 'owner_expense',
          userId: 'owner_user',
          householdId: 'household_1',
          amountCents: 1400,
          date: DateTime(2026, 4, 5),
        ),
        _entry(
          id: 'member_expense',
          userId: 'member_user',
          householdId: 'household_1',
          amountCents: 2600,
          date: DateTime(2026, 4, 6),
        ),
      ]);

      final rows = await database.getTransactionsFeedItems(
        const LocalTransactionsFeedQuery(
          userId: 'owner_user',
          householdId: 'household_1',
          currency: 'EUR',
          type: 'expense',
        ),
      );
      final summary = await database.getMonthlySummary(
        scopeKey: localScopeKey(
          userId: 'owner_user',
          householdId: 'household_1',
        ),
        month: DateTime(2026, 4),
        currency: 'EUR',
      );

      expect(rows.map((entry) => entry.id), [
        'member_expense',
        'owner_expense',
      ]);
      expect(summary?.expenseCents, 4000);
      expect(summary?.transactionCount, 2);
    });

    test('returns recurring rows from local cache for a scope', () async {
      await database.upsertTransactions([
        _entry(
          id: 'rent',
          userId: 'user_1',
          amountCents: 120000,
          date: DateTime(2026, 4, 1),
          isRecurring: true,
        ),
        _entry(
          id: 'coffee',
          userId: 'user_1',
          amountCents: 450,
          date: DateTime(2026, 4, 2),
        ),
      ]);

      final rows = await database.getRecurringTransactions(
        userId: 'user_1',
        householdId: null,
      );

      expect(rows.map((entry) => entry.id), ['rent']);
      expect(rows.single.isRecurring, isTrue);
    });

    test('replaces recurring rows for scope including empty server results',
        () async {
      await database.replaceRecurringTransactionsForScope(
        userId: 'user_1',
        householdId: null,
        entries: [
          _entry(
            id: 'rent',
            userId: 'user_1',
            amountCents: 120000,
            isRecurring: true,
          ),
        ],
      );

      var rows = await database.getRecurringTransactions(
        userId: 'user_1',
        householdId: null,
      );
      expect(rows.map((entry) => entry.id), ['rent']);

      await database.replaceRecurringTransactionsForScope(
        userId: 'user_1',
        householdId: null,
        entries: const [],
      );

      rows = await database.getRecurringTransactions(
        userId: 'user_1',
        householdId: null,
      );
      expect(rows, isEmpty);
    });

    test('builds local transaction feed summaries without fetching rows twice',
        () async {
      await database.upsertTransactions([
        _entry(
          id: 'expense_food',
          userId: 'user_1',
          amountCents: 1250,
          category: 'food',
          date: DateTime(2026, 4, 4),
        ),
        _entry(
          id: 'expense_transport',
          userId: 'user_1',
          amountCents: 800,
          category: 'transport',
          date: DateTime(2026, 5, 4),
        ),
        _entry(
          id: 'income_salary',
          userId: 'user_1',
          amountCents: 200000,
          type: 'income',
          category: 'salary',
          date: DateTime(2026, 5, 5),
        ),
      ]);

      final summary = await database.getTransactionsFeedSummary(
        const LocalTransactionsFeedQuery(
          userId: 'user_1',
          householdId: null,
          currency: 'EUR',
          type: 'all',
          intervalGranularity: 'monthly',
        ),
      );

      expect(summary.transactionCount, 3);
      expect(summary.expenseTotalCents, 2050);
      expect(summary.incomeTotalCents, 200000);
      expect(summary.categorySummaries.map((entry) => entry.category), [
        'food',
        'transport',
      ]);
      expect(summary.periodTotalsCents, {
        DateTime(2026, 4): 1250,
        DateTime(2026, 5): 800,
      });
    });
  });
}

ExpenseEntry _entry({
  required String id,
  required String userId,
  int amountCents = 1000,
  String type = 'expense',
  String? category,
  String currency = 'EUR',
  String? householdId,
  String? merchant,
  String? rawText,
  String? walletId,
  bool isRecurring = false,
  DateTime? date,
  DateTime? createdAt,
}) {
  return ExpenseEntry(
    id: id,
    userId: userId,
    householdId: householdId,
    date: date ?? DateTime(2026, 4, 1),
    amountCents: amountCents,
    currency: currency,
    category: category ?? (type == 'income' ? 'salary' : 'food'),
    createdAt: createdAt ?? DateTime.utc(2026, 4, 1, 9),
    rawText: rawText ?? 'Test row',
    merchant: merchant,
    walletId: walletId,
    type: type,
    isRecurring: isRecurring,
  );
}
