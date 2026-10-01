import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/sync/foreground_reconciler.dart';

void main() {
  test('a failed serialized phase does not block a queued newer revision',
      () async {
    final reconciler = ForegroundReconciler<int>();
    final gate = Completer<void>();
    var newerCalls = 0;
    final older = reconciler.run(
      identity: 1,
      serializationKey: 'user-1',
      isActive: () => true,
      phases: [() => gate.future],
    );
    final failure = expectLater(older, throwsStateError);
    final newer = reconciler.run(
      identity: 2,
      serializationKey: 'user-1',
      isActive: () => true,
      phases: [
        () async {
          newerCalls++;
        }
      ],
    );
    await pumpEventQueue();
    expect(newerCalls, 0);
    gate.completeError(StateError('offline'));
    await failure;
    await newer;
    expect(newerCalls, 1);
  });

  test(
      'newer sync revisions queue behind the same user without being suppressed',
      () async {
    final reconciler = ForegroundReconciler<(String, int)>();
    final gate = Completer<void>();
    final calls = <String>[];
    final older = reconciler.run(
      identity: ('user-1', 1),
      serializationKey: 'user-1',
      isActive: () => true,
      phases: [
        () async {
          calls.add('old-start');
          await gate.future;
          calls.add('old-end');
        }
      ],
    );
    final newer = reconciler.run(
      identity: ('user-1', 2),
      serializationKey: 'user-1',
      isActive: () => true,
      phases: [
        () async {
          calls.add('new');
        }
      ],
    );
    await pumpEventQueue();
    expect(calls, ['old-start']);
    gate.complete();
    await Future.wait([older, newer]);
    expect(calls, ['old-start', 'old-end', 'new']);
  });

  test('shares every downstream phase for the same scope and revision',
      () async {
    final reconciler = ForegroundReconciler<(String, int)>();
    final gate = Completer<void>();
    final calls = [0, 0, 0];
    final phases = <Future<void> Function()>[
      () async {
        calls[0]++;
        await gate.future;
      },
      () async => calls[1]++,
      () async => calls[2]++,
    ];
    final first = reconciler.run(
      identity: ('personal', 1),
      isActive: () => true,
      phases: phases,
    );
    final second = reconciler.run(
      identity: ('personal', 1),
      isActive: () => true,
      phases: phases,
    );
    expect(calls, [1, 0, 0]);
    gate.complete();
    await Future.wait([first, second]);
    expect(calls, [1, 1, 1]);
    await reconciler.run(
      identity: ('personal', 1),
      isActive: () => true,
      phases: phases,
    );
    expect(calls, [2, 2, 2]);
  });

  test('a newer revision or another scope cannot join an older request',
      () async {
    final reconciler = ForegroundReconciler<(String, int)>();
    final old = Completer<void>();
    final calls = <(String, int)>[];
    Future<void> run((String, int) identity, {bool held = false}) =>
        reconciler.run(
          identity: identity,
          isActive: () => true,
          phases: [
            () async {
              calls.add(identity);
              if (held) await old.future;
            }
          ],
        );
    final first = run(('personal', 1), held: true);
    await run(('personal', 2));
    await run(('household', 1));
    expect(calls, [('personal', 1), ('personal', 2), ('household', 1)]);
    old.complete();
    await first;
  });

  test('a surviving caller retries phases skipped by a cancelled owner',
      () async {
    final reconciler = ForegroundReconciler<String>();
    final gate = Completer<void>();
    var ownerActive = true;
    var skippedPhaseCalls = 0;
    var survivingPhaseCalls = 0;
    final owner = reconciler.run(
      identity: 'scope',
      isActive: () => ownerActive,
      phases: [() => gate.future, () async => skippedPhaseCalls++],
    );
    final survivor = reconciler.run(
      identity: 'scope',
      isActive: () => true,
      phases: [() async => survivingPhaseCalls++],
    );
    ownerActive = false;
    gate.complete();
    await Future.wait([owner, survivor]);
    expect(skippedPhaseCalls, 0);
    expect(survivingPhaseCalls, 1);
  });

  test('an inactive caller does no work and a failed phase can be retried',
      () async {
    final reconciler = ForegroundReconciler<String>();
    var calls = 0;
    await reconciler.run(
      identity: 'scope',
      isActive: () => false,
      phases: [() async => calls++],
    );
    expect(calls, 0);
    await expectLater(
        reconciler.run(
          identity: 'scope',
          isActive: () => true,
          phases: [() async => throw StateError('offline')],
        ),
        throwsStateError);
    await reconciler.run(
      identity: 'scope',
      isActive: () => true,
      phases: [() async => calls++],
    );
    expect(calls, 1);
  });
}
