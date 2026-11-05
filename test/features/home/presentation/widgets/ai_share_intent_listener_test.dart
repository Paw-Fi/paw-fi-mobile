import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/core/app/router.dart' show rootNavigatorKey;
import 'package:moneko/features/app_lock/data/app_lock_repository.dart';
import 'package:moneko/features/app_lock/domain/app_lock_passcode_hasher.dart';
import 'package:moneko/features/app_lock/presentation/app_lock_controller.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/ai_share_intent_listener.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'test@example.com');
}

class _Repository extends Mock implements AppLockRepository {}

class _Hasher extends Mock implements AppLockPasscodeHasher {}

class _Biometrics extends Mock implements AppLockBiometricService {}

class _Lock extends AppLockController {
  _Lock()
      : super(
            userId: 'user-1',
            repository: _Repository(),
            hasher: _Hasher(),
            biometricService: _Biometrics(),
            isEnabledFlagSet: false,
            setEnabledFlag: (_) async {});
}

class _Sharing extends ReceiveSharingIntent {
  late final initial = Completer<List<SharedMediaFile>>();
  final events = StreamController<List<SharedMediaFile>>.broadcast(sync: true);
  @override
  Future<List<SharedMediaFile>> getInitialMedia() => initial.future;
  @override
  Stream<List<SharedMediaFile>> getMediaStream() => events.stream;
  @override
  Future<void> reset() async {}
}

SharedMediaFile _media(String name,
        {SharedMediaType type = SharedMediaType.image}) =>
    SharedMediaFile(path: '/tmp/$name', type: type);

void main() {
  final originalSharing = ReceiveSharingIntent.instance;
  late _Sharing sharing;
  late _Lock lock;
  late ProviderContainer container;
  late List<List<AiSharedInputFile>> batches;
  Future<void> Function()? process;

  setUp(() {
    sharing = _Sharing();
    ReceiveSharingIntent.instance = sharing;
    lock = _Lock();
    batches = [];
    process = null;
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(_Auth.new),
      appLockControllerProvider.overrideWith((ref) => lock),
      sharedAiInputHandlerProvider
          .overrideWithValue((context, ref, {required files, onSuccess}) async {
        expect(Navigator.of(context).overlay, isNotNull);
        batches.add(files);
        await process?.call();
      }),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await sharing.events.close();
    ReceiveSharingIntent.instance = originalSharing;
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> mount(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (_, child) => AiShareIntentListener(child: child!),
        home: const Scaffold(body: Text('Home')),
      ),
    ));
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
        '$platform cold and warm images/documents enter the shared Home handler',
        (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      await mount(tester);
      sharing.initial.complete([_media('receipt.jpg')]);
      await tester.pumpAndSettle();
      sharing.events.add([
        _media('statement.pdf', type: SharedMediaType.file),
        _media('receipt.png')
      ]);
      await tester.pumpAndSettle();
      expect(
          batches
              .map((files) => files.map((file) => file.path).toList())
              .toList(),
          [
            ['/tmp/receipt.jpg'],
            ['/tmp/statement.pdf', '/tmp/receipt.png'],
          ]);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('late initial media requests a frame on an otherwise idle app',
      (tester) async {
    await mount(tester);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    sharing.initial.complete([_media('receipt.jpg')]);
    await tester.idle();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(batches, hasLength(1));
  });

  testWidgets('waits for sign-in and unlock without losing the shared files',
      (tester) async {
    container.read(authProvider.notifier).state =
        const AppUser(uid: '', email: '');
    lock.state = const AppLockState(status: AppLockStatus.locked);
    await mount(tester);
    sharing.initial
        .complete([_media('statement.csv', type: SharedMediaType.text)]);
    await tester.pumpAndSettle();
    expect(batches, isEmpty);
    container.read(authProvider.notifier).state =
        const AppUser(uid: 'user-1', email: 'test@example.com');
    await tester.pumpAndSettle();
    expect(batches, isEmpty);
    lock.state = const AppLockState.disabled();
    await tester.pumpAndSettle();
    expect(batches.single.single.path, '/tmp/statement.csv');
  });

  testWidgets('background delivery waits for foreground resume',
      (tester) async {
    await mount(tester);
    sharing.initial.complete([]);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    sharing.events.add([_media('receipt.jpg')]);
    await tester.pumpAndSettle();
    expect(batches, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(batches, hasLength(1));
  });

  testWidgets(
      'overlapping stream and initial delivery cannot analyze the same file twice',
      (tester) async {
    await mount(tester);
    sharing.events.add([_media('receipt-a.jpg')]);
    await tester.pumpAndSettle();
    sharing.events.add([_media('receipt-b.jpg')]);
    await tester.pumpAndSettle();
    sharing.initial.complete([_media('receipt-a.jpg')]);
    await tester.pumpAndSettle();
    expect(batches, hasLength(2));
  });

  testWidgets(
      'new shares wait for active analysis and links never enter file analysis',
      (tester) async {
    final gate = Completer<void>();
    process = () => gate.future;
    await mount(tester);
    sharing.initial.complete([_media('receipt.jpg')]);
    await tester.pumpAndSettle();
    sharing.events.add([
      SharedMediaFile(
          path: 'moneko://auth/callback', type: SharedMediaType.url),
      SharedMediaFile(path: 'shared prose', type: SharedMediaType.text),
      _media('statement.xlsx', type: SharedMediaType.file),
    ]);
    await tester.pumpAndSettle();
    expect(batches, hasLength(1));
    gate.complete();
    await tester.pumpAndSettle();
    expect(batches, hasLength(2));
    expect(batches.last.map((file) => file.path), ['/tmp/statement.xlsx']);
  });

  testWidgets('disposing before initial delivery does not start analysis',
      (tester) async {
    await mount(tester);
    await tester.pumpWidget(const SizedBox());
    sharing.initial.complete([_media('receipt.jpg')]);
    await tester.pumpAndSettle();
    expect(batches, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'file URIs normalize and malformed or remote URIs cannot block good siblings',
      (tester) async {
    await mount(tester);
    sharing.initial.complete([
      SharedMediaFile(
          path: 'file://remote/receipt.pdf', type: SharedMediaType.file),
      SharedMediaFile(
          path: 'file:///tmp/%E6%97%85%E8%A1%8C.pdf',
          type: SharedMediaType.file),
    ]);
    await tester.pumpAndSettle();
    expect(batches.single.single.path, '/tmp/旅行.pdf');
  });

  testWidgets(
      'receive and processing errors are visible and later shares still work',
      (tester) async {
    await mount(tester);
    sharing.initial.completeError(StateError('read failed'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to analyze'), findsOneWidget);
    process = () async => throw StateError('processing failed');
    sharing.events.add([_media('failed.jpg')]);
    await tester.pumpAndSettle();
    process = null;
    sharing.events.add([_media('next.jpg')]);
    await tester.pumpAndSettle();
    expect(batches, hasLength(2));
    expect(batches.last.single.path, '/tmp/next.jpg');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  });
}
