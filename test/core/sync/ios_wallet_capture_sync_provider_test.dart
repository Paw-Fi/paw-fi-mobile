import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/user_financial_cache_cleanup.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';
import 'package:moneko/core/sync/ios_wallet_capture_sync_provider.dart';
import 'package:moneko/core/ui/notifications/app_mutation_error_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuth extends Mock implements GoTrueClient {}

class _FakeAppAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user-1', email: 'user@example.com');
}

void main() {
  const channel = MethodChannel('moneko/siri_shortcut_auth');
  TestWidgetsFlutterBinding.ensureInitialized();
  late GoTrueClient auth;
  late ProviderContainer container;
  late ProviderSubscription<Future<void> Function(String)> subscription;
  late List<String> calls;
  late int pending;
  late bool offline;

  void mountSyncProvider() {
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(_FakeAppAuth.new),
      iosWalletCaptureAuthProvider.overrideWithValue(auth),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(true)),
    ]);
    subscription = container.listen(iosWalletCaptureSyncProvider, (_, __) {});
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    dotenv.testLoad(fileInput: '''
SUPABASE_URL=https://example.supabase.co
SUPABASE_ANON_KEY=anon-key
''');
    final mock = _MockAuth();
    final session = Session(
      accessToken: 'fresh-token',
      tokenType: 'bearer',
      user: const User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-03T00:00:00Z',
      ),
    )..expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    when(() => mock.currentSession).thenReturn(session);
    auth = mock;
    calls = [];
    pending = 1;
    offline = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'getStatus') return {'pendingWalletCaptures': pending};
      if (call.method == 'syncPendingWalletCaptures') {
        if (offline) return {'synced': 0, 'remaining': pending};
        final synced = pending;
        pending = 0;
        return {'synced': synced, 'remaining': 0};
      }
      return null;
    });
  });

  tearDown(() {
    subscription.close();
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('terminal Siri replay rejection emits an app-level error for its actor',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'syncPendingWalletCaptures') {
        return {
          'synced': 0,
          'remaining': 0,
          'failedSiriCaptures': [
            {'id': 'siri-capture-1', 'userId': 'user-1'},
          ],
        };
      }
      return null;
    });
    mountSyncProvider();
    await container.read(iosWalletCaptureSyncProvider)('user-1');
    await pumpEventQueue();
    expect(container.read(appMutationErrorProvider)?.id, 'siri-capture-1');
    expect(container.read(appMutationErrorProvider)?.feature, 'transaction');
    expect(container.read(iosWalletCaptureSyncRevisionProvider), 0);
  });

  test('terminal Siri replay errors from another actor are ignored', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'syncPendingWalletCaptures') {
        return {
          'synced': 0,
          'remaining': 0,
          'failedSiriCaptures': [
            {'id': 'siri-capture-2', 'userId': 'user-2'},
          ],
        };
      }
      return null;
    });
    mountSyncProvider();
    await container.read(iosWalletCaptureSyncProvider)('user-1');
    await pumpEventQueue();
    expect(container.read(appMutationErrorProvider), isNull);
  });

  test('startup Siri failure survives until the shell mounts', () async {
    final service = SiriShortcutAuthService.instance;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'syncPendingWalletCaptures') {
        return {
          'synced': 0,
          'failedSiriCaptures': [
            {'id': 'startup-siri-failure', 'userId': 'user-1'},
          ],
        };
      }
      return null;
    });
    await service.syncPendingWalletCapturesWithCurrentSession(
      auth: auth,
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      userId: 'user-1',
    );
    expect(service.pendingSiriFailures('user-1').map((event) => event.id),
        contains('startup-siri-failure'));
    mountSyncProvider();
    await pumpEventQueue();
    expect(
        container.read(appMutationErrorProvider)?.id, 'startup-siri-failure');
    expect(service.pendingSiriFailures('user-1'), isEmpty);
  });

  test('retries queued offline captures while foregrounded', () {
    fakeAsync((async) {
      mountSyncProvider();
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      offline = true;
      unawaited(container.read(iosWalletCaptureSyncProvider)('user-1'));
      async.flushMicrotasks();
      expect(pending, 1);
      expect(container.read(iosWalletCaptureSyncRevisionProvider), 0);
      offline = false;
      async.elapse(networkReachabilityCheckInterval);
      async.flushMicrotasks();
      expect(pending, 0);
      expect(container.read(iosWalletCaptureSyncRevisionProvider), 1);
    });
  });

  test('does not replay from the retry timer while backgrounded', () {
    fakeAsync((async) {
      mountSyncProvider();
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      async.elapse(networkReachabilityCheckInterval);
      expect(calls, isEmpty);
      expect(pending, 1);
    });
  });

  test('an empty queue does not dispatch network replay', () {
    fakeAsync((async) {
      mountSyncProvider();
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      pending = 0;
      async.elapse(networkReachabilityCheckInterval);
      async.flushMicrotasks();
      expect(calls, ['getStatus']);
    });
  });

  test('does not replay when backgrounded during the queue status check', () {
    fakeAsync((async) {
      final status = Completer<Map<String, dynamic>>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'getStatus') return status.future;
        return null;
      });
      mountSyncProvider();
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      async.elapse(networkReachabilityCheckInterval);
      async.flushMicrotasks();
      expect(calls, ['getStatus']);
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      status.complete({'pendingWalletCaptures': 1});
      async.flushMicrotasks();
      expect(calls, ['getStatus']);
      expect(pending, 1);
    });
  });

  test('replay is blocked during financial cache cleanup or for another actor',
      () async {
    mountSyncProvider();
    container.read(userFinancialCacheCleanupInProgressProvider.notifier).state =
        true;
    await container.read(iosWalletCaptureSyncProvider)('user-1');
    container.read(userFinancialCacheCleanupInProgressProvider.notifier).state =
        false;
    await container.read(iosWalletCaptureSyncProvider)('user-2');
    expect(calls, isEmpty);
    expect(pending, 1);
  });

  test('auth-triggered native success signals a mounted shell refresh',
      () async {
    mountSyncProvider();
    await SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'fresh-token',
      userId: 'user-1',
      expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    );
    await pumpEventQueue();
    expect(container.read(iosWalletCaptureSyncRevisionProvider), 1);
  });
}
