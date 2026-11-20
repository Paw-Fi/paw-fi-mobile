import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/core/services/notification_capture_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// The real SupabaseAuth event listener writes here, not a mocked GoTrue client.
class _AuthStorage extends LocalStorage {
  String? value;
  final writes = <String?>[];

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => value != null;
  @override
  Future<String?> accessToken() async => value;
  @override
  Future<void> persistSession(String persistSessionString) async {
    value = persistSessionString;
    writes.add(value);
  }

  @override
  Future<void> removePersistedSession() async {
    value = null;
    writes.add(null);
  }
}

Map<String, dynamic> _session(String actor) => {
      'access_token': 'header.${base64Url.encode(utf8.encode(jsonEncode({
                'sub': actor,
                'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
              }))).replaceAll('=', '')}.signature',
      'refresh_token': 'refresh-$actor',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': actor,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
        'created_at': '2026-10-03T00:00:00Z',
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('moneko/notification_capture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = NotificationCaptureService.instance;
  late GoTrueClient auth;
  late _AuthStorage storage;
  late Completer<void> refreshStarted;
  late Completer<http.Response> refreshResponse;
  late List<MethodCall> nativeCalls;
  late List<AuthState> events;
  late StreamSubscription<AuthState> listener;
  late int refreshRequests;

  Future<Object?> request({String actor = 'A'}) {
    final result = Completer<Object?>();
    ServicesBinding.instance.channelBuffers.push(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(
        'getCurrentSessionForNotificationCapture',
        {'userId': actor, 'forceRefresh': true},
      )),
      (data) {
        try {
          result.complete(channel.codec.decodeEnvelope(data!));
        } catch (error, stack) {
          result.completeError(error, stack);
        }
      },
    );
    return result.future;
  }

  Future<T> transition<T>(Future<T> Function() action) =>
      service.runAuthTransition(action);

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(
        fileInput: 'SUPABASE_URL=https://capture.test\n'
            'SUPABASE_ANON_KEY=test-anon');
    nativeCalls = [];
    events = [];
    refreshRequests = 0;
    refreshStarted = Completer<void>();
    refreshResponse = Completer<http.Response>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      return null;
    });
    await service.clearAuthContext();
    storage = _AuthStorage();
    await Supabase.initialize(
      url: 'https://capture.test',
      anonKey: 'test-anon',
      debug: false,
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: storage,
      ),
      httpClient: MockClient((request) async {
        if (request.url.queryParameters['grant_type'] == 'refresh_token') {
          refreshRequests++;
          refreshStarted.complete();
          return refreshResponse.future;
        }
        if (request.url.queryParameters['grant_type'] == 'password') {
          return http.Response(jsonEncode(_session('B')), 200);
        }
        return http.Response('{}', 200);
      }),
    );
    auth = Supabase.instance.client.auth;
    await auth.recoverSession(jsonEncode(_session('A')));
    service.initializeSessionBridge(authReady: () async => auth);
    listener = auth.onAuthStateChange.listen((event) {
      events.add(event);
      final session = event.session;
      if (session != null) {
        unawaited(service.syncAuthContext(
          supabaseUrl: 'https://capture.test',
          supabaseAnonKey: 'test-anon',
          accessToken: session.accessToken,
          userId: session.user.id,
          expiresAt: session.expiresAt!,
        ));
      }
    }, onError: (Object _) {});
    await pumpEventQueue();
    nativeCalls.clear();
    events.clear();
    storage.writes.clear();
  });

  tearDown(() async {
    await listener.cancel();
    await Supabase.instance.dispose();
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    await service.clearAuthContext();
    channel.setMethodCallHandler(null);
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final nextActor in <String?>[null, 'B']) {
    test(
        'delayed GoTrue refresh cannot replace final ${nextActor ?? 'logout'} '
        'session or persisted auth state', () async {
      // Capture the result without an unhandled error if the old bridge exports A.
      final reply = request()
          .then<Object?>((value) => value, onError: (Object error) => error);
      await refreshStarted.future;
      var actionStarted = false;
      final changing = transition(() async {
        actionStarted = true;
        if (nextActor == null) {
          await auth.signOut();
        } else {
          await auth.signInWithPassword(
              email: 'b@example.test', password: 'test');
        }
      });
      await pumpEventQueue();
      final startedBeforeRefresh = actionStarted;
      final suspendedBeforeRefresh =
          nativeCalls.any((call) => call.method == 'suspendAuthContext');

      refreshResponse.complete(http.Response(jsonEncode(_session('A')), 200));
      await changing;
      final result = await reply;
      await pumpEventQueue();

      expect(auth.currentSession?.user.id, nextActor);
      expect(auth.currentUser?.id, nextActor);
      expect(
          storage.value == null
              ? null
              : jsonDecode(storage.value!)['user']['id'],
          nextActor);
      expect(startedBeforeRefresh, isFalse);
      expect(suspendedBeforeRefresh, isTrue);
      expect(result, isA<PlatformException>());
      expect(
          events.last.event,
          nextActor == null
              ? AuthChangeEvent.signedOut
              : AuthChangeEvent.signedIn);
      expect(
          events.any((event) => event.event == AuthChangeEvent.tokenRefreshed),
          isTrue,
          reason: 'The real SDK mutates and emits the late A refresh');
      expect(
          nativeCalls
              .where((call) => call.method == 'syncAuthContext')
              .map((call) => (call.arguments as Map)['userId'])
              .toSet(),
          nextActor == null ? isEmpty : equals({'B'}));
      expect(refreshRequests, 1);
    });
  }
  test('admission and native publication stay blocked until logout finishes',
      () async {
    final actionStarted = Completer<void>();
    final finishAction = Completer<void>();
    final pending = transition(() async {
      actionStarted.complete();
      await finishAction.future;
      await auth.signOut();
    });
    await actionStarted.future;
    // An auth listener may independently clear context during the transition.
    await service.clearAuthContext();
    final token = auth.currentSession!;
    await service.syncAuthContext(
      supabaseUrl: 'https://capture.test',
      supabaseAnonKey: 'test-anon',
      accessToken: token.accessToken,
      userId: 'A',
      expiresAt: token.expiresAt!,
    );
    final rejected = request()
        .then<Object?>((value) => value, onError: (Object error) => error);
    await pumpEventQueue();
    final during = nativeCalls.toList();
    finishAction.complete();
    await pending;
    expect(await rejected, isA<PlatformException>());
    expect(refreshRequests, 0);
    expect(during.where((call) => call.method == 'syncAuthContext'), isEmpty);
    expect(storage.value, isNull);
  });

  test('queued transitions cannot reopen capture admission after native clear',
      () async {
    final nativeCleared = Completer<void>();
    final clearStarted = Completer<void>();
    var clears = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      if (call.method == 'suspendAuthContext' && ++clears == 1) {
        clearStarted.complete();
        await nativeCleared.future;
      }
      return null;
    });
    final order = <String>[];
    final first = transition(() async {
      order.add('first');
    });
    await clearStarted.future;
    final second = transition(() async {
      order.add('second');
      await auth.signInWithPassword(email: 'b@example.test', password: 'test');
    });
    nativeCleared.complete();
    await Future.wait([first, second]);
    expect(order, ['first', 'second']);
    expect(auth.currentUser?.id, 'B');
    // This must publish: a generation change while clear awaited must not leave
    // the separate native-clear admission flag permanently stuck.
    expect(
        nativeCalls
            .where((call) => call.method == 'syncAuthContext')
            .map((call) => (call.arguments as Map)['userId'])
            .toSet(),
        {'B'});
  });

  test('failed refresh still drains before final signed-out persistence',
      () async {
    final rejected = request()
        .then<Object?>((value) => value, onError: (Object error) => error);
    await refreshStarted.future;
    var actionStarted = false;
    final logout = transition(() async {
      actionStarted = true;
      await auth.signOut();
    });
    await pumpEventQueue();
    final startedEarly = actionStarted;
    refreshResponse.complete(http.Response(
        '{"msg":"invalid refresh token","code":"refresh_token_not_found"}',
        400));
    await logout;
    expect(await rejected, isA<PlatformException>());
    await pumpEventQueue();
    expect(startedEarly, isFalse);
    expect(auth.currentSession, isNull);
    expect(storage.value, isNull);
    expect(events.last.event, AuthChangeEvent.signedOut);
  });

  test('failed transition releases queued sign-in without signing out B',
      () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final first = transition<void>(() async {
      entered.complete();
      await release.future;
      throw const AuthException('failed transition');
    }).then<Object?>((_) => null, onError: (Object error) => error);
    await entered.future;
    final next = transition(() =>
        auth.signInWithPassword(email: 'b@example.test', password: 'test'));
    release.complete();
    expect(await first, isA<AuthException>());
    await next;
    await pumpEventQueue();
    expect(auth.currentUser?.id, 'B');
    expect(jsonDecode(storage.value!)['user']['id'], 'B');
    expect(events.last.event, AuthChangeEvent.signedIn);
    expect(
        nativeCalls
            .where((call) => call.method == 'syncAuthContext')
            .map((call) => (call.arguments as Map)['userId'])
            .toSet(),
        {'B'});
  });

  test(
      'native suspension failure drains refresh and does not install another actor',
      () async {
    final rejected = request()
        .then<Object?>((value) => value, onError: (Object error) => error);
    await refreshStarted.future;
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      if (call.method == 'suspendAuthContext') {
        throw PlatformException(code: 'native_storage_unavailable');
      }
      return null;
    });
    var actionStarted = false;
    var completed = false;
    final pending = transition(() async {
      actionStarted = true;
    }).then<Object?>((_) {
      completed = true;
      return null;
    }, onError: (Object error) {
      completed = true;
      return error;
    });
    await pumpEventQueue();
    final completedEarly = completed;
    refreshResponse.complete(http.Response(jsonEncode(_session('A')), 200));
    expect(await pending, isA<PlatformException>());
    expect(await rejected, isA<PlatformException>());
    expect(completedEarly, isFalse);
    expect(actionStarted, isFalse);
    expect(auth.currentUser?.id, 'A');
  });

  test('native auth publication waiting on authReady cannot cross a transition',
      () async {
    final ready = Completer<GoTrueClient>();
    service.initializeSessionBridge(authReady: () => ready.future);
    final token = auth.currentSession!;
    final publishing = service.syncAuthContext(
      supabaseUrl: 'https://capture.test',
      supabaseAnonKey: 'test-anon',
      accessToken: token.accessToken,
      userId: 'A',
      expiresAt: token.expiresAt!,
    );
    final logout = transition(() => auth.signOut());
    await pumpEventQueue();
    ready.complete(auth);
    await Future.wait([publishing, logout]);
    expect(
        nativeCalls.where((call) => call.method == 'syncAuthContext'), isEmpty);
    expect(auth.currentSession, isNull);
  });

  test('failed authentication preserves the original native queue', () async {
    await expectLater(
      transition<void>(() async => throw const AuthException('rejected')),
      throwsA(isA<AuthException>()),
    );
    expect(auth.currentUser?.id, 'A');
    expect(nativeCalls.map((call) => call.method),
        ['suspendAuthContext', 'syncAuthContext']);
  });
}
