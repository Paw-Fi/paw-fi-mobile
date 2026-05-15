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

    test('stores category remaps locally and queues sync mutation', () async {
      await database.saveCategoryRemapPreference(
        userId: 'user_1',
        fromCategory: 'Dining',
        toCategory: 'Groceries',
        transactionType: 'expense',
        clientMutationId: 'mobile:category_remap_1',
        usedAt: DateTime.utc(2026, 4, 6, 12),
      );

      final mapped = await database.resolveCategoryRemap(
        userId: 'user_1',
        category: 'dining',
        transactionType: 'expense',
      );
      final mutations = await database.getOutboxMutations();
      final payload = jsonDecode(mutations.single.payloadJson) as Map;

      expect(mapped, 'groceries');
      expect(mutations.single.entityType, 'category_remap');
      expect(mutations.single.entityId, 'user_1:expense:dining');
      expect(mutations.single.operation, 'save_category_remap');
      expect(payload['fromCategory'], 'dining');
      expect(payload['toCategory'], 'groceries');
      expect(payload['transactionType'], 'expense');
      expect(payload['useCount'], 1);
    });

    test('increments local category remap use count on repeated saves',
        () async {
      await database.saveCategoryRemapPreference(
        userId: 'user_1',
        fromCategory: 'Dining',
        toCategory: 'Groceries',
        transactionType: 'expense',
        clientMutationId: 'mobile:category_remap_1',
        usedAt: DateTime.utc(2026, 4, 6, 12),
      );

      await database.saveCategoryRemapPreference(
        userId: 'user_1',
        fromCategory: 'Dining',
        toCategory: 'Food',
        transactionType: 'expense',
        clientMutationId: 'mobile:category_remap_1',
        usedAt: DateTime.utc(2026, 4, 7, 12),
      );

      final mapped = await database.resolveCategoryRemap(
        userId: 'user_1',
        category: 'DINING',
        transactionType: 'expense',
      );
      final mutations = await database.getOutboxMutations();
      final payload = jsonDecode(mutations.last.payloadJson) as Map;

      expect(mapped, 'food');
      expect(mutations, hasLength(1));
      expect(mutations.single.clientMutationId, 'mobile:category_remap_1');
      expect(payload['toCategory'], 'food');
      expect(payload['useCount'], 2);
      expect(payload['lastUsedAt'],
          DateTime.utc(2026, 4, 7, 12).toIso8601String());
    });

    test('reconciles remote category remaps without queueing mutations',
        () async {
      await database.upsertCategoryRemapsFromRemote([
        LocalCategoryRemapPreference(
          userId: 'user_1',
          transactionType: 'expense',
          fromCategory: 'Dining',
          toCategory: 'Groceries',
          useCount: 3,
          lastUsedAt: DateTime.utc(2026, 4, 8, 12),
        ),
      ]);

      final mapped = await database.resolveCategoryRemap(
        userId: 'user_1',
        category: 'dining',
        transactionType: 'expense',
      );
      final mutations = await database.getOutboxMutations();

      expect(mapped, 'groceries');
      expect(mutations, isEmpty);
    });

    test('remote category remaps do not overwrite newer local mappings',
        () async {
      await database.saveCategoryRemapPreference(
        userId: 'user_1',
        fromCategory: 'Dining',
        toCategory: 'Food',
        transactionType: 'expense',
        clientMutationId: 'mobile:category_remap_1',
        usedAt: DateTime.utc(2026, 4, 9, 12),
      );

      await database.upsertCategoryRemapsFromRemote([
        LocalCategoryRemapPreference(
          userId: 'user_1',
          transactionType: 'expense',
          fromCategory: 'Dining',
          toCategory: 'Groceries',
          useCount: 3,
          lastUsedAt: DateTime.utc(2026, 4, 8, 12),
        ),
      ]);

      final mapped = await database.resolveCategoryRemap(
        userId: 'user_1',
        category: 'dining',
        transactionType: 'expense',
      );
      final mutations = await database.getOutboxMutations();

      expect(mapped, 'food');
      expect(mutations.single.status, localMutationStatusQueued);
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

    test('remote delta cannot resurrect a pending local delete', () async {
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

      await database.upsertTransactions([
        entry.copyWith(amountCents: 9999),
      ]);

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
      expect(summary?.transactionCount, 0);
    });

    test('remote delta cannot overwrite a pending local row', () async {
      final local = _entry(
        id: 'expense_1',
        userId: 'user_1',
        amountCents: 1200,
      );
      await database.writeOptimisticTransaction(
        entry: local,
        clientMutationId: 'mobile:create_1',
        operation: 'create',
        payload: {'expenseIds': local.id},
      );

      await database.upsertTransactions([
        local.copyWith(amountCents: 9999),
      ]);

      final rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );

      expect(rows.single.amountCents, 1200);
    });

    test('stores transaction feed cache completeness by query', () async {
      const completeQuery = LocalTransactionsFeedQuery(
        userId: 'user_1',
        householdId: null,
        currency: 'EUR',
        pageSize: 60,
      );
      const otherQuery = LocalTransactionsFeedQuery(
        userId: 'user_1',
        householdId: null,
        currency: 'USD',
        pageSize: 60,
      );

      expect(
        await database.isTransactionsFeedCacheComplete(completeQuery),
        isFalse,
      );

      await database.markTransactionsFeedCacheComplete(
        completeQuery,
        isComplete: true,
      );

      expect(
        await database.isTransactionsFeedCacheComplete(completeQuery),
        isTrue,
      );
      expect(
        await database.isTransactionsFeedCacheComplete(otherQuery),
        isFalse,
      );
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

    test('reconciles hard-deleted server rows from an authoritative page',
        () async {
      await database.upsertTransactions([
        _entry(
          id: 'server_keep',
          userId: 'user_1',
          amountCents: 1500,
          date: DateTime(2026, 4, 6),
          createdAt: DateTime.utc(2026, 4, 6, 9),
        ),
        _entry(
          id: 'server_deleted',
          userId: 'user_1',
          amountCents: 2500,
          date: DateTime(2026, 4, 5),
          createdAt: DateTime.utc(2026, 4, 5, 9),
        ),
      ]);
      await database.writeOptimisticTransaction(
        entry: _entry(
          id: 'local_pending',
          userId: 'user_1',
          amountCents: 3300,
          date: DateTime(2026, 4, 7),
          createdAt: DateTime.utc(2026, 4, 7, 9),
        ),
        clientMutationId: 'mobile:local_pending',
        operation: 'create',
        payload: {'id': 'local_pending'},
      );

      await database.reconcileTransactionsFeedPage(
        query: const LocalTransactionsFeedQuery(
          userId: 'user_1',
          householdId: null,
          currency: 'EUR',
          pageSize: 60,
        ),
        authoritativeItems: [
          _entry(
            id: 'server_keep',
            userId: 'user_1',
            amountCents: 1500,
            date: DateTime(2026, 4, 6),
            createdAt: DateTime.utc(2026, 4, 6, 9),
          ),
        ],
        remoteHasMore: false,
      );

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

      expect(rows.map((entry) => entry.id), ['local_pending', 'server_keep']);
      expect(summary?.expenseCents, 4800);
      expect(summary?.transactionCount, 2);
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
