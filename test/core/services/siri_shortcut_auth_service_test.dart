import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/siri_shortcut_auth_service.dart';

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
}
