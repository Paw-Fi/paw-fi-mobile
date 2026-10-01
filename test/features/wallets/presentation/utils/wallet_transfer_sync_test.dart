import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_delta_sync_service.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:sqlite3/sqlite3.dart';

List<ExpenseEntry> _serverRows(String? time, {int revision = 1}) => [
      for (final direction in ['out', 'in'])
        ExpenseEntry.fromJson({
          'id': 'transfer:00000000-0000-4000-8000-000000000001:$direction',
          'user_id': 'user-1',
          'date': '2026-10-01',
          'transfer_time': time,
          'amount_cents': 1000,
          'currency': 'USD',
          'category': 'transfers',
          'account_id': direction == 'out' ? 'from' : 'to',
          'type': direction == 'out' ? 'expense' : 'income',
          'created_at': '2026-10-01T01:00:00Z',
          'updated_at': '2026-10-01T0$revision:00:00Z',
          'analytics_class': 'transfer_$direction',
          'analytics_is_final': true,
          'analytics_spending_multiplier': 0,
          'analytics_counts_toward_income': false,
        }),
    ];

const _query = TransactionsFeedQuery(
  userId: 'user-1',
  householdId: null,
  selectedCurrency: 'USD',
  selectedCategory: null,
  selectedType: 'all',
  searchQuery: '',
  startDate: null,
  endDate: null,
  selectedAccountId: 'from',
);

class _TransferRemote extends TransactionsFeedService {
  _TransferRemote(this.rows);
  List<ExpenseEntry> rows;

  @override
  Future<TransactionsFeedPageResult> fetchPage(TransactionsFeedQuery query,
          {TransactionsFeedCursor? cursor}) async =>
      TransactionsFeedPageResult(
        items: rows
            .where((row) => row.walletId == query.normalizedAccountId)
            .toList(),
        hasMore: false,
        nextCursor: null,
      );

  @override
  Future<TransactionsFeedSummary> fetchSummary(
          TransactionsFeedQuery query) async =>
      const TransactionsFeedSummary.empty();
}

