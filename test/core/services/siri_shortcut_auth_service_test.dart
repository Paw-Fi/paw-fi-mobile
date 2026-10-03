import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuth extends Mock implements GoTrueClient {}

Session _session({String userId = 'user-1', bool expired = false}) => Session(
      accessToken: expired ? 'expired-token' : 'fresh-token',
      tokenType: 'bearer',
      user: User(
        id: userId,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-03T00:00:00Z',
      ),
    )..expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        (expired ? -3600 : 3600);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moneko/siri_shortcut_auth');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
      'syncAuthContextAndPendingWalletCaptures syncs auth before pending queue',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final methodCalls = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call.method);
      if (call.method == 'syncPendingWalletCaptures') {
        return <String, dynamic>{'attempted': 1, 'synced': 1, 'remaining': 0};
      }
      return null;
    });

    final result = await SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      userId: 'user-1',
      expiresAt: 123,
    );

    expect(methodCalls, ['syncAuthContext', 'syncPendingWalletCaptures']);
    expect(result, containsPair('synced', 1));
  });

  test('syncAuthContextAndPendingWalletCaptures coalesces concurrent syncs',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final authSyncCompleter = Completer<void>();
    final methodCalls = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call.method);
      if (call.method == 'syncAuthContext') {
        await authSyncCompleter.future;
        return null;
      }
      if (call.method == 'syncPendingWalletCaptures') {
        return <String, dynamic>{'attempted': 1, 'synced': 1, 'remaining': 0};
      }
      return null;
    });

    final first = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      userId: 'user-1',
      expiresAt: 123,
    );
    final second = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      userId: 'user-1',
      expiresAt: 123,
    );

    authSyncCompleter.complete();
    await Future.wait([first, second]);

    expect(methodCalls, ['syncAuthContext', 'syncPendingWalletCaptures']);
  });

  test('syncAuthContextAndPendingWalletCaptures reruns with newer credentials',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final authSyncCompleter = Completer<void>();
    final accessTokens = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'syncAuthContext') {
        final args = call.arguments as Map<Object?, Object?>;
        accessTokens.add(args['accessToken'] as String);
        if (accessTokens.length == 1) {
          await authSyncCompleter.future;
        }
        return null;
      }
      if (call.method == 'syncPendingWalletCaptures') {
        return <String, dynamic>{'attempted': 1, 'synced': 1, 'remaining': 0};
      }
      return null;
    });

    final first = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'old-access-token',
      refreshToken: 'old-refresh-token',
      userId: 'user-1',
      expiresAt: 123,
    );
    final second = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'new-access-token',
      refreshToken: 'new-refresh-token',
      userId: 'user-1',
      expiresAt: 456,
    );

    authSyncCompleter.complete();
    await Future.wait([first, second]);

    expect(accessTokens, ['old-access-token', 'new-access-token']);
  });

  test('syncAuthContextAndPendingWalletCaptures keeps queued newer credentials',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final authSyncCompleter = Completer<void>();
    final accessTokens = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'syncAuthContext') {
        final args = call.arguments as Map<Object?, Object?>;
        accessTokens.add(args['accessToken'] as String);
        if (accessTokens.length == 1) {
          await authSyncCompleter.future;
        }
        return null;
      }
      if (call.method == 'syncPendingWalletCaptures') {
        return <String, dynamic>{'attempted': 1, 'synced': 1, 'remaining': 0};
      }
      return null;
    });

    final first = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'old-access-token',
      refreshToken: 'old-refresh-token',
      userId: 'user-1',
      expiresAt: 123,
    );
    final second = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'new-access-token',
      refreshToken: 'new-refresh-token',
      userId: 'user-1',
      expiresAt: 456,
    );
    final third = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'old-access-token',
      refreshToken: 'old-refresh-token',
      userId: 'user-1',
      expiresAt: 123,
    );

    authSyncCompleter.complete();
    await Future.wait([first, second, third]);

    expect(accessTokens, ['old-access-token', 'new-access-token']);
  });

  test(
      'syncAuthContextAndPendingWalletCaptures runs queued newer credentials after failure',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final authSyncCompleter = Completer<void>();
    final accessTokens = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'syncAuthContext') {
        final args = call.arguments as Map<Object?, Object?>;
        accessTokens.add(args['accessToken'] as String);
        if (accessTokens.length == 1) {
          await authSyncCompleter.future;
          throw PlatformException(code: 'stale_token');
        }
        return null;
      }
      if (call.method == 'syncPendingWalletCaptures') {
        return <String, dynamic>{'attempted': 1, 'synced': 1, 'remaining': 0};
      }
      return null;
    });

    final first = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'old-access-token',
      refreshToken: 'old-refresh-token',
      userId: 'user-1',
      expiresAt: 123,
    );
    final second = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'new-access-token',
      refreshToken: 'new-refresh-token',
      userId: 'user-1',
      expiresAt: 456,
    );

    authSyncCompleter.complete();
    await Future.wait([first, second]);

    expect(accessTokens, ['old-access-token', 'new-access-token']);
  });

  test('clearAuthContext prevents in-flight sync from syncing pending captures',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final authSyncCompleter = Completer<void>();
    final methodCalls = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call.method);
      if (call.method == 'syncAuthContext') {
        await authSyncCompleter.future;
      }
      if (call.method == 'syncPendingWalletCaptures') {
        return <String, dynamic>{'attempted': 1, 'synced': 1, 'remaining': 0};
      }
      return null;
    });

    final sync = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      userId: 'user-1',
      expiresAt: 123,
    );

    final clear = SiriShortcutAuthService.instance.clearAuthContext();
    await Future<void>.delayed(Duration.zero);
    authSyncCompleter.complete();
    await Future.wait([sync, clear]);

    expect(methodCalls, ['syncAuthContext', 'clearAuthContext']);
  });

  test('clearAuthContext waits for pending sync already in progress', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final pendingSyncStarted = Completer<void>();
    final pendingSyncCompleter = Completer<void>();
    final methodCalls = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call.method);
      if (call.method == 'syncPendingWalletCaptures') {
        pendingSyncStarted.complete();
        await pendingSyncCompleter.future;
        return <String, dynamic>{'attempted': 1, 'synced': 1, 'remaining': 0};
      }
      return null;
    });

    final sync = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      userId: 'user-1',
      expiresAt: 123,
    );
    await pendingSyncStarted.future;

    final clear = SiriShortcutAuthService.instance.clearAuthContext();
    await Future<void>.delayed(Duration.zero);

    expect(methodCalls, ['syncAuthContext', 'syncPendingWalletCaptures']);

    pendingSyncCompleter.complete();
    await Future.wait([sync, clear]);

    expect(methodCalls, [
      'syncAuthContext',
      'syncPendingWalletCaptures',
      'clearAuthContext',
    ]);
  });

  test('syncAuthContextAndPendingWalletCaptures waits for clearAuthContext',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final clearCompleter = Completer<void>();
    final methodCalls = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call.method);
      if (call.method == 'clearAuthContext') {
        await clearCompleter.future;
      }
      if (call.method == 'syncPendingWalletCaptures') {
        return <String, dynamic>{'attempted': 1, 'synced': 1, 'remaining': 0};
      }
      return null;
    });

    final clear = SiriShortcutAuthService.instance.clearAuthContext();
    await Future<void>.delayed(Duration.zero);
    final sync = SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      userId: 'user-1',
      expiresAt: 123,
    );
    await Future<void>.delayed(Duration.zero);

    expect(methodCalls, ['clearAuthContext']);

    clearCompleter.complete();
    await Future.wait([clear, sync]);

    expect(methodCalls, [
      'clearAuthContext',
      'syncAuthContext',
      'syncPendingWalletCaptures',
    ]);
  });

  test('syncAuthContextAndPendingWalletCaptures is a no-op off iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final methodCalls = <String>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call.method);
      return null;
    });

    final result = await SiriShortcutAuthService.instance
        .syncAuthContextAndPendingWalletCaptures(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      userId: 'user-1',
      expiresAt: 123,
    );

    expect(methodCalls, isEmpty);
    expect(result, isEmpty);
  });

  group('replay with the current Flutter session', () {
    late _MockAuth auth;
    late Session? session;
    late List<String> calls;
    late List<Map<Object?, Object?>> nativeAuth;
    late Map<String, dynamic> syncResult;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      auth = _MockAuth();
      session = _session();
      calls = [];
      nativeAuth = [];
      syncResult = {'attempted': 1, 'synced': 1, 'remaining': 0};
      when(() => auth.currentSession).thenAnswer((_) => session);
      when(() => auth.refreshSession()).thenAnswer((_) async {
        calls.add('refresh');
        session = _session();
        return AuthResponse(session: session);
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'syncAuthContext') {
          nativeAuth.add(call.arguments as Map<Object?, Object?>);
        }
        return call.method == 'syncPendingWalletCaptures' ? syncResult : null;
      });
    });

    Future<Map<String, dynamic>> replay() => SiriShortcutAuthService.instance
            .syncPendingWalletCapturesWithCurrentSession(
          auth: auth,
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon-key',
          userId: 'user-1',
        );

    test('refreshes an expired session before dispatch and publishes success',
        () async {
      session = _session(expired: true);
      final synced =
          SiriShortcutAuthService.instance.walletCapturesSynced.first;
      expect(await replay(), containsPair('synced', 1));
      expect(await synced, 'user-1');
      expect(
          calls, ['refresh', 'syncAuthContext', 'syncPendingWalletCaptures']);
      expect(nativeAuth.single['accessToken'], 'fresh-token');
      expect(nativeAuth.single.containsKey('refreshToken'), isFalse);
    });

    test('retains offline work when session refresh fails', () async {
      session = _session(expired: true);
      when(() => auth.refreshSession()).thenThrow(StateError('offline'));
      await expectLater(replay(), throwsStateError);
      expect(calls, isEmpty);
    });

    test('does not publish old credentials after an account switch', () async {
      session = _session(expired: true);
      when(() => auth.refreshSession()).thenAnswer((_) async {
        session = _session(userId: 'user-2');
        return AuthResponse(session: session);
      });
      expect(await replay(), isEmpty);
      expect(calls, isEmpty);
    });

    test('retries a rejected token once with refreshed credentials', () async {
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'syncPendingWalletCaptures') {
          attempts++;
          return attempts == 1
              ? {'synced': 0, 'remaining': 1, 'requiresSessionRefresh': true}
              : {'synced': 1, 'remaining': 0};
        }
        return null;
      });
      expect(await replay(), containsPair('synced', 1));
      expect(calls, [
        'syncAuthContext',
        'syncPendingWalletCaptures',
        'refresh',
        'syncAuthContext',
        'syncPendingWalletCaptures',
      ]);
    });

    test('does not loop indefinitely on a persistently rejected session',
        () async {
      syncResult = {
        'synced': 0,
        'remaining': 1,
        'requiresSessionRefresh': true,
      };
      expect(await replay(), containsPair('remaining', 1));
      verify(() => auth.refreshSession()).called(1);
      expect(
          calls.where((call) => call == 'syncPendingWalletCaptures').length, 2);
    });

    test('successful replay completes before downstream transaction refresh',
        () async {
      final completed = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'syncPendingWalletCaptures') {
          await completed.future;
          return syncResult;
        }
        return null;
      });
      final replayAndPull = () async {
        await replay();
        calls.add('pull-delta');
      }();
      await pumpEventQueue();
      expect(calls, ['syncAuthContext', 'syncPendingWalletCaptures']);
      completed.complete();
      await replayAndPull;
      expect(calls.last, 'pull-delta');
    });

    test('a failed replay can be retried with the same account', () async {
      syncResult = {'synced': 0, 'remaining': 1};
      expect(await replay(), containsPair('remaining', 1));
      syncResult = {'synced': 1, 'remaining': 0};
      expect(await replay(), containsPair('synced', 1));
      expect(
          calls.where((call) => call == 'syncPendingWalletCaptures').length, 2);
    });
  });
}
