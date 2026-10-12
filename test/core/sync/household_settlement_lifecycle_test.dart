import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/household_settlement_outbox_dispatcher.dart';
import 'package:moneko/core/sync/sync_coordinator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqlite3/sqlite3.dart';

String _token(String character) => 'v1:${List.filled(64, character).join()}';

Map<String, dynamic> _result(String id, {String status = 'applied'}) => {
      'status': status,
      'replayed': false,
      'client_mutation_id': id,
      'settlement_event_id': status == 'applied' ? 'event-$id' : null,
      'requested_amount_cents': 4000,
      'applied_amount_cents': status == 'applied' ? 4000 : 0,
      'pair_balance_before_cents': 10000,
      'pair_balance_after_cents': status == 'applied' ? 6000 : 10000,
      'current_net_cents': status == 'applied' ? 6000 : 10000,
      'cleared_pair_balance': false,
      'result_snapshot_token': _token('b'),
    };

Future<LocalMutationOutboxData> _enqueue(MonekoDatabase database, String id) =>
    database.enqueueHouseholdSettlementMutation(
      householdId: '00000000-0000-0000-0000-000000000001',
      memberUserId: '00000000-0000-0000-0000-000000000002',
      mode: 'to_member',
      amountCents: 4000,
      currency: 'EUR',
      note: 'Partial payment',
      expectedSnapshotToken: _token('a'),
      clientMutationId: id,
    );

void main() {
  test(
      'server acknowledgement survives SQLite close and reopen without pending resurrection',
      () async {
    final directory =
        await Directory('.dart_tool').createTemp('settlement-restart-');
    var database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite3.open('${directory.path}/ledger.sqlite'));
    try {
      final mutation = await _enqueue(database, 'restart');
      await persistHouseholdSettlementAcknowledgement(
          database: database,
          actorUserId: 'actor',
          payload: LocalHouseholdSettlementMutationPayload.fromJson(
              jsonDecode(mutation.payloadJson) as Map<String, dynamic>),
          result: parseHouseholdSettlementWriteResult(_result('restart'),
              expectedClientMutationId: 'restart', expectedAmountCents: 4000));
      await database.markMutationSynced('restart');
      await database.close();
      database = MonekoDatabase.fromExistingDatabaseForTesting(
          sqlite3.open('${directory.path}/ledger.sqlite'));
      expect(
          await database.getPendingHouseholdSettlementMutations(
              householdId: mutation.entityId),
          isEmpty);
      final proof = await database.getHouseholdSettlementAcknowledgements(
          actorUserId: 'actor', householdId: mutation.entityId);
      expect(proof.single['amount_cents'], 4000);
      expect(proof.single['client_mutation_id'], 'restart');
      expect(proof.single['id'], 'event-restart');
      expect(
          await database.getHouseholdSettlementAcknowledgements(
              actorUserId: 'another-actor', householdId: mutation.entityId),
          isEmpty);
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
  test(
      'lost response retries the exact durable request through the real RPC SDK',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final mutation = await _enqueue(database, 'lost-response');
    final requests = <Map<String, dynamic>>[];
    final client = SupabaseClient(
      'https://settlement.test',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.path,
            '/rest/v1/rpc/households_settle_amount_and_notify_v2');
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        // Model an already-committed server result whose first response is lost.
        // Server idempotency itself is not implemented or certified by this stub.
        if (requests.length == 1) throw TimeoutException('response lost');
        return http.Response(
          jsonEncode({..._result('lost-response'), 'replayed': true}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    var now = DateTime.now().toUtc().add(const Duration(seconds: 1));
    SyncCoordinator coordinator() => SyncCoordinator(
          database: database,
          now: () => now,
          dispatchMutation: (queued) async {
            await dispatchHouseholdSettlementMutation(
              client,
              queued,
              jsonDecode(queued.payloadJson) as Map<String, dynamic>,
            );
          },
        );

    expect(await coordinator().drainOutbox(maxMutations: 1), 0);
    final unresolved = await database.getHouseholdSettlementMutation(
      mutation.clientMutationId,
    );
    expect(unresolved!.status, localMutationStatusFailed);
    expect(unresolved.payloadJson, mutation.payloadJson);
    now = now.add(const Duration(minutes: 10));
    // A fresh coordinator models loss of in-process retry state.
    final synced = await coordinator().drainOutbox(maxMutations: 1);
    expect(synced, 1,
        reason: (await database.getHouseholdSettlementMutation(
          mutation.clientMutationId,
        ))
            ?.lastError);
    expect(requests, hasLength(2));
    expect(requests[1], requests[0]);
    expect(requests[1]['p_amount_cents'], 4000);
    expect(requests[1]['p_expected_snapshot_token'], _token('a'));
    expect(requests[1]['p_client_mutation_id'], 'lost-response');
    expect(
        await database.getPendingHouseholdSettlementMutations(
          householdId: mutation.entityId,
        ),
        isEmpty);
    expect(await coordinator().drainOutbox(), 0);
    expect(requests, hasLength(2));
  });

  for (final status in ['snapshot_conflict', 'nothing_to_settle']) {
    test('$status retires the request without an applied payment', () async {
      final database = MonekoDatabase.inMemory();
      addTearDown(database.close);
      final mutation = await _enqueue(database, status);
      final client = SupabaseClient(
        'https://settlement.test',
        'test-key',
        httpClient: MockClient((request) async => http.Response(
              jsonEncode(_result(status, status: status)),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            )),
      );
      addTearDown(client.dispose);
      final coordinator = SyncCoordinator(
        database: database,
        dispatchMutation: (queued) async {
          expect(
            await dispatchHouseholdSettlementMutation(
              client,
              queued,
              jsonDecode(queued.payloadJson) as Map<String, dynamic>,
            ),
            status,
          );
        },
      );
      final synced = await coordinator.drainOutbox();
      expect(synced, 1,
          reason: (await database.getHouseholdSettlementMutation(
            mutation.clientMutationId,
          ))
              ?.lastError);
      expect(
          await database.getPendingHouseholdSettlementMutations(
            householdId: mutation.entityId,
          ),
          isEmpty);
    });
  }

  test('malformed successful acknowledgment keeps the immutable attempt queued',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final mutation = await _enqueue(database, 'malformed');
    final client = SupabaseClient(
      'https://settlement.test',
      'test-key',
      httpClient: MockClient((request) async => http.Response(
            jsonEncode({..._result('malformed'), 'applied_amount_cents': 8000}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          )),
    );
    addTearDown(client.dispose);
    final coordinator = SyncCoordinator(
      database: database,
      dispatchMutation: (queued) async {
        await dispatchHouseholdSettlementMutation(
          client,
          queued,
          jsonDecode(queued.payloadJson) as Map<String, dynamic>,
        );
      },
    );
    expect(await coordinator.drainOutbox(maxMutations: 1), 0);
    final pending = await database.getPendingHouseholdSettlementMutations(
      householdId: mutation.entityId,
    );
    expect(pending.single.status, localMutationStatusFailed);
    expect(pending.single.payloadJson, mutation.payloadJson);
  });

  test('overlapping drains claim a queued settlement only once locally',
      () async {
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    await _enqueue(database, 'concurrent');
    final entered = Completer<void>();
    final release = Completer<void>();
    var dispatched = 0;
    final coordinator = SyncCoordinator(
      database: database,
      dispatchMutation: (_) async {
        dispatched++;
        entered.complete();
        await release.future;
      },
    );
    final first = coordinator.drainOutbox();
    await entered.future;
    expect(await coordinator.drainOutbox(), 0);
    release.complete();
    expect(await first, 1);
    expect(dispatched, 1);
  });
}
