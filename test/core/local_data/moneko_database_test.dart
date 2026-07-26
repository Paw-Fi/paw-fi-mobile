import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

String _settlementSnapshotToken(String character) =>
    'v1:${List<String>.filled(64, character).join()}';

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

    test('persists parent recurring links for offline deduplication', () async {
      await database.upsertTransactions([
        _entry(
          id: 'actual_recurring_occurrence',
          userId: 'user_1',
          amountCents: 2500,
          date: DateTime(2026, 6, 10),
        ).copyWith(parentRecurringId: 'recurring_series_1'),
      ]);

      final rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );

      expect(rows.single.parentRecurringId, 'recurring_series_1');
    });

    test('round-trips recurring occurrence provenance through upserts',
        () async {
      final confirmedAt = DateTime.utc(2026, 6, 11, 12, 30);
      final entry = _entry(
        id: 'actual_recurring_occurrence',
        userId: 'user_1',
        amountCents: 2500,
        date: DateTime(2026, 6, 13),
      ).copyWith(
        parentRecurringId: 'recurring_series_1',
        scheduledOccurrenceDate: DateTime(2026, 6, 10),
        recurringConfirmedAt: confirmedAt,
        recurringConfirmationSource: 'manual',
      );

      await database.upsertTransactions([entry]);
      await database.upsertTransactions([
        entry.copyWith(
          recurringConfirmedAt: confirmedAt.add(const Duration(minutes: 5)),
          recurringConfirmationSource: 'reconciled',
        ),
      ]);

      final rows = await database.getTransactionsByScheduledOccurrenceRange(
        userId: 'user_1',
        householdId: null,
        parentRecurringId: 'recurring_series_1',
        startDate: DateTime(2026, 6, 10),
        endDate: DateTime(2026, 6, 10),
      );

      expect(rows, hasLength(1));
      expect(rows.single.date, DateTime(2026, 6, 13));
      expect(rows.single.scheduledOccurrenceDate, DateTime(2026, 6, 10));
      expect(
        rows.single.recurringConfirmedAt,
        confirmedAt.add(const Duration(minutes: 5)),
      );
      expect(rows.single.recurringConfirmationSource, 'reconciled');
    });

    test('migrates existing transaction caches with nullable provenance',
        () async {
      final oldDatabase = sqlite.sqlite3.openInMemory();
      oldDatabase.execute('''
        CREATE TABLE local_transactions (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          scope_key TEXT NOT NULL,
          date TEXT NOT NULL,
          amount_cents INTEGER NOT NULL,
          currency TEXT NOT NULL,
          category TEXT,
          created_at TEXT NOT NULL,
          merchant TEXT,
          raw_text TEXT,
          wallet_id TEXT,
          sync_status TEXT NOT NULL DEFAULT 'synced',
          deleted_at TEXT
        );
      ''');
      oldDatabase.execute(
        '''
        INSERT INTO local_transactions (
          id, user_id, scope_key, date, amount_cents, currency, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'legacy_recurring',
          'user_1',
          'user_1:personal',
          '2026-06-10',
          2500,
          'EUR',
          '2026-06-10T09:00:00.000Z'
        ],
      );
      oldDatabase.execute('PRAGMA user_version = 8');

      final migrated =
          MonekoDatabase.fromExistingDatabaseForTesting(oldDatabase);
      try {
        var rows = await migrated.getRecentTransactions(
          userId: 'user_1',
          householdId: null,
        );
        expect(rows, hasLength(1));
        expect(rows.single.scheduledOccurrenceDate, isNull);
        expect(rows.single.recurringConfirmedAt, isNull);
        expect(rows.single.recurringConfirmationSource, isNull);

        await migrated.upsertTransactions([
          rows.single.copyWith(
            parentRecurringId: 'recurring_series_1',
            scheduledOccurrenceDate: DateTime(2026, 6, 10),
            recurringConfirmedAt: DateTime.utc(2026, 6, 11),
            recurringConfirmationSource: 'manual',
          ),
        ]);
        rows = await migrated.getTransactionsByScheduledOccurrenceRange(
          userId: 'user_1',
          householdId: null,
          startDate: DateTime(2026, 6, 10),
          endDate: DateTime(2026, 6, 10),
        );
        expect(rows.single.recurringConfirmationSource, 'manual');
      } finally {
        await migrated.close();
      }
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

    test('local summaries apply canonical spending semantics', () async {
      final base = _entry(
        id: 'purchase',
        userId: 'user_1',
        amountCents: 2500,
        type: 'expense',
        date: DateTime(2026, 4, 3),
      );
      await database.upsertTransactions([
        base.copyWith(
          analyticsClass: 'consumer_spend',
          analyticsSpendingMultiplier: 1,
          analyticsCountsTowardIncome: false,
        ),
        base.copyWith(
          id: 'refund',
          amountCents: 500,
          type: 'income',
          analyticsClass: 'refund_or_reversal',
          analyticsSpendingMultiplier: -1,
          analyticsCountsTowardIncome: false,
        ),
        base.copyWith(
          id: 'transfer',
          amountCents: 3000,
          analyticsClass: 'transfer_out',
          analyticsSpendingMultiplier: 0,
          analyticsCountsTowardIncome: false,
        ),
        base.copyWith(
          id: 'pending',
          amountCents: 1000,
          analyticsClass: 'consumer_spend',
          analyticsIsFinal: false,
          analyticsSpendingMultiplier: 1,
          analyticsCountsTowardIncome: false,
        ),
      ]);

      final monthly = await database.getMonthlySummary(
        scopeKey: localScopeKey(userId: 'user_1', householdId: null),
        month: DateTime(2026, 4),
        currency: 'EUR',
      );
      final feed = await database.getTransactionsFeedSummary(
        const LocalTransactionsFeedQuery(
          userId: 'user_1',
          householdId: null,
          currencies: ['EUR'],
        ),
      );

      expect(monthly?.expenseCents, 2000);
      expect(monthly?.incomeCents, 0);
      expect(feed.expenseTotalCents, 2000);
      expect(feed.incomeTotalCents, 0);
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

    test('preserves client identity when replacing an optimistic transaction',
        () async {
      final optimistic = _entry(
        id: 'optimistic_1',
        userId: 'user_1',
        amountCents: 1800,
        date: DateTime(2026, 4, 5),
      );
      final saved = _entry(
        id: 'server_1',
        userId: 'user_1',
        amountCents: 1800,
        date: DateTime(2026, 4, 5),
      );

      await database.writeOptimisticTransaction(
        entry: optimistic,
        clientMutationId: 'mobile:optimistic_1',
        operation: 'create',
        payload: {'amount': 18},
      );
      await database.replaceOptimisticTransaction(
        optimisticId: optimistic.id,
        savedEntry: saved,
        clientMutationId: 'mobile:optimistic_1',
      );

      var rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );
      expect(rows.single.id, 'server_1');
      expect(rows.single.clientRecordId, 'optimistic_1');
      expect(rows.single.clientMutationId, 'mobile:optimistic_1');

      await database.upsertTransactions([saved.copyWith(amountCents: 1900)]);
      rows = await database.getRecentTransactions(
        userId: 'user_1',
        householdId: null,
        limit: 20,
      );
      expect(rows.single.amountCents, 1900);
      expect(rows.single.clientRecordId, 'optimistic_1');
      expect(rows.single.clientMutationId, 'mobile:optimistic_1');
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

    test('reclaims syncing mutations only after the bounded lease expires',
        () async {
      await database.enqueueMutation(
        clientMutationId: 'interrupted',
        entityType: 'transaction',
        entityId: 'expense_interrupted',
        operation: 'create',
        payload: {'id': 'expense_interrupted'},
      );
      await database.markMutationSyncing('interrupted');

      final syncingMutation = (await database.getOutboxMutations()).single;
      expect(syncingMutation.status, localMutationStatusSyncing);
      expect(
        await database.nextRetryableMutation(
          syncingMutation.updatedAt.add(const Duration(minutes: 9)),
        ),
        isNull,
      );

      final recovered = await database.nextRetryableMutation(
        syncingMutation.updatedAt.add(const Duration(minutes: 11)),
      );

      expect(recovered, isNotNull);
      expect(recovered!.clientMutationId, 'interrupted');
      expect(recovered.status, localMutationStatusQueued);
      expect(recovered.retryAfter, isNull);
    });

    test('pending household gate retains old and new update scopes', () async {
      final original = _entry(
        id: 'expense_move',
        userId: 'user_1',
        householdId: 'household_old',
      );
      final updated = original.copyWith(householdId: 'household_new');

      await database.upsertTransactions([original]);
      await database.writeOptimisticTransactionUpdate(
        originalEntry: original,
        updatedEntry: updated,
        clientMutationId: 'mobile:update_move',
        payload: {
          'expenseId': original.id,
          'updates': {'household_id': 'household_new'},
          'extraBody': {
            'householdId': 'household_new',
          },
        },
      );

      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_old',
        ),
        isTrue,
      );
      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_new',
        ),
        isTrue,
      );
      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_unrelated',
        ),
        isFalse,
      );

      await database.markMutationSyncing('mobile:update_move');
      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_old',
        ),
        isTrue,
      );
      await database.markMutationFailed(
        clientMutationId: 'mobile:update_move',
        error: 'offline',
        retryAfter: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_new',
        ),
        isTrue,
      );

      await database.markMutationSynced('mobile:update_move');
      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_old',
        ),
        isFalse,
      );
      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_new',
        ),
        isFalse,
      );
    });

    test('pending household gate covers queued AI input payloads', () async {
      await database.enqueueMutation(
        clientMutationId: 'mobile:ai_input_1',
        entityType: 'ai_input',
        entityId: 'ai_input_1',
        operation: 'analyze_ai_input',
        payload: {
          'userId': 'user_1',
          'householdId': 'household_ai',
          'body': {'text': 'Dinner was 20'},
        },
      );

      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_ai',
        ),
        isTrue,
      );
      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_other',
        ),
        isFalse,
      );
    });

    test('pending household gate supports legacy transaction payloads',
        () async {
      await database.writeOptimisticTransaction(
        entry: _entry(
          id: 'legacy_queued',
          userId: 'user_1',
          householdId: 'household_legacy',
        ),
        clientMutationId: 'mobile:legacy_queued',
        operation: 'create',
        payload: {'amount': 18},
      );

      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_legacy',
        ),
        isTrue,
      );
    });

    test('delete tombstones block until successfully reconciled', () async {
      final entry = _entry(
        id: 'expense_delete',
        userId: 'user_1',
        householdId: 'household_delete',
      );
      await database.upsertTransactions([entry]);
      await database.writeOptimisticTransactionDelete(
        entries: [entry],
        clientMutationId: 'mobile:delete_household',
        payload: {'expenseIds': entry.id},
      );

      expect(
        await database.getRecentTransactions(
          userId: 'user_1',
          householdId: 'household_delete',
          limit: 20,
        ),
        isEmpty,
      );
      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_delete',
        ),
        isTrue,
      );

      final deleteMutation = (await database.getOutboxMutations()).single;
      await database.markMutationCancelled(
        clientMutationId: deleteMutation.clientMutationId,
        error: 'retry limit reached',
      );
      await database.markTransactionMutationExhausted(
        mutation: deleteMutation,
      );
      expect(
        (await database.getOutboxMutations()).single.status,
        localMutationStatusCancelled,
      );
      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_delete',
        ),
        isTrue,
      );

      await database.markOptimisticTransactionDeleteSynced(
        clientMutationId: deleteMutation.clientMutationId,
      );
      expect(
        await database.hasPendingHouseholdTransactionMutations(
          'household_delete',
        ),
        isFalse,
      );
    });

    test('stores settlement attempts as immutable idempotent mutations',
        () async {
      final first = await database.enqueueHouseholdSettlementMutation(
        householdId: ' household_1 ',
        memberUserId: ' member_1 ',
        mode: 'TO_MEMBER',
        amountCents: 6611,
        currency: 'cad',
        note: '  Paid by transfer  ',
        expectedSnapshotToken: _settlementSnapshotToken('a'),
        clientMutationId: 'mobile:settlement:1',
      );
      final payload = jsonDecode(first.payloadJson) as Map<String, dynamic>;

      expect(first.entityType, localHouseholdSettlementMutationEntityType);
      expect(first.entityId, 'household_1');
      expect(first.operation, localHouseholdSettlementMutationOperation);
      expect(payload, {
        'householdId': 'household_1',
        'memberUserId': 'member_1',
        'mode': 'to_member',
        'amountCents': 6611,
        'currency': 'CAD',
        'note': 'Paid by transfer',
        'expectedSnapshotToken': _settlementSnapshotToken('a'),
        'clientMutationId': 'mobile:settlement:1',
      });

      await database.markMutationFailed(
        clientMutationId: first.clientMutationId,
        error: 'offline',
        retryAfter: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      final repeated = await database.enqueueHouseholdSettlementMutation(
        householdId: 'household_1',
        memberUserId: 'member_1',
        mode: 'to_member',
        amountCents: 6611,
        currency: 'CAD',
        note: 'Paid by transfer',
        expectedSnapshotToken: _settlementSnapshotToken('a'),
        clientMutationId: 'mobile:settlement:1',
      );

      expect(repeated.status, localMutationStatusFailed);
      expect(repeated.attemptCount, 1);
      expect(
        () => database.enqueueHouseholdSettlementMutation(
          householdId: 'household_1',
          memberUserId: 'member_1',
          mode: 'to_member',
          amountCents: 9999,
          currency: 'CAD',
          note: 'Paid by transfer',
          expectedSnapshotToken: _settlementSnapshotToken('a'),
          clientMutationId: 'mobile:settlement:1',
        ),
        throwsStateError,
      );
      expect(
        jsonDecode(
          (await database.getHouseholdSettlementMutation(
            'mobile:settlement:1',
          ))!
              .payloadJson,
        ),
        payload,
      );
    });

    test('settlement blocker filters unresolved attempts and fails closed',
        () async {
      await database.enqueueHouseholdSettlementMutation(
        householdId: 'household_1',
        memberUserId: 'member_1',
        mode: 'to_member',
        amountCents: 1000,
        currency: 'CAD',
        note: null,
        expectedSnapshotToken: _settlementSnapshotToken('a'),
        clientMutationId: 'settlement-1',
      );
      await expectLater(
        () => database.enqueueHouseholdSettlementMutation(
          householdId: 'household_1',
          memberUserId: 'member_2',
          mode: 'from_member',
          amountCents: 2000,
          currency: 'USD',
          note: null,
          expectedSnapshotToken: _settlementSnapshotToken('b'),
          clientMutationId: 'settlement-2',
        ),
        throwsStateError,
      );
      await database.enqueueHouseholdSettlementMutation(
        householdId: 'household_2',
        memberUserId: 'member_1',
        mode: 'both',
        amountCents: 3000,
        currency: 'CAD',
        note: null,
        expectedSnapshotToken: _settlementSnapshotToken('c'),
        clientMutationId: 'settlement-3',
      );

      expect(
        (await database.getPendingHouseholdSettlementMutations(
          householdId: 'household_1',
        ))
            .map((mutation) => mutation.clientMutationId),
        ['settlement-1'],
      );
      expect(
        await database.hasPendingHouseholdSettlementMutations(
          householdId: 'household_1',
          memberUserId: 'member_1',
          currency: 'cad',
        ),
        isTrue,
      );
      expect(
        await database.hasPendingHouseholdSettlementMutations(
          householdId: 'household_1',
          memberUserId: 'member_1',
          currency: 'CAD',
          excludingClientMutationId: 'settlement-1',
        ),
        isFalse,
      );

      await database.markMutationSynced('settlement-1');
      await database.enqueueHouseholdSettlementMutation(
        householdId: 'household_1',
        memberUserId: 'member_2',
        mode: 'from_member',
        amountCents: 2000,
        currency: 'USD',
        note: null,
        expectedSnapshotToken: _settlementSnapshotToken('b'),
        clientMutationId: 'settlement-2',
      );
      await database.markMutationCancelled(
        clientMutationId: 'settlement-2',
        error: 'legacy cancellation',
      );
      expect(
        await database.hasPendingHouseholdSettlementMutations(
          householdId: 'household_1',
          memberUserId: 'member_1',
          currency: 'CAD',
        ),
        isFalse,
      );
      expect(
        await database.hasPendingHouseholdSettlementMutations(
          householdId: 'household_1',
          memberUserId: 'member_2',
          currency: 'USD',
        ),
        isTrue,
      );
    });

    test('rejects settlement payloads that the server cannot accept', () async {
      expect(
        () => database.enqueueHouseholdSettlementMutation(
          householdId: 'household_1',
          memberUserId: 'member_1',
          mode: 'invalid',
          amountCents: 1,
          currency: 'CAD',
          note: null,
          expectedSnapshotToken: _settlementSnapshotToken('a'),
          clientMutationId: 'settlement-invalid-mode',
        ),
        throwsArgumentError,
      );
      expect(
        () => database.enqueueHouseholdSettlementMutation(
          householdId: 'household_1',
          memberUserId: 'member_1',
          mode: 'both',
          amountCents: 0,
          currency: 'CAD',
          note: null,
          expectedSnapshotToken: _settlementSnapshotToken('a'),
          clientMutationId: 'settlement-invalid-amount',
        ),
        throwsArgumentError,
      );
      expect(
        () => database.enqueueHouseholdSettlementMutation(
          householdId: 'household_1',
          memberUserId: 'member_1',
          mode: 'both',
          amountCents: 1,
          currency: 'CA',
          note: null,
          expectedSnapshotToken: 'bad',
          clientMutationId: 'settlement-invalid-shape',
        ),
        throwsArgumentError,
      );
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

    test('deletes category remaps locally and queues sync mutation', () async {
      await database.saveCategoryRemapPreference(
        userId: 'user_1',
        fromCategory: 'Dining',
        toCategory: 'Groceries',
        transactionType: 'expense',
        clientMutationId: 'mobile:category_remap_delete',
      );

      await database.deleteCategoryRemapPreference(
        userId: 'user_1',
        fromCategory: 'Dining',
        transactionType: 'expense',
        clientMutationId: 'mobile:category_remap_delete',
      );

      final mapped = await database.resolveCategoryRemap(
        userId: 'user_1',
        category: 'dining',
        transactionType: 'expense',
      );
      final mutations = await database.getOutboxMutations();
      final payload = jsonDecode(mutations.single.payloadJson) as Map;

      expect(mapped, isNull);
      expect(mutations.single.clientMutationId, 'mobile:category_remap_delete');
      expect(mutations.single.entityType, 'category_remap');
      expect(mutations.single.entityId, 'user_1:expense:dining');
      expect(mutations.single.operation, 'delete_category_remap');
      expect(payload['fromCategory'], 'dining');
      expect(payload['transactionType'], 'expense');
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

    test('remote category remap snapshot clears stale synced local rows',
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

      await database.replaceCategoryRemapsFromRemote(
        userId: 'user_1',
        remaps: const <LocalCategoryRemapPreference>[],
      );

      final mapped = await database.resolveCategoryRemap(
        userId: 'user_1',
        category: 'dining',
        transactionType: 'expense',
      );

      expect(mapped, isNull);
    });

    test('remote category remap snapshot preserves pending local saves',
        () async {
      await database.saveCategoryRemapPreference(
        userId: 'user_1',
        fromCategory: 'Dining',
        toCategory: 'Groceries',
        transactionType: 'expense',
        clientMutationId: 'mobile:category_remap_1',
      );

      await database.replaceCategoryRemapsFromRemote(
        userId: 'user_1',
        remaps: const <LocalCategoryRemapPreference>[],
      );

      final mapped = await database.resolveCategoryRemap(
        userId: 'user_1',
        category: 'dining',
        transactionType: 'expense',
      );

      expect(mapped, 'groceries');
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

    test('persists recurring lifecycle deletion as a distinct outbox operation',
        () async {
      final entry = _entry(
        id: 'recurring_1',
        userId: 'user_1',
        amountCents: 1200,
      );
      await database.upsertTransactions([entry]);

      await database.writeOptimisticTransactionDelete(
        entries: [entry],
        clientMutationId: 'mobile:recurring_delete_1',
        payload: {'recurringId': entry.id},
        operation: 'delete_recurring_template',
      );

      final mutations = await database.getOutboxMutations();

      expect(mutations.single.operation, 'delete_recurring_template');
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

    test('filters local feed pages and summaries by multiple currencies',
        () async {
      await database.upsertTransactions([
        _entry(
          id: 'usd-row',
          userId: 'user_1',
          currency: 'USD',
          amountCents: 1200,
          date: DateTime(2026, 4, 3),
          createdAt: DateTime.utc(2026, 4, 3, 9),
        ),
        _entry(
          id: 'eur-row',
          userId: 'user_1',
          currency: 'eur',
          amountCents: 3400,
          date: DateTime(2026, 4, 2),
          createdAt: DateTime.utc(2026, 4, 2, 9),
        ),
        _entry(
          id: 'gbp-row',
          userId: 'user_1',
          currency: 'GBP',
          amountCents: 5600,
          date: DateTime(2026, 4, 1),
          createdAt: DateTime.utc(2026, 4, 1, 9),
        ),
      ]);

      const query = LocalTransactionsFeedQuery(
        userId: 'user_1',
        householdId: null,
        currency: 'GBP',
        currencies: ['eur', 'USD'],
        type: 'expense',
      );

      final page = await database.getTransactionsFeedPage(query);
      final summary = await database.getTransactionsFeedSummary(query);

      expect(page.items.map((entry) => entry.id), ['usd-row', 'eur-row']);
      expect(summary.transactionCount, 2);
      expect(summary.expenseTotalCents, 4600);
      expect(summary.hasMultipleCurrencies, isTrue);
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

    test(
        'household changed-since lookup includes updates owned by another member',
        () async {
      final cachedAt =
          DateTime.now().toUtc().subtract(const Duration(seconds: 1));
      await database.upsertTransactions([
        _entry(
          id: 'member_expense',
          userId: 'member_user',
          householdId: 'household_1',
          amountCents: 4200,
          date: DateTime(2026, 4, 6),
        ).copyWith(updatedAt: DateTime.utc(2026, 4, 6, 12)),
      ]);

      final changed = await database.getSyncedTransactionsChangedSince(
        userId: 'owner_user',
        householdId: 'household_1',
        changedAfter: cachedAt,
      );

      expect(changed, hasLength(1));
      expect(changed.single.id, 'member_expense');
      expect(changed.single.amountCents, 4200);
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
