import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_transfer_feed_entries.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_snapshot_math.dart';
import 'package:sqlite3/sqlite3.dart';

List<ExpenseEntry> rows(String id, {int fee = 125, String? feeId}) =>
    buildWalletTransferFeedEntries(
      transferJson: {
        'id': id,
        'from_account_id': 'source',
        'to_account_id': 'target',
        'amount_cents': 10000,
        'currency': 'EUR',
        'to_amount_cents': 11000,
        'to_currency': 'USD',
        'exchange_rate': '1.1',
        'fee_amount_cents': fee,
        'fee_expense_id': feeId,
        'transfer_contract_version': 2,
        'date': '2026-10-15',
        'created_at': '2026-10-15T12:00:00Z',
        'created_by_user_id': 'user',
      },
      fallbackUserId: 'user',
    );

const query = LocalTransactionsFeedQuery(
  userId: 'user',
  householdId: null,
  currency: 'EUR',
  accountId: 'source',
);

void main() {
  test('duplicate create acknowledgement cannot overwrite newer canonical edit',
      () async {
    final db = MonekoDatabase.inMemory();
    addTearDown(db.close);
    final original = rows('optimistic-transfer-test');
    final saved = rows('canonical', feeId: 'canonical-fee');
    await db.writeOptimisticWalletTransfer(
        entries: original,
        clientMutationId: 'create',
        entityId: 'optimistic-transfer-test',
        payload: {'functionName': 'create-wallet-transfer'});
    await db.replaceOptimisticWalletTransfer(
        optimisticIds: original.map((e) => e.id),
        savedEntries: saved,
        clientMutationId: 'create');
    await db.writeOptimisticWalletTransferUpdate(
        originalEntries: saved,
        updatedEntries: rows('canonical', feeId: 'canonical-fee', fee: 200),
        clientMutationId: 'edit',
        transferId: 'canonical',
        payload: {'functionName': 'update-wallet-transfer'});
    await db.replaceOptimisticWalletTransfer(
        optimisticIds: original.map((e) => e.id),
        savedEntries: saved,
        clientMutationId: 'create');
    expect((await db.getWalletTransferFeeEntry('canonical'))?.amountCents, 200);
    await db.rollbackOptimisticWalletTransfer(
        optimisticIds: original.map((e) => e.id),
        clientMutationId: 'create',
        error: 'late failed duplicate dispatch');
    expect((await db.getOutboxMutations()).first.status,
        localMutationStatusSynced);
  });

  test('schema 13 upgrades linkage and failed grouped write commits nothing',
      () async {
    final raw = sqlite3.openInMemory();
    var db = MonekoDatabase.fromExistingDatabaseForTesting(raw);
    // Reopen a copy so the database facade can own/dispose each connection.
    final directory = await Directory.systemTemp.createTemp('fee-schema-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/local.sqlite';
    raw.execute('VACUUM INTO ?', [path]);
    await db.close();
    final legacy = sqlite3.open(path);
    legacy.execute(
        'ALTER TABLE local_transactions DROP COLUMN transfer_fee_transfer_id');
    legacy.execute('PRAGMA user_version = 13');
    legacy.dispose();
    db = MonekoDatabase.fromExistingDatabaseForTesting(sqlite3.open(path));
    addTearDown(db.close);
    final entries = rows('optimistic-transfer-test');
    await expectLater(
        db.writeOptimisticWalletTransfer(
            entries: [
              ...entries,
              ExpenseEntry(
                  id: 'invalid',
                  date: DateTime(2026),
                  amountCents: 1,
                  createdAt: DateTime(2026))
            ],
            clientMutationId: 'bad',
            entityId: 'optimistic-transfer-test',
            payload: {'functionName': 'create-wallet-transfer'}),
        throwsArgumentError);
    expect(await db.getOutboxMutations(), isEmpty);
    expect(
        await db.getWalletTransferFeeEntry('optimistic-transfer-test'), isNull);
    expect(
        await db.getTransactionByIdOrClientRecordId(entries.first.id), isNull);
    await db.writeOptimisticWalletTransfer(
        entries: entries,
        clientMutationId: 'good',
        entityId: 'optimistic-transfer-test',
        payload: {'functionName': 'create-wallet-transfer'});
    expect(
        (await db.getWalletTransferFeeEntry('optimistic-transfer-test'))
            ?.amountCents,
        125);
    expect(await db.getActiveTransactionCreateMutationIds(), contains('good'));
  });

  test('SQLite feed drives Home Pocket and native wallet projections once',
      () async {
    final db = MonekoDatabase.inMemory();
    addTearDown(db.close);
    final native = rows('optimistic-transfer-test');
    await db.writeOptimisticWalletTransfer(
        entries: native,
        clientMutationId: 'create',
        entityId: 'optimistic-transfer-test',
        payload: {'functionName': 'create-wallet-transfer'});
    final all = await db.getTransactionsFeedItems(
        const LocalTransactionsFeedQuery(
            userId: 'user', householdId: null, currencies: ['EUR', 'USD']));
    expect(await db.getRecentTransactions(userId: 'user', householdId: null),
        hasLength(3));
    final home = mergeDashboardTransactionsWithLocalOverlay(
        base: all,
        localOverlay: all,
        query: const DashboardScopeQuery(
            userId: 'user',
            householdId: null,
            selectedCurrency: 'EUR',
            selectedCurrencies: ['EUR', 'USD'],
            startDate: null,
            endDate: null));
    expect(home, hasLength(3));
    expect(home.fold<double>(0, (sum, e) => sum + e.spendingEffect), 1.25);
    const rates =
        CurrencyRateTable(baseCurrency: 'EUR', rates: {'EUR': 1, 'USD': 1.25});
    final pocket = PocketEnvelope(
        id: 'bank',
        name: 'Bank',
        budgetAmountCents: 10000,
        spent: 0,
        currency: 'EUR',
        lastUpdated: DateTime(2026, 10));
    final state = PocketsState.initial().copyWith(
        isLoading: false,
        periodMonth: DateTime(2026, 10),
        currency: 'EUR',
        saved: [pocket],
        editing: [pocket.copyWith()],
        envelopeCategories: {
          'bank': ['bank fees']
        },
        aggregateTotalSpent: 0);
    final projected = rebuildPocketSpendingFromLocalFeed(
        state: state,
        expenses: all,
        isComplete: true,
        selectedCurrencies: ['EUR', 'USD'],
        rates: rates);
    expect(projected.totalSpent, 1.25);
    expect(projected.saved.single.spent, 1.25);
    WalletEntity wallet(String id, String currency, int opening) =>
        WalletEntity(
            id: id,
            userId: 'user',
            householdId: null,
            name: id,
            icon: 'wallet',
            color: '#000000',
            currency: currency,
            openingBalanceCents: opening,
            goalAmountCents: null,
            isDefault: false,
            isSystem: false,
            isArchived: false,
            currentBalanceCents: opening);
    final wallets = [
      wallet('source', 'EUR', 20000),
      wallet('target', 'USD', 0)
    ];
    final source = buildWalletSnapshot(
        wallets: [wallets.first],
        transactions: all,
        endExclusive: DateTime(2026, 11),
        targetCurrency: 'EUR',
        rates: rates);
    expect(source.walletBalances['source'], 9875);
    final target = buildWalletSnapshot(
        wallets: [wallets.last],
        transactions: all,
        endExclusive: DateTime(2026, 11),
        targetCurrency: 'USD',
        rates: rates);
    expect(target.walletBalances['target'], 11000);
    final aggregate = buildWalletSnapshot(
        wallets: wallets,
        transactions: all,
        endExclusive: DateTime(2026, 11),
        targetCurrency: 'EUR',
        rates: rates);
    expect(aggregate.netWorthCents,
        18675); // Reference FX is independent of transfer's 1.1 rate.
    expect(aggregate.totalSpentCents, 125);
    expect(aggregate.totalIncomeCents, 0);
    await db.writeOptimisticWalletTransferUpdate(
        originalEntries: native,
        updatedEntries: rows('optimistic-transfer-test', fee: 0),
        clientMutationId: 'edit',
        transferId: 'optimistic-transfer-test',
        payload: {
          'functionName': 'update-wallet-transfer',
          'requestBody': {'transferId': 'optimistic-transfer-test'}
        });
    expect(await db.hasPendingTransactionUpdatesOrDeletes(), isTrue);
    expect(await db.getPendingTransactionUpdateIds(), contains(native.last.id));
  });

  test('fee removal and dependent delete suppress canonical create children',
      () async {
    for (final delete in [false, true]) {
      final db = MonekoDatabase.inMemory();
      addTearDown(db.close);
      final original = rows('optimistic-transfer-test');
      await db.writeOptimisticWalletTransfer(
          entries: original,
          clientMutationId: 'create',
          entityId: 'optimistic-transfer-test',
          payload: {'functionName': 'create-wallet-transfer'});
      final payload = {
        'functionName':
            delete ? 'delete-wallet-transfer' : 'update-wallet-transfer',
        'requestBody': {'transferId': 'optimistic-transfer-test'}
      };
      if (delete) {
        await db.writeOptimisticWalletTransferDelete(
            entries: original,
            clientMutationId: 'later',
            transferId: 'optimistic-transfer-test',
            payload: payload);
      } else {
        await db.writeOptimisticWalletTransferUpdate(
            originalEntries: original,
            updatedEntries: rows('optimistic-transfer-test', fee: 0),
            clientMutationId: 'later',
            transferId: 'optimistic-transfer-test',
            payload: payload);
      }
      final saved = rows('canonical', feeId: 'canonical-fee');
      await db.replaceOptimisticWalletTransfer(
          optimisticIds: original.map((e) => e.id),
          savedEntries: saved,
          clientMutationId: 'create');
      await db.upsertTransactions(saved);
      expect((await db.getTransactionsFeedPage(query)).items,
          hasLength(delete ? 0 : 1));
      final later = (await db.getOutboxMutations())
          .singleWhere((m) => m.clientMutationId == 'later');
      final originals = (jsonDecode(later.payloadJson)['originalEntries']
              as List)
          .map(
              (e) => ExpenseEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await db.rollbackOptimisticWalletTransferMutation(
          originalEntries: originals,
          clientMutationId: 'later',
          isDelete: delete,
          error: 'terminal');
      expect((await db.getTransactionsFeedPage(query)).items, hasLength(2));
      expect(
          (await db.getTransactionByIdOrClientRecordId('canonical-fee'))
              ?.transferFeeTransferId,
          'canonical');
    }
  });

  test('new fee acknowledgement retargets a newer delete without resurrection',
      () async {
    final db = MonekoDatabase.inMemory();
    addTearDown(db.close);
    final original = rows('canonical', fee: 0);
    final edited = rows('canonical');
    await db.upsertTransactions(original);
    await db.writeOptimisticWalletTransferUpdate(
        originalEntries: original,
        updatedEntries: edited,
        clientMutationId: 'add-fee',
        transferId: 'canonical',
        payload: {
          'functionName': 'update-wallet-transfer',
          'requestBody': {'transferId': 'canonical'}
        });
    await db.writeOptimisticWalletTransferDelete(
        entries: edited,
        clientMutationId: 'delete',
        transferId: 'canonical',
        payload: {
          'functionName': 'delete-wallet-transfer',
          'requestBody': {'transferId': 'canonical'}
        });
    await db.markOptimisticWalletTransferMutationSynced(
        clientMutationId: 'add-fee',
        isDelete: false,
        savedEntries: rows('canonical', feeId: 'canonical-fee'));
    await db.upsertTransactions(rows('canonical', feeId: 'canonical-fee'));
    expect((await db.getTransactionsFeedPage(query)).items, isEmpty);
  });

  test(
      'rejected fee addition removes only owned fee and stale rollback preserves edit',
      () async {
    final db = MonekoDatabase.inMemory();
    addTearDown(db.close);
    final original = rows('canonical', fee: 0);
    await db.upsertTransactions(original);
    await db.writeOptimisticWalletTransferUpdate(
        originalEntries: original,
        updatedEntries: rows('canonical'),
        clientMutationId: 'add',
        transferId: 'canonical',
        payload: {'functionName': 'update-wallet-transfer'});
    await db.rollbackOptimisticWalletTransferMutation(
        originalEntries: original,
        clientMutationId: 'add',
        isDelete: false,
        error: 'rejected');
    expect((await db.getTransactionsFeedPage(query)).items, hasLength(1));
    for (final fee in [125, 200]) {
      await db.writeOptimisticWalletTransferUpdate(
          originalEntries: original,
          updatedEntries: rows('canonical', fee: fee),
          clientMutationId: 'add-$fee',
          transferId: 'canonical',
          payload: {'functionName': 'update-wallet-transfer'});
    }
    await db.rollbackOptimisticWalletTransferMutation(
        originalEntries: original,
        clientMutationId: 'add-125',
        isDelete: false,
        error: 'stale');
    expect(
        (await db.getTransactionByIdOrClientRecordId('transfer-fee:canonical'))
            ?.amountCents,
        200);
  });

  test('terminal create failure cancels edited fee group and all dependencies',
      () async {
    final db = MonekoDatabase.inMemory();
    addTearDown(db.close);
    final original = rows('optimistic-transfer-test', fee: 0);
    await db.writeOptimisticWalletTransfer(
        entries: original,
        clientMutationId: 'create',
        entityId: 'optimistic-transfer-test',
        payload: {'functionName': 'create-wallet-transfer'});
    await db.writeOptimisticWalletTransferUpdate(
        originalEntries: original,
        updatedEntries: rows('optimistic-transfer-test'),
        clientMutationId: 'edit',
        transferId: 'optimistic-transfer-test',
        payload: {
          'functionName': 'update-wallet-transfer',
          'requestBody': {'transferId': 'optimistic-transfer-test'}
        });
    await db.rollbackOptimisticWalletTransfer(
        optimisticIds: original.map((e) => e.id),
        clientMutationId: 'create',
        error: 'terminal');
    expect(await db.getRecentTransactions(userId: 'user', householdId: null),
        isEmpty);
    expect(
        (await db.getOutboxMutations())
            .every((m) => m.status == localMutationStatusCancelled),
        isTrue);
    expect(
        await db.getTransactionByIdOrClientRecordId(
            'transfer-fee:optimistic-transfer-test'),
        isNull);
  });

  test('legacy model defaults and v2 separate native principals', () {
    final legacy = WalletTransfer(
        id: 'old',
        fromAccountId: 'source',
        toAccountId: 'target',
        amountCents: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 15));
    expect(legacy.effectiveToAmountCents, 100);
    expect(legacy.effectiveToCurrency, 'EUR');
    expect(legacy.transferContractVersion, 1);
    final transfer = WalletTransfer.fromJson({
      'id': 'new',
      'from_account_id': 'source',
      'to_account_id': 'target',
      'amount_cents': 10000,
      'currency': 'EUR',
      'to_amount_cents': 11000,
      'to_currency': 'USD',
      'exchange_rate': '1.1',
      'fee_amount_cents': 125,
      'fee_expense_id': 'canonical-fee',
      'transfer_contract_version': 2,
    });
    expect(transfer.effectiveToAmountCents, 11000);
    expect(transfer.effectiveToCurrency, 'USD');
    expect(transfer.exchangeRate, '1.1');
    expect(transfer.feeExpenseId, 'canonical-fee');
  });

  test('pair excludes principal analytics and fee is one linked source expense',
      () {
    final entries = rows('optimistic-transfer-test');
    expect(entries.map((e) => e.amountCents), [10000, 11000, 125]);
    expect(entries.map((e) => e.currency), ['EUR', 'USD', 'EUR']);
    expect(entries.map((e) => e.effectiveSpendingMultiplier), [0, 0, 1]);
    expect(entries.every((e) => !e.countsTowardIncome), isTrue);
    final fee = entries.last;
    expect(fee.walletId, 'source');
    expect(fee.transferFeeTransferId, 'optimistic-transfer-test');
    expect(
        ExpenseEntry.fromJson(fee.toJson())
            .copyWith(amountCents: 150)
            .transferFeeTransferId,
        fee.transferFeeTransferId);
    expect(rows('canonical', feeId: 'fee-uuid').last.id, 'fee-uuid');
    expect(rows('no-fee', fee: 0), hasLength(2));
  });

  test('grouped create survives restart and fee removal rollback is owned',
      () async {
    final directory = await Directory.systemTemp.createTemp('transfer-fee-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/local.sqlite';
    var db = MonekoDatabase.fromExistingDatabaseForTesting(sqlite3.open(path));
    final original = rows('optimistic-transfer-test');
    await db.writeOptimisticWalletTransfer(
        entries: original,
        clientMutationId: 'create',
        entityId: 'optimistic-transfer-test',
        payload: {'functionName': 'create-wallet-transfer'});
    expect((await db.getTransactionsFeedPage(query)).items, hasLength(2));
    await db.close();
    db = MonekoDatabase.fromExistingDatabaseForTesting(sqlite3.open(path));
    addTearDown(db.close);
    expect((await db.getTransactionsFeedPage(query)).items, hasLength(2));
    expect(
        (await db.getTransactionByIdOrClientRecordId(original.last.id))
            ?.transferFeeTransferId,
        'optimistic-transfer-test');
    await db.writeOptimisticWalletTransferUpdate(
        originalEntries: original,
        updatedEntries: rows('optimistic-transfer-test', fee: 0),
        clientMutationId: 'remove-fee',
        transferId: 'optimistic-transfer-test',
        payload: {'functionName': 'update-wallet-transfer'});
    expect((await db.getTransactionsFeedPage(query)).items, hasLength(1));
    await db.upsertTransactions(original);
    expect((await db.getTransactionsFeedPage(query)).items, hasLength(1));
    await db.rollbackOptimisticWalletTransferMutation(
        originalEntries: original,
        clientMutationId: 'remove-fee',
        isDelete: false,
        error: 'rejected');
    expect((await db.getTransactionsFeedPage(query)).items, hasLength(2));
  });

  test('create reconciliation retargets newer fee and rollback identities',
      () async {
    final db = MonekoDatabase.inMemory();
    addTearDown(db.close);
    final original = rows('optimistic-transfer-test');
    await db.writeOptimisticWalletTransfer(
        entries: original,
        clientMutationId: 'create',
        entityId: 'optimistic-transfer-test',
        payload: {'functionName': 'create-wallet-transfer'});
    await db.writeOptimisticWalletTransferUpdate(
        originalEntries: original,
        updatedEntries: rows('optimistic-transfer-test', fee: 200),
        clientMutationId: 'edit',
        transferId: 'optimistic-transfer-test',
        payload: {
          'functionName': 'update-wallet-transfer',
          'requestBody': {'transferId': 'optimistic-transfer-test'}
        });
    await db.replaceOptimisticWalletTransfer(
        optimisticIds: original.map((e) => e.id),
        savedEntries: rows('canonical', feeId: 'canonical-fee'),
        clientMutationId: 'create');
    final fee = await db.getTransactionByIdOrClientRecordId('canonical-fee');
    expect(fee?.amountCents, 200);
    expect(fee?.transferFeeTransferId, 'canonical');
    expect((await db.getTransactionsFeedPage(query)).items, hasLength(2));
    final edit = (await db.getOutboxMutations())
        .singleWhere((m) => m.clientMutationId == 'edit');
    final payload = jsonDecode(edit.payloadJson) as Map<String, dynamic>;
    final before = (payload['originalEntries'] as List)
        .map((e) => ExpenseEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    expect(before.last.id, 'canonical-fee');
    expect(before.last.transferFeeTransferId, 'canonical');
    await db.rollbackOptimisticWalletTransferMutation(
        originalEntries: before,
        clientMutationId: 'edit',
        isDelete: false,
        error: 'rejected');
    expect(
        (await db.getTransactionByIdOrClientRecordId('canonical-fee'))
            ?.amountCents,
        125);
  });
}