void main() {
  test('canonical update acknowledgement persists server clock and version',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _serverRows('09:30:00');
    await database.upsertTransactions(original);
    await database.writeOptimisticWalletTransferUpdate(
      originalEntries: original,
      updatedEntries: _serverRows(null, revision: 2)
          .map((row) => row.copyWith(accountName: 'Cached wallet'))
          .toList(),
      clientMutationId: 'clear-time',
      transferId: '00000000-0000-4000-8000-000000000001',
      payload: {'functionName': 'update-wallet-transfer'},
    );
    await database.markOptimisticWalletTransferMutationSynced(
      clientMutationId: 'clear-time',
      isDelete: false,
      savedEntries: _serverRows(null, revision: 3),
    );
    await database.rollbackOptimisticWalletTransferMutation(
      originalEntries: original,
      clientMutationId: 'clear-time',
      isDelete: false,
      error: StateError('late failure after authoritative acknowledgement'),
    );
    await database.upsertTransactions(_serverRows('09:30:00', revision: 2));
    final saved =
        await database.getTransactionByIdOrClientRecordId(original.first.id);
    expect(saved?.transferTime, isNull);
    expect(saved?.updatedAt, DateTime.utc(2026, 10, 1, 3));
    expect(saved?.accountName, 'Cached wallet');
  });

  test('older update acknowledgement cannot replace a newer pending clock',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _serverRows('09:30:00');
    await database.upsertTransactions(original);
    for (final revision in [2, 3]) {
      await database.writeOptimisticWalletTransferUpdate(
        originalEntries: original,
        updatedEntries: _serverRows(revision == 2 ? '14:45:00' : '18:00:00',
            revision: revision),
        clientMutationId: 'time-$revision',
        transferId: '00000000-0000-4000-8000-000000000001',
        payload: {'functionName': 'update-wallet-transfer'},
      );
    }
    await database.markOptimisticWalletTransferMutationSynced(
      clientMutationId: 'time-2',
      isDelete: false,
      savedEntries: _serverRows('14:45:00', revision: 4),
    );
    final pending = await database.getTransactionByIdOrClientRecordId(
        original.first.id,
        syncStatus: localSyncStatusLocal);
    expect(pending?.transferTime, '18:00:00');
  });

  test('transfer delta drains pages and applies both deletion directions',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final cursors = <String?>[];
    final rows = _serverRows('14:45:00', revision: 2);
    final service = MobileDeltaSyncService(
      database: database,
      fetchDelta: (
              {required userId,
              required since,
              required sinceId,
              required limit}) async =>
          const MobileDelta(),
      fetchTransferDelta: (
          {required userId,
          required since,
          required sinceId,
          required limit}) async {
        cursors.add(sinceId);
        if (cursors.length == 1) {
          return MobileDelta(
              transactions: rows,
              hasMore: true,
              nextCursor: DateTime.utc(2026, 10, 1, 2),
              nextCursorId: 'transfer-cursor-1');
        }
        return MobileDelta(
            deletedTransactionIds: rows.map((row) => row.id).toList(),
            nextCursor: DateTime.utc(2026, 10, 1, 3),
            nextCursorId: 'transfer-cursor-2');
      },
    );
    await service.pullAndApply(userId: 'user-1');
    expect(cursors, [null, 'transfer-cursor-1']);
    for (final row in rows) {
      expect(await database.getTransactionByIdOrClientRecordId(row.id), isNull);
    }
  });

  test('failed transfer page does not advance its persisted cursor', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.setSyncCursorValue(
        entityName: mobileTransferDeltaEntityName,
        scopeKey: 'user-1:all',
        cursor: '{"changedAt":"2026-10-01T02:00:00Z","id":"cursor-1"}');
    final service = MobileDeltaSyncService(
      database: database,
      fetchDelta: (
              {required userId,
              required since,
              required sinceId,
              required limit}) async =>
          const MobileDelta(),
      fetchTransferDelta: (
          {required userId,
          required since,
          required sinceId,
          required limit}) async {
        expect(sinceId, 'cursor-1');
        throw StateError('offline');
      },
    );
    await expectLater(service.pullAndApply(userId: 'user-1'), throwsStateError);
    expect(
        await database.getSyncCursorValue(
            entityName: mobileTransferDeltaEntityName, scopeKey: 'user-1:all'),
        contains('cursor-1'));
  });

  test('refresh of the receiving wallet also updates the paired outgoing clock',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.upsertTransactions(_serverRows('09:30:00'));
    final remote = _TransferRemote(_serverRows('14:45:00', revision: 2));
    final service =
        LocalFirstTransactionsFeedService(database: database, remote: remote);
    for (final time in ['14:45:00', null]) {
      remote.rows = _serverRows(time, revision: time == null ? 3 : 2);
      await service.refreshFromRemote(_query.copyWith(selectedAccountId: 'to'));
      for (final row in remote.rows) {
        expect(
            (await database.getTransactionByIdOrClientRecordId(row.id))
                ?.transferTime,
            time);
      }
    }
  });

  test('refresh replaces cross-device time, including explicit null, in SQLite',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.upsertTransactions(_serverRows('09:30:00'));
    final remote = _TransferRemote(_serverRows('14:45:00', revision: 2));
    final service =
        LocalFirstTransactionsFeedService(database: database, remote: remote);
    await service.refreshFromRemote(_query);
    expect(
        (await database
                .getTransactionByIdOrClientRecordId(remote.rows.first.id))
            ?.transferTime,
        '14:45:00');
    remote.rows = _serverRows(null, revision: 3);
    await service.refreshFromRemote(_query);
    expect(
        (await database
                .getTransactionByIdOrClientRecordId(remote.rows.first.id))
            ?.transferTime,
        isNull);
  });

  test('older in-flight server response cannot erase a more recent synced time',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.upsertTransactions(_serverRows('14:45:00', revision: 3));
    await database.upsertTransactions(_serverRows('09:30:00', revision: 2));
    expect(
        (await database
                .getTransactionByIdOrClientRecordId(_serverRows(null).first.id))
            ?.transferTime,
        '14:45:00');
  });

  test(
      'transfer delta updates both rows and reuses its own cursor after restart',
      () async {
    final directory = await Directory.systemTemp.createTemp('transfer-sync-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/local.sqlite';
    var database =
        MonekoDatabase.fromExistingDatabaseForTesting(sqlite3.open(path));
    await database.upsertTransactions(_serverRows('09:30:00'));
    await database.setSyncCursorValue(
        entityName: mobileDeltaEntityName,
        scopeKey: 'user-1:all',
        cursor: '{"changedAt":"2026-10-01T08:00:00Z"}');
    final capturedTransferCursors = <DateTime?>[];
    MobileDeltaSyncService sync(
            MonekoDatabase local, String? time, int revision) =>
        MobileDeltaSyncService(
          database: local,
          fetchDelta: (
                  {required userId,
                  required since,
                  required sinceId,
                  required limit}) async =>
              const MobileDelta(),
          fetchTransferDelta: (
              {required userId,
              required since,
              required sinceId,
              required limit}) async {
            capturedTransferCursors.add(since);
            return MobileDelta(
                transactions: _serverRows(time, revision: revision),
                nextCursor: DateTime.utc(2026, 10, 1, revision),
                nextCursorId: '00000000-0000-4000-8000-000000000001');
          },
        );
    await sync(database, '14:45:00', 2).pullAndApply(userId: 'user-1');
    expect(capturedTransferCursors.single, isNull);
    await database.close();
    database =
        MonekoDatabase.fromExistingDatabaseForTesting(sqlite3.open(path));
    final offline = LocalFirstTransactionsFeedService(
        database: database, remote: _TransferRemote([]), remoteEnabled: false);
    expect((await offline.fetchPage(_query)).items.single.transferTime,
        '14:45:00');
    await sync(database, null, 3).pullAndApply(userId: 'user-1');
    expect(capturedTransferCursors.last, DateTime.utc(2026, 10, 1, 2));
    await database.close();
    database =
        MonekoDatabase.fromExistingDatabaseForTesting(sqlite3.open(path));
    addTearDown(database.close);
    for (final row in _serverRows(null)) {
      final saved = await database.getTransactionByIdOrClientRecordId(row.id);
      expect(saved?.date, DateTime(2026, 10, 1));
      expect(saved?.transferTime, isNull);
    }
  });

  test('server time refresh preserves pending local edit until reconciliation',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final original = _serverRows('09:30:00');
    final pending = _serverRows('18:00:00', revision: 2);
    await database.upsertTransactions(original);
    await database.writeOptimisticWalletTransferUpdate(
      originalEntries: original,
      updatedEntries: pending,
      clientMutationId: 'pending-time',
      transferId: '00000000-0000-4000-8000-000000000001',
      payload: {'functionName': 'update-wallet-transfer'},
    );
    await database.upsertTransactions(_serverRows(null, revision: 3));
    expect(
        (await database.getTransactionByIdOrClientRecordId(original.first.id))
            ?.transferTime,
        '18:00:00');
    await database.markOptimisticWalletTransferMutationSynced(
        clientMutationId: 'pending-time', isDelete: false);
    await database.upsertTransactions(_serverRows(null, revision: 3));
    expect(
        (await database.getTransactionByIdOrClientRecordId(original.first.id))
            ?.transferTime,
        isNull);
  });
}
