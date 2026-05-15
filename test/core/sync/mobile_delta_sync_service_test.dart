import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_delta_sync_service.dart';

void main() {
  test('MobileDelta parses transactions, deleted ids, cursor, and hasMore', () {
    final dynamicRow = <Object?, Object?>{
      'id': 'expense_1',
      'user_id': 'user_1',
      'date': '2026-04-10',
      'amount_cents': 1250,
      'currency': 'EUR',
      'category': 'food',
      'created_at': '2026-04-10T09:00:00.000Z',
      'type': 'expense',
    };

    final delta = MobileDelta.fromJson({
      'transactions': [dynamicRow],
      'deletedTransactionIds': ['expense_2'],
      'nextCursor': '2026-04-10T09:01:00.000Z',
      'nextCursorId': _cursorId1,
      'hasMore': true,
    });

    expect(delta.transactions.single.id, 'expense_1');
    expect(delta.deletedTransactionIds, ['expense_2']);
    expect(delta.nextCursor, DateTime.parse('2026-04-10T09:01:00.000Z'));
    expect(delta.nextCursorId, _cursorId1);
    expect(delta.hasMore, isTrue);
  });

  test('MobileDeltaSyncService applies transactions and deleted ids locally',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await database.upsertTransactions([
      _entryJson('expense_2'),
    ]
        .map((json) => MobileDelta.fromJson({
              'transactions': [json],
            }).transactions.single)
        .toList());

    final service = MobileDeltaSyncService(
      database: database,
      fetchDelta: ({
        required userId,
        required since,
        required sinceId,
        required limit,
      }) async {
        return MobileDelta.fromJson({
          'transactions': [_entryJson('expense_1')],
          'deletedTransactionIds': ['expense_2'],
          'nextCursor': '2026-04-10T09:01:00.000Z',
          'nextCursorId': _cursorId1,
          'hasMore': false,
        });
      },
    );

    final result = await service.pullAndApply(userId: 'user_1');
    final rows = await database.getRecentTransactions(
      userId: 'user_1',
      householdId: null,
      limit: 20,
    );

    expect(result.nextCursor, DateTime.parse('2026-04-10T09:01:00.000Z'));
    expect(rows.map((entry) => entry.id), ['expense_1']);
  });

  test('MobileDeltaSyncService preserves pending local rows and tombstones',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final pending = MobileDelta.fromJson({
      'transactions': [_entryJson('pending_create')],
    }).transactions.single;
    final deleting = MobileDelta.fromJson({
      'transactions': [_entryJson('pending_delete')],
    }).transactions.single;
    await database.writeOptimisticTransaction(
      entry: pending,
      clientMutationId: 'mobile:create_pending',
      operation: 'create',
      payload: {'id': pending.id},
    );
    await database.upsertTransactions([deleting]);
    await database.writeOptimisticTransactionDelete(
      entries: [deleting],
      clientMutationId: 'mobile:delete_pending',
      payload: {'expenseIds': deleting.id},
    );

    final service = MobileDeltaSyncService(
      database: database,
      fetchDelta: ({
        required userId,
        required since,
        required sinceId,
        required limit,
      }) async {
        return MobileDelta.fromJson({
          'transactions': [
            {..._entryJson('pending_create'), 'amount_cents': 9999},
            {..._entryJson('pending_delete'), 'amount_cents': 9999},
          ],
          'deletedTransactionIds': const [],
          'hasMore': false,
        });
      },
    );

    await service.pullAndApply(userId: 'user_1');
    final rows = await database.getRecentTransactions(
      userId: 'user_1',
      householdId: null,
      limit: 20,
    );

    expect(rows.map((entry) => entry.id), ['pending_create']);
    expect(rows.single.amountCents, 1250);
  });

  test('MobileDeltaSyncService persists and reuses sync cursor', () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);

    DateTime? capturedSince;
    String? capturedSinceId;
    var callCount = 0;
    final service = MobileDeltaSyncService(
      database: database,
      fetchDelta: ({
        required userId,
        required since,
        required sinceId,
        required limit,
      }) async {
        callCount += 1;
        capturedSince = since;
        capturedSinceId = sinceId;
        return MobileDelta.fromJson({
          'transactions': const [],
          'deletedTransactionIds': const [],
          'nextCursor': callCount == 1
              ? '2026-04-10T09:01:00.000Z'
              : '2026-04-10T09:02:00.000Z',
          'nextCursorId': callCount == 1 ? _cursorId1 : _cursorId2,
          'hasMore': false,
        });
      },
    );

    await service.pullAndApply(userId: 'user_1');
    expect(capturedSince, isNull);
    expect(capturedSinceId, isNull);

    await service.pullAndApply(userId: 'user_1');
    expect(capturedSince, DateTime.parse('2026-04-10T09:01:00.000Z'));
    expect(capturedSinceId, _cursorId1);
  });

  test('MobileDeltaSyncService drains multiple delta pages in one pull',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);

    final capturedCursors = <String?>[];
    var callCount = 0;
    final service = MobileDeltaSyncService(
      database: database,
      fetchDelta: ({
        required userId,
        required since,
        required sinceId,
        required limit,
      }) async {
        callCount += 1;
        capturedCursors.add(sinceId);
        if (callCount == 1) {
          return MobileDelta.fromJson({
            'transactions': [_entryJson('expense_1')],
            'deletedTransactionIds': const [],
            'nextCursor': '2026-04-10T09:01:00.000Z',
            'nextCursorId': _cursorId1,
            'hasMore': true,
          });
        }
        return MobileDelta.fromJson({
          'transactions': [_entryJson('expense_2')],
          'deletedTransactionIds': const [],
          'nextCursor': '2026-04-10T09:02:00.000Z',
          'nextCursorId': _cursorId2,
          'hasMore': false,
        });
      },
    );

    final result = await service.pullAndApply(userId: 'user_1');
    final rows = await database.getRecentTransactions(
      userId: 'user_1',
      householdId: null,
      limit: 20,
    );

    expect(callCount, 2);
    expect(capturedCursors, [null, _cursorId1]);
    expect(result.transactions.map((entry) => entry.id), [
      'expense_1',
      'expense_2',
    ]);
    expect(result.nextCursorId, _cursorId2);
    expect(
        rows.map((entry) => entry.id), containsAll(['expense_1', 'expense_2']));
    expect(rows, hasLength(2));
  });
}

const String _cursorId1 = '00000000-0000-4000-8000-000000000001';
const String _cursorId2 = '00000000-0000-4000-8000-000000000002';

Map<String, dynamic> _entryJson(String id) {
  return {
    'id': id,
    'user_id': 'user_1',
    'date': '2026-04-10',
    'amount_cents': 1250,
    'currency': 'EUR',
    'category': 'food',
    'created_at': '2026-04-10T09:00:00.000Z',
    'type': 'expense',
  };
}
