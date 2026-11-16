import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/notification_capture_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuth extends Mock implements GoTrueClient {}

Session _session({
  String userId = 'user-1',
  String accessToken = 'fresh-token',
  int expiresIn = 3600,
}) =>
    Session(
      accessToken: accessToken,
      refreshToken: 'flutter-owned-refresh-token',
      tokenType: 'bearer',
      user: User(
        id: userId,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-03T00:00:00Z',
      ),
    )..expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moneko/notification_capture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late NotificationCaptureService service;
  late _MockAuth auth;
  Session? current;
  late List<MethodCall> nativeCalls;

  // Incoming native messages must use the real Flutter channel handler, not the
  // outbound mock. No Supabase singleton or network client is initialized here.
  Future<Object?> nativeCall(String method, Object? arguments) {
    final response = Completer<Object?>();
    ServicesBinding.instance.channelBuffers.push(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, arguments)),
      (data) {
        try {
          if (data == null) throw MissingPluginException(method);
          response.complete(channel.codec.decodeEnvelope(data));
        } catch (error, stackTrace) {
          response.completeError(error, stackTrace);
        }
      },
    );
    return response.future;
  }

  Future<Map<Object?, Object?>> request({
    String userId = 'user-1',
    bool forceRefresh = false,
  }) async =>
      Map<Object?, Object?>.from(
        await nativeCall('getCurrentSessionForNotificationCapture', {
          'userId': userId,
          'forceRefresh': forceRefresh,
        }) as Map,
      );

  Map<String, Object?> credentials(Session session) => {
        'accessToken': session.accessToken,
        'userId': session.user.id,
        'expiresAt': session.expiresAt,
      };

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    nativeCalls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      return null;
    });
    service = NotificationCaptureService.instance;
    await service.clearAuthContext();
    nativeCalls.clear();
    auth = _MockAuth();
    current = _session();
    when(() => auth.currentSession).thenAnswer((_) => current);
    when(() => auth.currentUser).thenAnswer((_) => current?.user);
    when(() => auth.refreshSession()).thenAnswer((_) async {
      current = _session();
      return AuthResponse(session: current);
    });
    service.initializeSessionBridge(authReady: () async => auth);
  });

  tearDown(() async {
    try {
      // Native dispatch owns replay. Calling it from the credential callback can
      // recurse back into that callback or deadlock unattended capture.
      expect(
        nativeCalls.where((call) => call.method == 'syncPendingCaptures'),
        isEmpty,
        reason: 'The session bridge must not recursively replay captures',
      );
    } finally {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await service.clearAuthContext();
      channel.setMethodCallHandler(null);
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  group('Android notification capture session bridge', () {
    test('returns only current access credentials without refreshing',
        () async {
      final result = await request();

      expect(result, credentials(current!));
      expect(result, isNot(contains('refreshToken')));
      expect(result.values, isNot(contains('flutter-owned-refresh-token')));
      verifyNever(() => auth.refreshSession());
      expect(nativeCalls, isEmpty);
    });

    for (final seconds in [-3600, 20, 30]) {
      test('refreshes a token with $seconds seconds remaining', () async {
        current = _session(accessToken: 'old-token', expiresIn: seconds);

        final result = await request();

        expect(result, credentials(current!));
        expect(result['accessToken'], 'fresh-token');
        verify(() => auth.refreshSession()).called(1);
      });
    }

    test('does not refresh a token safely outside the 30 second window',
        () async {
      current = _session(expiresIn: 120);

      expect(await request(), credentials(current!));

      verifyNever(() => auth.refreshSession());
    });

    test('a native 401 forces refresh even when the token is not expired',
        () async {
      current = _session(accessToken: 'server-rejected-token');

      expect(await request(forceRefresh: true), credentials(current!));
      expect(current!.accessToken, 'fresh-token');
      verify(() => auth.refreshSession()).called(1);
    });

    test('cold engine waits for authReady before reading SDK credentials',
        () async {
      final ready = Completer<GoTrueClient>();
      service.initializeSessionBridge(authReady: () => ready.future);
      var completed = false;
      final pending = request().then((value) {
        completed = true;
        return value;
      });

      await pumpEventQueue();
      expect(completed, isFalse);
      verifyNever(() => auth.currentSession);
      verifyNever(() => auth.refreshSession());

      ready.complete(auth);
      expect(await pending, credentials(current!));
    });

    for (final forceRefresh in [false, true]) {
      test('overlapping requests share one refresh (forced: $forceRefresh)',
          () async {
        current = _session(expiresIn: forceRefresh ? 3600 : -3600);
        final refreshed = Completer<AuthResponse>();
        when(() => auth.refreshSession()).thenAnswer((_) => refreshed.future);

        final first = request(forceRefresh: forceRefresh);
        await pumpEventQueue();
        final second = request(forceRefresh: forceRefresh);
        await pumpEventQueue();
        verify(() => auth.refreshSession()).called(1);

        current = _session();
        refreshed.complete(AuthResponse(session: current));
        expect(await first, credentials(current!));
        expect(await second, credentials(current!));
        verifyNever(() => auth.refreshSession());
      });
    }

    for (final actor in <String?>[null, 'user-2']) {
      test('rejects unavailable or wrong session actor ($actor)', () async {
        current = actor == null ? null : _session(userId: actor);

        await expectLater(
          request(forceRefresh: true),
          throwsA(isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'capture_session_unavailable',
          )),
        );
        verifyNever(() => auth.refreshSession());
      });
    }

    test('rejects a stale session when currentUser is a different actor',
        () async {
      when(() => auth.currentUser).thenReturn(_session(userId: 'user-2').user);

      await expectLater(
        request(forceRefresh: true),
        throwsA(isA<PlatformException>()),
      );
      verifyNever(() => auth.refreshSession());
    });

    test('rejects missing currentUser even if an old session remains',
        () async {
      when(() => auth.currentUser).thenReturn(null);

      await expectLater(
        request(forceRefresh: true),
        throwsA(isA<PlatformException>()),
      );
      verifyNever(() => auth.refreshSession());
    });

    test('another actor cannot join an existing refresh', () async {
      current = _session(expiresIn: -3600);
      final refreshed = Completer<AuthResponse>();
      when(() => auth.refreshSession()).thenAnswer((_) => refreshed.future);
      final pending = request();
      await pumpEventQueue();

      await expectLater(
        request(userId: 'user-2'),
        throwsA(isA<PlatformException>()),
      );
      current = _session();
      refreshed.complete(AuthResponse(session: current));
      expect(await pending, credentials(current!));
      verify(() => auth.refreshSession()).called(1);
    });

    test('actor switch during refresh cannot export either actor token',
        () async {
      current = _session(expiresIn: -3600);
      final refreshed = Completer<AuthResponse>();
      when(() => auth.refreshSession()).thenAnswer((_) => refreshed.future);
      final rejected =
          expectLater(request(), throwsA(isA<PlatformException>()));
      await pumpEventQueue();

      final previousActorSession = _session();
      current = _session(userId: 'user-2', accessToken: 'other-actor-token');
      refreshed.complete(AuthResponse(session: previousActorSession));

      await rejected;
      expect(await request(userId: 'user-2'), credentials(current!));
      verify(() => auth.refreshSession()).called(1);
    });

    for (final waitingForAuth in [false, true]) {
      test(
          'logout fences ${waitingForAuth ? 'authReady' : 'refresh'} '
          'before native clear completes', () async {
        final ready = Completer<GoTrueClient>();
        final refreshed = Completer<AuthResponse>();
        final nativeCleared = Completer<void>();
        final clearStarted = Completer<void>();
        if (waitingForAuth) {
          service.initializeSessionBridge(authReady: () => ready.future);
        } else {
          current = _session(expiresIn: -3600);
          when(() => auth.refreshSession()).thenAnswer((_) => refreshed.future);
        }
        messenger.setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          if (call.method == 'clearAuthContext') {
            clearStarted.complete();
            await nativeCleared.future;
          }
          return null;
        });

        final rejected =
            expectLater(request(), throwsA(isA<PlatformException>()));
        await pumpEventQueue();
        if (!waitingForAuth) {
          verify(() => auth.refreshSession()).called(1);
        }
        var clearCompleted = false;
        final clearing = service.clearAuthContext().then((_) {
          clearCompleted = true;
        });
        await clearStarted.future;
        // Keep the same actor and a valid session: only the logout generation,
        // not a null SDK session or actor mismatch, can reject this late result.
        current = _session();
        if (waitingForAuth) {
          ready.complete(auth);
        } else {
          refreshed.complete(AuthResponse(session: current));
        }
        try {
          await rejected.timeout(const Duration(seconds: 5));
          expect(clearCompleted, isFalse);
          if (waitingForAuth) verifyNever(() => auth.refreshSession());
        } finally {
          nativeCleared.complete();
          await clearing;
        }
      });
    }

    test('offline refresh failure releases the flight and allows retry',
        () async {
      current = _session(expiresIn: -3600);
      var attempts = 0;
      when(() => auth.refreshSession()).thenAnswer((_) async {
        if (++attempts == 1) throw const AuthException('Offline');
        current = _session();
        return AuthResponse(session: current);
      });

      await expectLater(request(), throwsA(isA<PlatformException>()));
      expect(await request(), credentials(current!));
      expect(attempts, 2);
      verify(() => auth.refreshSession()).called(2);
    });

    for (final invalidResult in [
      'null',
      'expired',
      'near-expiry',
      'empty',
      'actor'
    ]) {
      test('rejects an invalid refresh result: $invalidResult', () async {
        current = _session(expiresIn: -3600);
        final Session? result = switch (invalidResult) {
          'null' => null,
          'expired' => _session(expiresIn: -60),
          'near-expiry' => _session(expiresIn: 20),
          'empty' => _session(accessToken: ''),
          _ => _session(userId: 'user-2'),
        };
        when(() => auth.refreshSession()).thenAnswer((_) async {
          // A valid current session cannot make an invalid refresh response
          // authoritative (nor can a null response fall back to the old token).
          current = _session();
          return AuthResponse(session: result);
        });

        await expectLater(request(), throwsA(isA<PlatformException>()));
        verify(() => auth.refreshSession()).called(1);
      });
    }

    test('session bridge preserves capturesChanged revision delivery',
        () async {
      final events = <String>[];
      final listener = service.capturesSynced.listen(events.add);
      addTearDown(listener.cancel);

      await nativeCall('capturesChanged', {'userId': 'user-1', 'revision': 1});
      await pumpEventQueue();
      expect(events, ['user-1']);
      expect(await request(), credentials(current!));
      await nativeCall('capturesChanged', {'userId': 'user-1', 'revision': 1});
      await nativeCall('capturesChanged', {'userId': 'user-1', 'revision': 2});
      await pumpEventQueue();

      expect(events, ['user-1', 'user-1']);
      verifyNever(() => auth.refreshSession());
    });

    test('capturesChanged from an old actor does not publish reconciliation',
        () async {
      final events = <String>[];
      final listener = service.capturesSynced.listen(events.add);
      addTearDown(listener.cancel);

      await nativeCall('capturesChanged', {'userId': 'user-2', 'revision': 1});
      await pumpEventQueue();

      expect(events, isEmpty);
      expect(await request(), credentials(current!));
    });
  });
}
