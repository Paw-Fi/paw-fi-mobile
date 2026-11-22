import 'dart:async';

import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/profile/data/financial_reset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const activeId = '682c7b39-c220-499a-a241-81398cc7df46';
  late Future<Object?> Function(String, Map<String, dynamic>) rpc;
  late FinancialReset reset;
  late MonekoDatabase db;
  var owner = 'A';
  var cleanupCount = 0;
  FinancialReset restart() => FinancialReset(
        rpc: (name, params) => rpc(name, params),
        database: () async => db,
        timeout: const Duration(milliseconds: 100),
      );
  Future<ResetJob?> run(
      {bool confirm = false, bool failCleanup = false}) async {
    if (confirm) await reset.prepare('A', () => owner == 'A');
    return reset.run(
      userId: 'A',
      isCurrent: () => owner == 'A',
      cleanup: (guard) async {
        guard();
        cleanupCount++;
        if (failCleanup) throw StateError('disk unavailable');
      },
    );
  }

  setUp(() {
    db = MonekoDatabase.inMemory();
    addTearDown(db.close);
    owner = 'A';
    cleanupCount = 0;
    reset = restart();
  });

  test('account switch during confirmation does not save or enqueue', () async {
    rpc = (_, __) => fail('unexpected reset');
    final preparing = reset.prepare('A', () => owner == 'A');
    owner = 'B';
    await expectLater(preparing, throwsStateError);
    expect(await reset.saved('A'), isNull);
    expect(await reset.saved('B'), isNull);
  });

  test('wrong job or missing known status cannot authorize cleanup or enqueue',
      () async {
    var requests = 0;
    rpc = (name, args) async {
      if (requests == 0 && name == 'get_financial_data_reset') return null;
      if (name == 'request_financial_data_reset') {
        requests++;
        return {'id': activeId, 'status': 'pending'};
      }
      return {
        'id': 'e1f86e92-7e2e-44b8-b559-c81e178589ce',
        'status': 'completed'
      };
    };
    await run(confirm: true);
    await expectLater(run(), throwsFormatException);
    rpc = (name, _) async {
      expect(name, 'get_financial_data_reset');
      return null;
    };
    await expectLater(run(), throwsStateError);
    expect(requests, 1);
    expect((await reset.saved('A'))?.id, activeId);
    expect(cleanupCount, 0);
  });

  test('lost enqueue reply: restart replays only the durable original UUID',
      () async {
    late String original;
    rpc = (name, args) async {
      if (name == 'get_financial_data_reset') return null;
      expect(name, 'request_financial_data_reset');
      original = args['p_request_id'] as String;
      expect(args['p_expected_user_id'], 'A');
      expect((await restart().saved('A'))?.id, original);
      expect(await restart().saved('B'), isNull);
      return Completer<Object?>().future;
    };
    await expectLater(run(confirm: true), throwsA(isA<TimeoutException>()));
    reset = restart();
    final calls = <String>[];
    rpc = (name, args) async {
      calls.add(name);
      expect(args['p_request_id'], original);
      if (name == 'get_financial_data_reset') return null;
      return {'id': original, 'status': 'completed'};
    };
    expect((await run())?.status, ResetStatus.completed);
    expect(calls, ['get_financial_data_reset', 'request_financial_data_reset']);
    expect(cleanupCount, 1);
    expect(await reset.saved('A'), isNull);
  });

  test('no reset RPC can overtake an admitted outbox dispatch', () async {
    final release = Completer<int>();
    final dispatch = db.runOutboxDrain(() => release.future);
    final calls = <String>[];
    rpc = (name, args) async {
      calls.add(name);
      return name == 'get_financial_data_reset'
          ? null
          : {'id': args['p_request_id'], 'status': 'pending'};
    };
    await reset.prepare('A', () => true);
    final pending = run();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
    expect(db.activeResetOwner, 'A');
    release.complete(1);
    await dispatch;
    expect((await pending)?.status, ResetStatus.pending);
    expect(calls, ['get_financial_data_reset', 'request_financial_data_reset']);
  });

  test('adopts active ID; pending and cleanup retries never enqueue again',
      () async {
    var enqueues = 0;
    var completed = false;
    rpc = (name, args) async {
      if (enqueues == 0 && name == 'get_financial_data_reset') return null;
      if (name == 'request_financial_data_reset') {
        enqueues++;
        expect(args['p_request_id'], isNot(activeId));
      } else {
        expect(args['p_request_id'], activeId);
      }
      return {'id': activeId, 'status': completed ? 'completed' : 'pending'};
    };
    expect((await run(confirm: true))?.status, ResetStatus.pending);
    expect(cleanupCount, 0);
    completed = true;
    reset = restart();
    await expectLater(run(failCleanup: true), throwsStateError);
    expect((await reset.saved('A'))?.id, activeId);
    reset = restart();
    rpc = (_, __) => throw StateError('cleanup must work offline');
    expect((await run())?.status, ResetStatus.completed);
    expect(enqueues, 1);
    expect(cleanupCount, 2);
    expect(await reset.saved('A'), isNull);
  });

  test('failed job requires fresh confirmation before replacing its ID',
      () async {
    final ids = <String>[];
    rpc = (name, args) async {
      if (name == 'get_financial_data_reset') return null;
      expect(name, 'request_financial_data_reset');
      ids.add(args['p_request_id'] as String);
      return {'id': ids.last, 'status': 'failed', 'message': 'Rejected'};
    };
    expect((await run(confirm: true))?.message, 'Rejected');
    final failedId = ids.single;
    reset = restart();
    expect((await run())?.status, ResetStatus.failed);
    expect((await reset.saved('A'))?.id, failedId);
    await run(confirm: true);
    expect(ids.length, 2);
    expect(ids.last, isNot(failedId));
    expect(cleanupCount, 0);
  });

  test('duplicate tap and actor change during enqueue cannot start cleanup',
      () async {
    final dispatched = Completer<void>();
    final response = Completer<Object?>();
    rpc = (name, _) {
      if (name == 'get_financial_data_reset') return Future.value(null);
      dispatched.complete();
      return response.future;
    };
    final first = run(confirm: true);
    await dispatched.future;
    await expectLater(run(confirm: true), throwsStateError);
    owner = 'B';
    response.complete({'id': activeId, 'status': 'completed'});
    await expectLater(first, throwsStateError);
    expect(cleanupCount, 0);
    expect((await reset.saved('A'))?.id, activeId);
    expect(await reset.saved('B'), isNull);
  });
}
