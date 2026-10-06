import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/core/sync/sync_coordinator.dart';
import 'package:moneko/features/home/data/repositories/ai_input_capture_repository.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory root;
  late MonekoDatabase database;
  late AiInputCaptureRepository repository;
  final capturedAt = DateTime.utc(2026, 10, 2, 23, 30);
  const target = {
    'accountType': 'household',
    'householdId': 'space',
    'isPortfolio': false,
    'accountId': 'wallet',
    'accountCurrency': 'JPY',
    'spaceLabel': '家族',
  };
  Future<AiInputCapture> capture(
          [Map<String, dynamic> input = const {'text': '昨日、家族の財布から５０円'}]) =>
      repository.capture(
        userId: 'owner',
        body: {
          'userId': 'owner',
          'date': '2026-10-03',
          'language': 'ja-JP',
          'currency': 'JPY',
          ...input
        },
        target: target,
        preferredTimezone: 'Asia/Tokyo',
        capturedAt: capturedAt,
      );
  Future<void> reopen() async {
    await database.close();
    database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open('${root.path}/capture.sqlite'));
    repository = AiInputCaptureRepository(database,
        directory: () async => Directory('${root.path}/media'));
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('moneko-ai-capture-test-');
    database = MonekoDatabase.fromExistingDatabaseForTesting(
        sqlite.sqlite3.open('${root.path}/capture.sqlite'));
    repository = AiInputCaptureRepository(database,
        directory: () async => Directory('${root.path}/media'));
  });
  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test(
      'offline text and original defaults survive disk reopen and remain owner scoped',
      () async {
    final saved = await capture();
    expect(
        await database.nextRetryableMutation(DateTime.now().toUtc()), isNull);
    await reopen();
    final restored = (await repository.pending('owner')).single;
    expect(restored.id, saved.id);
    expect(restored.body, saved.body);
    expect(restored.payload['target'], target);
    expect(restored.payload['preferredTimezone'], 'Asia/Tokyo');
    expect(restored.capturedAt, capturedAt);
    expect(await repository.pending('another-owner'), isEmpty);
    expect(
        await database.getRecentTransactions(
            userId: 'owner', householdId: null),
        isEmpty);
  });

  test(
      'audio, images and every file retain bytes and MIME metadata after restart',
      () async {
    final bytes = base64Encode([0, 1, 2, 255]);
    final inputs = [
      {
        'audio': {'data': bytes, 'contentType': 'audio/aac'}
      },
      {
        'image': {'data': bytes, 'contentType': 'image/png'}
      },
      {
        'attachments': [
          {
            'data': bytes,
            'contentType': 'application/pdf',
            'filename': '領収書.pdf'
          },
          {'data': bytes, 'contentType': 'text/csv', 'filename': '支出.csv'},
        ]
      },
    ];
    final ids = <String>[];
    for (final input in inputs) {
      ids.add((await capture(input)).id);
    }
    await reopen();
    final restored = await repository.pending('owner');
    expect(restored.map((item) => item.id).toSet(), ids.toSet());
    for (var index = 0; index < restored.length; index++) {
      final item = restored.firstWhere((item) => item.id == ids[index]);
      expect(item.body.containsKey(inputs[index].keys.single), isFalse);
      expect(
          await repository.requestBody(item), {...item.body, ...inputs[index]});
      await repository.removeMaterializedMedia(item);
      expect(await Directory('${root.path}/media/${item.id}').exists(), isTrue);
    }
  });

  test('invalid media leaves neither a capture nor partially written files',
      () async {
    await expectLater(
        capture({
          'attachments': [
            {
              'data': base64Encode([1]),
              'contentType': 'text/csv'
            },
            {'data': 'invalid base64', 'contentType': 'application/pdf'},
          ]
        }),
        throwsFormatException);
    expect(await repository.pending('owner'), isEmpty);
    expect(await Directory('${root.path}/media').list().toList(), isEmpty);
  });

  test(
      'questions and custom answers survive disk reopen and stale checkpoints are rejected',
      () async {
    final original = await capture();
    final asked = await repository.checkpoint(original, {
      'question': {
        'question': '誰の財布ですか？',
        'choices': ['私', 'アリス'],
        'allowCustomResponse': true
      },
      'answers': [
        {'question': '金額？', 'answer': '５０円'}
      ],
    });
    await expectLater(
        repository.checkpoint(original, {'answers': []}), throwsStateError);
    await reopen();
    final restored = (await repository.pending('owner')).single;
    expect(restored.payload, asked.payload);
  });

  test('explicit cancellation survives disk reopen and removes captured media',
      () async {
    final saved = await capture({
      'audio': {
        'data': base64Encode([1, 2, 3]),
        'contentType': 'audio/aac'
      }
    });
    final changed = database.aiInputChanges.first;
    await repository.cancel(saved);
    await changed;
    expect(await Directory('${root.path}/media/${saved.id}').exists(), isFalse);
    await reopen();
    expect(await repository.pending('owner'), isEmpty);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusCancelled);
    expect(
        await database.nextRetryableMutation(DateTime.now().toUtc()), isNull);
    expect(await database.holdAiInputForForeground(saved.mutation), isFalse);
    await expectLater(
        repository.checkpoint(saved, {'answers': []}), throwsStateError);
    expect(
        await database.getRecentTransactions(
            userId: 'owner', householdId: null),
        isEmpty);
  });

  test('stale cancellation cannot discard a newer checkpoint or its media',
      () async {
    final original = await capture({
      'image': {
        'data': base64Encode([1, 2, 3]),
        'contentType': 'image/png'
      }
    });
    final newer = await repository.checkpoint(original, {
      'answers': [
        {'question': 'どの財布？', 'answer': '私の財布'}
      ]
    });
    await expectLater(repository.cancel(original), throwsStateError);
    await reopen();
    final restored = (await repository.pending('owner')).single;
    expect(restored.payload, newer.payload);
    expect((await repository.requestBody(restored))['image'], {
      'data': base64Encode([1, 2, 3]),
      'contentType': 'image/png'
    });
    await repository.cancel(restored);
    await reopen();
    expect(await repository.pending('owner'), isEmpty);
  });

  test('media cleanup failure cannot make a cancelled capture retryable',
      () async {
    final saved = await capture();
    repository = AiInputCaptureRepository(database,
        directory: () async => throw const FileSystemException('unavailable'));
    await repository.cancel(saved);
    await reopen();
    expect(await repository.pending('owner'), isEmpty);
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusCancelled);
  });

  test(
      'ready groups atomically hand off, skip replayed groups and finish after disk reopen',
      () async {
    var saved = await capture({
      'image': {
        'data': base64Encode([1, 2]),
        'contentType': 'image/jpeg'
      }
    });
    final response = {
      'success': true,
      'data': {
        'items': [
          {'amount': 50},
          {'amount': 20}
        ]
      }
    };
    saved = await repository.checkpoint(saved, {
      'readyResponse': response,
      'destinationKeys': ['first', 'second'],
      'completedDestinations': <String>[],
    });
    final entry = ExpenseEntry(
        id: saved.transactionId(0),
        userId: 'owner',
        date: DateTime(2026, 10, 3),
        amountCents: 5000,
        currency: 'JPY',
        category: 'food',
        createdAt: capturedAt,
        merchant: '小商店');
    Future<bool> handoff(String key, ExpenseEntry row) =>
        database.materializeAiInputDestination(
          clientMutationId: saved.mutation.clientMutationId,
          userId: 'owner',
          expectedReadyResponseJson: jsonEncode(response),
          destinationKey: key,
          mutations: [
            (
              entry: row,
              clientMutationId: 'mobile:${row.id}',
              operation: 'create',
              payload: {
                'functionName': 'save-expense',
                'requestBody': {
                  'userId': 'owner',
                  'merchant': '小商店',
                  'clientCreatedAt': capturedAt.toIso8601String()
                }
              }
            )
          ],
        );
    expect(await handoff('first', entry), isTrue);
    await reopen();
    expect((await repository.pending('owner')).single.completedDestinations,
        ['first']);
    expect(await handoff('first', entry.copyWith(amountCents: 9900)), isFalse);
    expect(
        (await database.getRecentTransactions(
                userId: 'owner', householdId: null))
            .single
            .amountCents,
        5000);
    expect(
        await handoff('second',
            entry.copyWith(id: saved.transactionId(1), amountCents: 2000)),
        isTrue);
    expect(await repository.pending('owner'), isEmpty);
    expect(
        (await database.getOutboxMutations())
            .where((row) => row.entityType == 'transaction')
            .length,
        2);
    await repository.removeMaterializedMedia(saved);
    expect(await Directory('${root.path}/media/${saved.id}').exists(), isFalse);
  });

  test(
      'a failed later row rolls back every handoff write and leaves the source retryable',
      () async {
    final saved = await repository.checkpoint(await capture(), {
      'readyResponse': {'success': true},
      'destinationKeys': ['only'],
    });
    final entry = ExpenseEntry(
        id: saved.transactionId(0),
        userId: 'owner',
        date: DateTime(2026, 10, 3),
        amountCents: 5000,
        currency: 'JPY',
        category: 'food',
        createdAt: capturedAt);
    final revision = database.transactionRevision;
    await expectLater(
        database.materializeAiInputDestination(
          clientMutationId: saved.mutation.clientMutationId,
          userId: 'owner',
          expectedReadyResponseJson: jsonEncode(saved.readyResponse),
          destinationKey: 'only',
          mutations: [
            (
              entry: entry,
              clientMutationId: 'first',
              operation: 'create',
              payload: <String, dynamic>{}
            ),
            (
              entry: entry.copyWith(id: saved.transactionId(1)),
              clientMutationId: 'second',
              operation: 'create',
              payload: <String, dynamic>{'notSerializable': () {}}
            ),
          ],
        ),
        throwsA(isA<JsonUnsupportedObjectError>()));
    expect(database.transactionRevision, revision);
    await reopen();
    expect(
        await database.getRecentTransactions(
            userId: 'owner', householdId: null),
        isEmpty);
    expect(await database.getOutboxMutations(), hasLength(1));
    expect((await repository.pending('owner')).single.completedDestinations,
        isEmpty);
  });

  test('wrong owner or changed ready result cannot create transactions',
      () async {
    final saved = await repository.checkpoint(await capture(), {
      'readyResponse': {'success': true},
      'destinationKeys': ['only'],
    });
    final entry = ExpenseEntry(
        id: saved.transactionId(0),
        userId: 'owner',
        date: DateTime(2026, 10, 3),
        amountCents: 5000,
        currency: 'JPY',
        category: 'food',
        createdAt: capturedAt);
    for (final values in [
      ('other', jsonEncode(saved.readyResponse)),
      ('owner', '{}')
    ]) {
      await expectLater(
          database.materializeAiInputDestination(
            clientMutationId: saved.mutation.clientMutationId,
            userId: values.$1,
            expectedReadyResponseJson: values.$2,
            destinationKey: 'only',
            mutations: [
              (
                entry: entry,
                clientMutationId: 'mobile:${entry.id}',
                operation: 'create',
                payload: {}
              )
            ],
          ),
          throwsStateError);
    }
    expect(
        await database.getRecentTransactions(
            userId: 'owner', householdId: null),
        isEmpty);
    expect((await repository.pending('owner')).single.completedDestinations,
        isEmpty);
  });

  test(
      'holding legacy analysis does not block financial mutations or mark capture synced',
      () async {
    await database.enqueueMutation(
        clientMutationId: 'legacy',
        entityType: 'ai_input',
        entityId: 'legacy',
        operation: 'analyze_ai_input',
        payload: {
          'userId': 'owner',
          'body': {'text': '買い物'}
        });
    await database.enqueueMutation(
        clientMutationId: 'financial',
        entityType: 'wallet',
        entityId: 'wallet',
        operation: 'invoke_function',
        payload: {});
    final dispatched = <String>[];
    final coordinator = SyncCoordinator(
        database: database,
        dispatchMutation: (mutation) async {
          dispatched.add(mutation.clientMutationId);
          if (mutation.entityType == 'ai_input') {
            await database.holdAiInputForForeground(mutation);
          }
        });
    await coordinator.drainOutbox();
    expect(dispatched, ['legacy', 'financial']);
    final pending = (await repository.pending('owner')).single;
    expect(pending.mutation.status, 'awaiting_ai');
    expect(pending.transactionId(2), 'legacy-2');
    expect(
        await database.nextRetryableMutation(DateTime.now().toUtc()), isNull);
  });

  test(
      'AI child writes survive extended offline retries and terminal errors still roll back',
      () async {
    var now = DateTime.now().toUtc();
    final entry = ExpenseEntry(
        id: 'optimistic-ai',
        userId: 'owner',
        date: DateTime(2026, 10, 3),
        amountCents: 5000,
        currency: 'JPY',
        category: 'food',
        createdAt: capturedAt);
    await database.writeOptimisticTransaction(
        entry: entry,
        clientMutationId: 'child',
        operation: 'create',
        payload: {
          'aiCaptureId': 'capture',
          'functionName': 'save-expense',
          'requestBody': {'userId': 'owner'}
        });
    var terminal = false;
    final coordinator = SyncCoordinator(
      database: database,
      now: () => now,
      dispatchMutation: (_) async {
        if (terminal) {
          throw const NonRetryableLocalMutationException('wallet deleted');
        }
        throw const SocketException('offline');
      },
      onMutationCancelled: (mutation, error) async {
        await database.rollbackOptimisticTransaction(
            optimisticId: mutation.entityId,
            clientMutationId: mutation.clientMutationId,
            error: error);
      },
    );
    for (var attempt = 1; attempt <= 10; attempt++) {
      await coordinator.drainOutbox();
      final mutation = (await database.getOutboxMutations()).single;
      expect(mutation.status, localMutationStatusFailed);
      expect(mutation.attemptCount, attempt);
      expect(
          await database.getRecentTransactions(
              userId: 'owner', householdId: null),
          hasLength(1));
      now = now.add(const Duration(minutes: 6));
    }
    terminal = true;
    await coordinator.drainOutbox();
    expect((await database.getOutboxMutations()).single.status,
        localMutationStatusCancelled);
    expect(
        await database.getRecentTransactions(
            userId: 'owner', householdId: null),
        isEmpty);
  });

  test(
      'resume controller serializes captures, retries on wake and fences disposed owners',
      () {
    final controller = AiInputResumeController();
    expect(controller.tryStart('first'), isTrue);
    expect(controller.tryStart('second'), isFalse);
    controller.wake();
    expect(controller.tryStart('first'), isFalse);
    controller.finish('first');
    expect(controller.tryStart('first'), isFalse);
    expect(controller.tryStart('second'), isTrue);
    controller.finish('second');
    controller.wake();
    expect(controller.tryStart('first'), isTrue);
    controller.dispose();
    controller.finish('first');
    expect(controller.tryStart('second'), isFalse);
  });

  test('a shared receipt survives until its last pending child finishes',
      () async {
    final receipt = File('${root.path}/receipt.jpg');
    await receipt.writeAsBytes([1, 2, 3], flush: true);
    final payload = <String, dynamic>{'localReceiptImagePath': receipt.path};
    for (final id in ['first', 'second']) {
      await database.enqueueMutation(
        clientMutationId: id,
        entityType: 'transaction',
        entityId: id,
        operation: 'create',
        payload: payload,
      );
    }
    final children = await database.getOutboxMutations();
    final first =
        children.firstWhere((child) => child.clientMutationId == 'first');
    final second =
        children.firstWhere((child) => child.clientMutationId == 'second');
    await deleteQueuedReceiptIfUnused(database, first, payload);
    expect(await receipt.readAsBytes(), [1, 2, 3]);
    await database.markMutationSynced('first');
    await deleteQueuedReceiptIfUnused(database, second, payload);
    expect(await receipt.exists(), isFalse);
  });

  test('an older completed request cannot delete a newer receipt reference',
      () async {
    final receipt = File('${root.path}/receipt.jpg');
    await receipt.writeAsBytes([1, 2, 3], flush: true);
    final original = <String, dynamic>{'localReceiptImagePath': receipt.path};
    Future<void> enqueue(Map<String, dynamic> payload) =>
        database.enqueueMutation(
          clientMutationId: 'child',
          entityType: 'transaction',
          entityId: 'child',
          operation: 'create',
          payload: payload,
        );
    await enqueue(original);
    final snapshot = (await database.getOutboxMutations()).single;
    await enqueue({...original, 'revision': 2});
    await deleteQueuedReceiptIfUnused(database, snapshot, original);
    expect(await receipt.readAsBytes(), [1, 2, 3]);
  });

  test(
      'AI saves retry recoverable statuses and reject authoritative client errors',
      () {
    for (final status in [200, 401, 408, 425, 429, 500, 503]) {
      expect(isTerminalAiCaptureStatus(status), isFalse, reason: '$status');
    }
    for (final status in [400, 403, 404, 409, 413, 422]) {
      expect(isTerminalAiCaptureStatus(status), isTrue, reason: '$status');
    }
  });
}
