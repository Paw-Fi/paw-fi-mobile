import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_transfer_feed_entries.dart';

void main() {
  test('rebuilds existing synthetic transfer rows with the edited values', () {
    const fromWallet = WalletEntity(
      id: 'from-wallet',
      userId: 'user-1',
      householdId: null,
      name: 'Checking',
      icon: 'wallet',
      color: '#112233',
      currency: 'USD',
      openingBalanceCents: 10000,
      goalAmountCents: null,
      isDefault: true,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 7500,
    );
    const toWallet = WalletEntity(
      id: 'to-wallet',
      userId: 'user-1',
      householdId: null,
      name: 'Savings',
      icon: 'savings',
      color: '#445566',
      currency: 'USD',
      openingBalanceCents: 0,
      goalAmountCents: null,
      isDefault: false,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 2500,
    );

    final rows = buildWalletTransferFeedEntriesForTransfer(
      transfer: WalletTransfer(
        id: 'transfer-1',
        fromAccountId: fromWallet.id,
        toAccountId: toWallet.id,
        amountCents: 3000,
        currency: 'USD',
        date: DateTime(2026, 8, 12),
        note: 'Updated note',
      ),
      fallbackUserId: 'user-1',
      fromWallet: fromWallet,
      toWallet: toWallet,
    );

    expect(rows.map((row) => row.id), [
      'transfer:transfer-1:out',
      'transfer:transfer-1:in',
    ]);
    expect(rows.map((row) => row.amountCents), [3000, 3000]);
    expect(rows.map((row) => row.rawText), ['Updated note', 'Updated note']);
  });

  test('builds wallet-bound outgoing and incoming transfer feed rows',
      () async {
    const fromWallet = WalletEntity(
      id: 'from-wallet',
      userId: 'user-1',
      householdId: null,
      name: 'Checking',
      icon: 'wallet',
      color: '#112233',
      currency: 'USD',
      openingBalanceCents: 10000,
      goalAmountCents: null,
      isDefault: true,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 7500,
    );
    const toWallet = WalletEntity(
      id: 'to-wallet',
      userId: 'user-1',
      householdId: null,
      name: 'Savings',
      icon: 'savings',
      color: '#445566',
      currency: 'USD',
      openingBalanceCents: 0,
      goalAmountCents: null,
      isDefault: false,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 2500,
    );

    final rows = buildWalletTransferFeedEntries(
      transferJson: {
        'id': 'transfer-1',
        'from_account_id': fromWallet.id,
        'to_account_id': toWallet.id,
        'amount_cents': 2500,
        'currency': 'USD',
        'date': '2026-07-28',
        'note': 'Emergency fund',
        'created_by_user_id': 'user-1',
        'household_id': null,
        'created_at': '2026-07-28T12:00:00Z',
        'updated_at': '2026-07-28T12:00:00Z',
      },
      fallbackUserId: 'user-1',
      fromWallet: fromWallet,
      toWallet: toWallet,
    );

    expect(rows, hasLength(2));

    final outgoing = rows.firstWhere((row) => row.id.endsWith(':out'));
    expect(outgoing.id, 'transfer:transfer-1:out');
    expect(outgoing.walletId, fromWallet.id);
    expect(outgoing.accountName, fromWallet.name);
    expect(outgoing.type, 'expense');
    expect(outgoing.analyticsClass, 'transfer_out');
    expect(outgoing.analyticsSpendingMultiplier, 0);
    expect(outgoing.analyticsCountsTowardIncome, isFalse);
    expect(outgoing.rawText, 'Emergency fund');

    final incoming = rows.firstWhere((row) => row.id.endsWith(':in'));
    expect(incoming.id, 'transfer:transfer-1:in');
    expect(incoming.walletId, toWallet.id);
    expect(incoming.accountName, toWallet.name);
    expect(incoming.type, 'income');
    expect(incoming.analyticsClass, 'transfer_in');
    expect(incoming.analyticsSpendingMultiplier, 0);
    expect(incoming.analyticsCountsTowardIncome, isFalse);
    expect(incoming.rawText, 'Emergency fund');

    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.upsertTransactions(rows);

    final sourcePage = await database.getTransactionsFeedPage(
      const LocalTransactionsFeedQuery(
        userId: 'user-1',
        householdId: null,
        currency: 'USD',
        accountId: 'from-wallet',
      ),
    );
    expect(sourcePage.items.map((row) => row.id), [outgoing.id]);

    final destinationPage = await database.getTransactionsFeedPage(
      const LocalTransactionsFeedQuery(
        userId: 'user-1',
        householdId: null,
        currency: 'USD',
        accountId: 'to-wallet',
      ),
    );
    expect(destinationPage.items.map((row) => row.id), [incoming.id]);
  });

  test('optimistic wallet transfer rows stay visible and reconcile atomically',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final optimisticRows = buildWalletTransferFeedEntries(
      transferJson: {
        'id': 'optimistic-transfer-1',
        'from_account_id': 'from-wallet',
        'to_account_id': 'to-wallet',
        'amount_cents': 2500,
        'currency': 'USD',
        'date': '2026-07-28',
        'created_by_user_id': 'user-1',
        'created_at': '2026-07-28T12:00:00Z',
      },
      fallbackUserId: 'user-1',
    );

    await database.writeOptimisticWalletTransfer(
      entries: optimisticRows,
      clientMutationId: 'mobile:wallet_optimistic-transfer-1',
      entityId: 'optimistic-transfer-1',
      payload: const {
        'functionName': 'create-wallet-transfer',
        'requestBody': {
          'fromAccountId': 'from-wallet',
          'toAccountId': 'to-wallet',
          'amountCents': 2500,
          'currency': 'USD',
          'date': '2026-07-28',
        },
      },
    );

    const sourceQuery = LocalTransactionsFeedQuery(
      userId: 'user-1',
      householdId: null,
      currency: 'USD',
      accountId: 'from-wallet',
    );
    expect(
      (await database.getTransactionsFeedPage(sourceQuery))
          .items
          .map((row) => row.id),
      ['transfer:optimistic-transfer-1:out'],
    );
    final editedRows = buildWalletTransferFeedEntries(
      transferJson: {
        'id': 'optimistic-transfer-1',
        'from_account_id': 'from-wallet',
        'to_account_id': 'to-wallet',
        'amount_cents': 3000,
        'currency': 'USD',
        'date': '2026-07-28',
        'created_by_user_id': 'user-1',
        'created_at': '2026-07-28T12:00:00Z',
      },
      fallbackUserId: 'user-1',
    );
    await database.writeOptimisticWalletTransferUpdate(
      originalEntries: optimisticRows,
      updatedEntries: editedRows,
      clientMutationId: 'mobile:wallet_transfer-edit-1',
      transferId: 'optimistic-transfer-1',
      payload: const {
        'functionName': 'update-wallet-transfer',
        'requestBody': {'transferId': 'optimistic-transfer-1'},
      },
    );

    final savedRows = buildWalletTransferFeedEntries(
      transferJson: {
        'id': 'server-transfer-1',
        'from_account_id': 'from-wallet',
        'to_account_id': 'to-wallet',
        'amount_cents': 2500,
        'currency': 'USD',
        'date': '2026-07-28',
        'created_by_user_id': 'user-1',
        'created_at': '2026-07-28T12:00:01Z',
      },
      fallbackUserId: 'user-1',
    );
    await database.replaceOptimisticWalletTransfer(
      optimisticIds: optimisticRows.map((row) => row.id),
      savedEntries: savedRows,
      clientMutationId: 'mobile:wallet_optimistic-transfer-1',
    );

    expect(
      (await database.getTransactionsFeedPage(sourceQuery))
          .items
          .map((row) => row.id),
      ['transfer:server-transfer-1:out'],
    );
    expect(
      (await database.getTransactionsFeedPage(sourceQuery))
          .items
          .single
          .amountCents,
      3000,
    );
    expect(
      (await database.getOutboxMutations())
          .singleWhere((mutation) =>
              mutation.clientMutationId == 'mobile:wallet_transfer-edit-1')
          .entityId,
      'server-transfer-1',
    );
    final dependentMutation = (await database.getOutboxMutations()).singleWhere(
      (mutation) =>
          mutation.clientMutationId == 'mobile:wallet_transfer-edit-1',
    );
    final dependentPayload =
        jsonDecode(dependentMutation.payloadJson) as Map<String, dynamic>;
    expect(dependentMutation.status, localMutationStatusQueued);
    expect(
      (dependentPayload['requestBody'] as Map)['transferId'],
      'server-transfer-1',
    );
    final rollbackEntries = (dependentPayload['originalEntries'] as List)
        .whereType<Map>()
        .map((entry) => ExpenseEntry.fromJson(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
    expect(rollbackEntries.first.id, 'transfer:server-transfer-1:out');

    await database.rollbackOptimisticWalletTransferMutation(
      originalEntries: rollbackEntries,
      clientMutationId: dependentMutation.clientMutationId,
      isDelete: false,
      error: StateError('rejected edit'),
    );
    expect(
      (await database.getTransactionsFeedPage(sourceQuery))
          .items
          .single
          .amountCents,
      2500,
    );
  });

  test('pending transfer delete suppresses create rows and retargets rollback',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final optimisticRows = buildWalletTransferFeedEntries(
      transferJson: {
        'id': 'optimistic-transfer-delete',
        'from_account_id': 'from-wallet',
        'to_account_id': 'to-wallet',
        'amount_cents': 2500,
        'currency': 'USD',
        'date': '2026-07-28',
        'created_by_user_id': 'user-1',
        'created_at': '2026-07-28T12:00:00Z',
      },
      fallbackUserId: 'user-1',
    );
    await database.writeOptimisticWalletTransfer(
      entries: optimisticRows,
      clientMutationId: 'mobile:wallet_optimistic-transfer-delete',
      entityId: 'optimistic-transfer-delete',
      payload: const {'functionName': 'create-wallet-transfer'},
    );
    await database.writeOptimisticWalletTransferDelete(
      entries: optimisticRows,
      clientMutationId: 'mobile:wallet_transfer-delete-pending',
      transferId: 'optimistic-transfer-delete',
      payload: const {
        'functionName': 'delete-wallet-transfer',
        'requestBody': {'transferId': 'optimistic-transfer-delete'},
      },
    );
    final savedRows = buildWalletTransferFeedEntries(
      transferJson: {
        'id': 'server-transfer-delete',
        'from_account_id': 'from-wallet',
        'to_account_id': 'to-wallet',
        'amount_cents': 2500,
        'currency': 'USD',
        'date': '2026-07-28',
        'created_by_user_id': 'user-1',
        'created_at': '2026-07-28T12:00:01Z',
      },
      fallbackUserId: 'user-1',
    );
    await database.replaceOptimisticWalletTransfer(
      optimisticIds: optimisticRows.map((entry) => entry.id),
      savedEntries: savedRows,
      clientMutationId: 'mobile:wallet_optimistic-transfer-delete',
    );

    const sourceQuery = LocalTransactionsFeedQuery(
      userId: 'user-1',
      householdId: null,
      currency: 'USD',
      accountId: 'from-wallet',
    );
    expect(
        (await database.getTransactionsFeedPage(sourceQuery)).items, isEmpty);
    final deleteMutation = (await database.getOutboxMutations()).singleWhere(
      (mutation) =>
          mutation.clientMutationId == 'mobile:wallet_transfer-delete-pending',
    );
    final deletePayload =
        jsonDecode(deleteMutation.payloadJson) as Map<String, dynamic>;
    final rollbackEntries = (deletePayload['originalEntries'] as List)
        .whereType<Map>()
        .map((entry) => ExpenseEntry.fromJson(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
    expect((deletePayload['requestBody'] as Map)['transferId'],
        'server-transfer-delete');
    expect(rollbackEntries.first.id, 'transfer:server-transfer-delete:out');

    await database.rollbackOptimisticWalletTransferMutation(
      originalEntries: rollbackEntries,
      clientMutationId: deleteMutation.clientMutationId,
      isDelete: true,
      error: StateError('rejected delete'),
    );
    expect(
      (await database.getTransactionsFeedPage(sourceQuery)).items.single.id,
      'transfer:server-transfer-delete:out',
    );
  });

  test('terminal wallet transfer failure removes optimistic rows', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final optimisticRows = buildWalletTransferFeedEntries(
      transferJson: {
        'id': 'optimistic-transfer-2',
        'from_account_id': 'from-wallet',
        'to_account_id': 'to-wallet',
        'amount_cents': 2500,
        'currency': 'USD',
        'date': '2026-07-28',
        'created_by_user_id': 'user-1',
        'created_at': '2026-07-28T12:00:00Z',
      },
      fallbackUserId: 'user-1',
    );
    const clientMutationId = 'mobile:wallet_optimistic-transfer-2';
    await database.writeOptimisticWalletTransfer(
      entries: optimisticRows,
      clientMutationId: clientMutationId,
      entityId: 'optimistic-transfer-2',
      payload: const {'functionName': 'create-wallet-transfer'},
    );

    await database.rollbackOptimisticWalletTransfer(
      optimisticIds: optimisticRows.map((row) => row.id),
      clientMutationId: clientMutationId,
      error: StateError('rejected'),
    );

    final sourcePage = await database.getTransactionsFeedPage(
      const LocalTransactionsFeedQuery(
        userId: 'user-1',
        householdId: null,
        currency: 'USD',
        accountId: 'from-wallet',
      ),
    );
    expect(sourcePage.items, isEmpty);
  });

  test('transfer edit and delete project feed rows with revision-safe rollback',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final originalRows = buildWalletTransferFeedEntries(
      transferJson: {
        'id': 'transfer-3',
        'from_account_id': 'from-wallet',
        'to_account_id': 'to-wallet',
        'amount_cents': 2500,
        'currency': 'USD',
        'date': '2026-07-28',
        'created_by_user_id': 'user-1',
        'created_at': '2026-07-28T12:00:00Z',
      },
      fallbackUserId: 'user-1',
    );
    await database.upsertTransactions(originalRows);
    final updatedRows = buildWalletTransferFeedEntries(
      transferJson: {
        'id': 'transfer-3',
        'from_account_id': 'from-wallet',
        'to_account_id': 'to-wallet',
        'amount_cents': 4200,
        'currency': 'USD',
        'date': '2026-07-29',
        'note': 'Updated',
        'created_by_user_id': 'user-1',
        'created_at': '2026-07-28T12:00:00Z',
      },
      fallbackUserId: 'user-1',
    );

    await database.writeOptimisticWalletTransferUpdate(
      originalEntries: originalRows,
      updatedEntries: updatedRows,
      clientMutationId: 'mobile:wallet_transfer-edit-3',
      transferId: 'transfer-3',
      payload: const {'functionName': 'update-wallet-transfer'},
    );
    expect(
      (await database.getTransactionsFeedPage(const LocalTransactionsFeedQuery(
        userId: 'user-1',
        householdId: null,
        currency: 'USD',
        accountId: 'from-wallet',
      )))
          .items
          .single
          .amountCents,
      4200,
    );

    await database.writeOptimisticWalletTransferDelete(
      entries: updatedRows,
      clientMutationId: 'mobile:wallet_transfer-delete-3',
      transferId: 'transfer-3',
      payload: const {'functionName': 'delete-wallet-transfer'},
    );
    await database.rollbackOptimisticWalletTransferMutation(
      originalEntries: originalRows,
      clientMutationId: 'mobile:wallet_transfer-edit-3',
      isDelete: false,
      error: StateError('stale edit failed'),
    );
    expect(
      (await database.getTransactionsFeedPage(const LocalTransactionsFeedQuery(
        userId: 'user-1',
        householdId: null,
        currency: 'USD',
        accountId: 'from-wallet',
      )))
          .items,
      isEmpty,
    );

    await database.rollbackOptimisticWalletTransferMutation(
      originalEntries: updatedRows,
      clientMutationId: 'mobile:wallet_transfer-delete-3',
      isDelete: true,
      error: StateError('delete failed'),
    );
    expect(
      (await database.getTransactionsFeedPage(const LocalTransactionsFeedQuery(
        userId: 'user-1',
        householdId: null,
        currency: 'USD',
        accountId: 'from-wallet',
      )))
          .items
          .single
          .amountCents,
      4200,
    );
  });
}
