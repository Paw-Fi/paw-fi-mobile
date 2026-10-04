import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
// Inject the same platform event stream used by FirebaseMessaging's tap API.
// ignore: depend_on_referenced_packages
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/notifications/notification_badge_service.dart';
import 'package:moneko/core/notifications/notification_dispatcher.dart';
import 'package:moneko/core/notifications/notification_intent.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRef extends Mock implements Ref {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

class _MockDeviceRegistrationGateway extends Mock
    implements DeviceRegistrationGateway {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockSession extends Mock implements Session {}

class _MockUser extends Mock implements User {}

class _MockNotificationSettings extends Mock implements NotificationSettings {}

class _MockNotificationBadgeService extends Mock
    implements NotificationBadgeService {}

class _MockNotificationDispatcher extends Mock
    implements NotificationDispatcher {}

const _authorizedSettings = NotificationSettings(
  authorizationStatus: AuthorizationStatus.authorized,
  alert: AppleNotificationSetting.enabled,
  announcement: AppleNotificationSetting.notSupported,
  badge: AppleNotificationSetting.enabled,
  carPlay: AppleNotificationSetting.notSupported,
  lockScreen: AppleNotificationSetting.enabled,
  notificationCenter: AppleNotificationSetting.enabled,
  showPreviews: AppleShowPreviewSetting.always,
  timeSensitive: AppleNotificationSetting.notSupported,
  criticalAlert: AppleNotificationSetting.notSupported,
  sound: AppleNotificationSetting.enabled,
  providesAppNotificationSettings: AppleNotificationSetting.notSupported,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationIntent(
      action: NotificationIntentAction.unknown,
    ));
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'households:splits:v1:household-1:all': 'splits',
      'households:expenses:v1:household-1:1000': 'expenses',
      'households:summary:v1:household-1:USD': 'summary',
      'households:settlement-payments:v1:household-1:user-1': 'payments',
      'households:splits:v1:household-2:all': 'other-household',
      'unrelated': 'keep',
    });
  });

  test('settlement push evicts every affected household cache', () async {
    final householdId = await clearHouseholdMutationCaches(
      const {
        'event_type': 'split_settled',
        'household_id': 'household-1',
      },
    );
    final preferences = await SharedPreferences.getInstance();

    expect(householdId, 'household-1');
    expect(
      preferences.getKeys().where((key) => key.contains('household-1')),
      isEmpty,
    );
    expect(preferences.getString('households:splits:v1:household-2:all'),
        'other-household');
    expect(preferences.getString('unrelated'), 'keep');
  });

  test('unrelated push does not evict household caches', () async {
    final householdId = await clearHouseholdMutationCaches(
      const {
        'event_type': 'member_reminded',
        'household_id': 'household-1',
      },
    );
    final preferences = await SharedPreferences.getInstance();

    expect(householdId, isNull);
    expect(preferences.getString('households:splits:v1:household-1:all'),
        'splits');
  });

  test('notification launches and taps clear badges without delaying routing',
      () async {
    final ref = _MockRef();
    final messaging = _MockFirebaseMessaging();
    final local = _MockLocalNotifications();
    final gateway = _MockDeviceRegistrationGateway();
    final badge = _MockNotificationBadgeService();
    final dispatcher = _MockNotificationDispatcher();
    final pendingClear = Completer<void>();
    when(() => ref.read(notificationBadgeServiceProvider)).thenReturn(badge);
    when(() => badge.clear()).thenAnswer((_) => pendingClear.future);
    when(() => ref.read(notificationDispatcherProvider)).thenReturn(dispatcher);
    when(() => dispatcher.enqueueIntent(any(), source: any(named: 'source')))
        .thenAnswer((_) async {});
    void Function(NotificationResponse)? onTap;
    when(() => local.initialize(any(),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse')))
        .thenAnswer((invocation) async {
      onTap = invocation.namedArguments[#onDidReceiveNotificationResponse]
          as void Function(NotificationResponse)?;
      return true;
    });
    when(() => local.getNotificationAppLaunchDetails()).thenAnswer(
      (_) async => const NotificationAppLaunchDetails(true,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: '{"event_type":"log_expense_reminder"}',
          )),
    );
    when(() => messaging.getInitialMessage()).thenAnswer(
      (_) async => const RemoteMessage(
        data: {'event_type': 'log_expense_reminder'},
      ),
    );
    when(() => gateway.currentUserId).thenReturn('user-1');
    when(() => gateway.hasActiveSession).thenReturn(true);
    when(() => gateway.isAndroid).thenReturn(false);
    when(() => gateway.isIOS).thenReturn(false);
    final deniedSettings = _MockNotificationSettings();
    when(() => deniedSettings.authorizationStatus)
        .thenReturn(AuthorizationStatus.denied);
    when(() => gateway.requestMessagingPermission())
        .thenAnswer((_) => Future<NotificationSettings>.value(deniedSettings));
    final service = DeviceRegistrationService(
      ref,
      _MockSupabaseClient(),
      messaging,
      local,
      gateway: gateway,
    );
    // Permission denial after handler setup avoids token registration. Badge
    // acknowledgement must work independently of registration success.
    expect(await service.initialize(bypassPromptGate: true),
        DeviceRegistrationResult.permissionDenied);
    verify(() => badge.clear()).called(2);
    verify(() => dispatcher.enqueueIntent(any(), source: 'local_launch'))
        .called(1);
    verify(() => dispatcher.enqueueIntent(any(), source: 'fcm_tap')).called(1);

    onTap!(const NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      payload: '{"event_type":"log_expense_reminder"}',
    ));
    verify(() => badge.clear()).called(1);
    verify(() => dispatcher.enqueueIntent(any(), source: 'local_tap'))
        .called(1);
    onTap!(const NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
    ));
    verify(() => badge.clear()).called(1);

    FirebaseMessagingPlatform.onMessageOpenedApp.add(const RemoteMessage(
      data: {'event_type': 'log_expense_reminder'},
    ));
    await pumpEventQueue();
    verify(() => badge.clear()).called(1);
    verify(() => dispatcher.enqueueIntent(any(), source: 'fcm_tap')).called(1);
    pendingClear.complete();
  });

  group('Firebase registration backend contract', () {
    late _MockSupabaseClient supabase;
    late _MockGoTrueClient auth;
    late _MockFunctionsClient functions;
    late _MockSession session;
    late FirebaseDeviceRegistrationGateway gateway;

    setUp(() {
      supabase = _MockSupabaseClient();
      auth = _MockGoTrueClient();
      functions = _MockFunctionsClient();
      session = _MockSession();
      final user = _MockUser();
      when(() => user.id).thenReturn('user-1');
      when(() => session.user).thenReturn(user);
      when(() => session.accessToken).thenReturn('session-jwt');
      when(() => supabase.auth).thenReturn(auth);
      when(() => supabase.functions).thenReturn(functions);
      when(() => auth.currentSession).thenReturn(session);
      gateway = FirebaseDeviceRegistrationGateway(
          supabase, _MockFirebaseMessaging(),
          requestTimeout: Duration.zero);
      when(() =>
          functions.invoke('households-register-device',
              headers: any(named: 'headers'),
              body: any(named: 'body'))).thenAnswer(
          (_) async => FunctionResponse(status: 200, data: {'success': true}));
    });

    test('foreground banners and sound do not reapply the iOS badge', () async {
      final messaging = _MockFirebaseMessaging();
      when(() => messaging.setForegroundNotificationPresentationOptions(
          alert: any(named: 'alert'),
          badge: any(named: 'badge'),
          sound: any(named: 'sound'))).thenAnswer((_) async {});
      final gateway = FirebaseDeviceRegistrationGateway(supabase, messaging);
      await gateway.configureForegroundPresentation();
      verify(() => messaging.setForegroundNotificationPresentationOptions(
          alert: true, badge: false, sound: true)).called(1);
    });

    test('registration and deletion use the captured authenticated session',
        () async {
      expect(await gateway.registerDevice('token-1', expectedUserId: 'user-1'),
          isTrue);
      expect(
          await gateway.unregisterDevice('token-1', expectedUserId: 'user-1'),
          isTrue);
      final calls = verify(() => functions.invoke('households-register-device',
          headers: captureAny(named: 'headers'),
          body: captureAny(named: 'body'))).captured;
      expect(calls[0], {'Authorization': 'Bearer session-jwt'});
      expect((calls[1] as Map)['push_token'], 'token-1');
      expect(calls[2], {'Authorization': 'Bearer session-jwt'});
      expect((calls[3] as Map)['delete_device'], isTrue);
    });

    for (final absent in [false, true]) {
      test(
          'no request is sent for ${absent ? 'a missing session' : 'a different account'}',
          () async {
        if (absent) when(() => auth.currentSession).thenReturn(null);
        expect(
            await gateway.registerDevice('token-1',
                expectedUserId: absent ? 'user-1' : 'user-2'),
            isFalse);
        expect(
            await gateway.unregisterDevice('token-1',
                expectedUserId: absent ? 'user-1' : 'user-2'),
            isFalse);
        verifyNever(() => functions.invoke(any(),
            headers: any(named: 'headers'), body: any(named: 'body')));
      });
    }

    for (final data in [
      {'success': false},
      {'message': 'missing acknowledgement'},
      'unexpected response'
    ]) {
      test('HTTP 200 without success acknowledgement is rejected: $data',
          () async {
        when(() => functions.invoke(any(),
                headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer((_) async => FunctionResponse(status: 200, data: data));
        expect(
            await gateway.registerDevice('token-1', expectedUserId: 'user-1'),
            isFalse);
        expect(
            await gateway.unregisterDevice('token-1', expectedUserId: 'user-1'),
            isFalse);
      });
    }

    test('HTTP conflict is a failed registration, not a cached success',
        () async {
      when(() => functions.invoke(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenThrow(const FunctionException(status: 409));
      expect(await gateway.registerDevice('token-1', expectedUserId: 'user-1'),
          isFalse);
    });

    test('stalled backend requests return failure within the request timeout',
        () async {
      when(() => functions.invoke(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) => Completer<FunctionResponse>().future);
      expect(await gateway.registerDevice('token-1', expectedUserId: 'user-1'),
          isFalse);
      expect(
          await gateway.unregisterDevice('token-1', expectedUserId: 'user-1'),
          isFalse);
    });
  });

  group('device registration lifecycle', () {
    late _MockDeviceRegistrationGateway gateway;
    late StreamController<String> tokenRefreshController;

    DeviceRegistrationService buildService() {
      return DeviceRegistrationService(
        _MockRef(),
        _MockSupabaseClient(),
        _MockFirebaseMessaging(),
        _MockLocalNotifications(),
        gateway: gateway,
        interactionHandlersInitializer: () async {},
        apnsTokenWaitTimeout: Duration.zero,
      );
    }

    DeviceRegistrationService buildServiceWithInteractionInitializer(
      Future<void> Function() initializer,
    ) {
      return DeviceRegistrationService(
        _MockRef(),
        _MockSupabaseClient(),
        _MockFirebaseMessaging(),
        _MockLocalNotifications(),
        gateway: gateway,
        interactionHandlersInitializer: initializer,
        apnsTokenWaitTimeout: Duration.zero,
        interactionHandlersTimeout: Duration.zero,
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'notifications_prompted:user-1': true,
      });
      gateway = _MockDeviceRegistrationGateway();
      tokenRefreshController = StreamController<String>.broadcast();

      when(() => gateway.currentUserId).thenReturn('user-1');
      when(() => gateway.hasActiveSession).thenReturn(true);
      when(() => gateway.isIOS).thenReturn(false);
      when(() => gateway.isAndroid).thenReturn(false);
      when(() => gateway.requestAndroidNotificationPermission())
          .thenAnswer((_) async {});
      when(() => gateway.onTokenRefresh)
          .thenAnswer((_) => tokenRefreshController.stream);
      when(() => gateway.requestMessagingPermission())
          .thenAnswer((_) async => _authorizedSettings);
      when(() => gateway.configureForegroundPresentation())
          .thenAnswer((_) async {});
      when(() => gateway.getToken())
          .thenAnswer((_) => Future<String?>.value('token-1'));
      when(() => gateway.deleteToken()).thenAnswer((_) async {});
      when(() => gateway.registerDevice('token-1',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) async => true);
      when(() => gateway.unregisterDevice('token-1',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) async => true);
      when(() => gateway.unregisterDevice('token-2',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) async => true);
    });

    tearDown(() async {
      await tokenRefreshController.close();
    });

    for (final platform in ['iOS', 'Android']) {
      test('$platform registers and caches only after backend confirmation',
          () async {
        final isIOS = platform == 'iOS';
        when(() => gateway.isIOS).thenReturn(isIOS);
        when(() => gateway.isAndroid).thenReturn(!isIOS);
        when(() => gateway.getApnsToken())
            .thenAnswer((_) async => 'apns-token');
        final backend = Completer<bool>();
        when(() => gateway.registerDevice('token-1',
                expectedUserId: any(named: 'expectedUserId')))
            .thenAnswer((_) => backend.future);
        final service = buildService();
        final pending = service.repairDeviceRegistration();
        await pumpEventQueue();

        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString('device_reg:user-1:token'), isNull);
        verify(() => gateway.getToken()).called(1);
        if (isIOS) {
          verify(() => gateway.getApnsToken()).called(1);
          verify(() => gateway.configureForegroundPresentation()).called(1);
          verifyNever(() => gateway.requestAndroidNotificationPermission());
        } else {
          verify(() => gateway.requestAndroidNotificationPermission())
              .called(1);
          verifyNever(() => gateway.getApnsToken());
          verifyNever(() => gateway.configureForegroundPresentation());
        }

        backend.complete(true);
        expect(await pending, DeviceRegistrationResult.registered);
        expect(preferences.getString('device_reg:user-1:token'), 'token-1');
      });

      test('$platform replaces a refreshed token and retires the prior token',
          () async {
        when(() => gateway.isIOS).thenReturn(platform == 'iOS');
        when(() => gateway.isAndroid).thenReturn(platform == 'Android');
        when(() => gateway.getApnsToken())
            .thenAnswer((_) async => 'apns-token');
        when(() => gateway.registerDevice('token-2',
                expectedUserId: any(named: 'expectedUserId')))
            .thenAnswer((_) async => true);
        final service = buildService();
        expect(await service.initialize(), DeviceRegistrationResult.registered);

        tokenRefreshController.add('token-2');
        await pumpEventQueue();

        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString('device_reg:user-1:token'), 'token-2');
        verify(() => gateway.registerDevice('token-2',
            expectedUserId: any(named: 'expectedUserId'))).called(1);
        verify(() => gateway.unregisterDevice('token-1',
            expectedUserId: any(named: 'expectedUserId'))).called(1);
      });
    }

    test('failed token refresh is retried on the next app resume', () async {
      final service = buildService();
      expect(await service.initialize(), DeviceRegistrationResult.registered);
      when(() => gateway.registerDevice('token-2',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) async => false);
      when(() => gateway.getToken())
          .thenAnswer((_) => Future<String?>.value('token-2'));
      tokenRefreshController.add('token-2');
      await pumpEventQueue();
      when(() => gateway.registerDevice('token-2',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) async => true);
      expect(await service.initialize(), DeviceRegistrationResult.registered);
      verify(() => gateway.registerDevice('token-2',
          expectedUserId: any(named: 'expectedUserId'))).called(2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('device_reg:user-1:token'), 'token-2');
    });

    test('logout during token rotation removes the old and in-flight tokens',
        () async {
      final service = buildService();
      expect(await service.initialize(), DeviceRegistrationResult.registered);
      final backend = Completer<bool>();
      when(() => gateway.registerDevice('token-2',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) => backend.future);
      tokenRefreshController.add('token-2');
      await pumpEventQueue();
      final logout = service.unregisterDevice();
      backend.complete(true);
      await logout;
      verify(() => gateway.unregisterDevice('token-1',
          expectedUserId: any(named: 'expectedUserId'))).called(1);
      verify(() => gateway.unregisterDevice('token-2',
          expectedUserId: any(named: 'expectedUserId'))).called(1);
      verify(() => gateway.deleteToken()).called(1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('device_reg:user-1:token'), isNull);
    });

    test('logout rechecks the account after reading the fallback token',
        () async {
      final token = Completer<String?>();
      when(() => gateway.getToken()).thenAnswer((_) => token.future);
      final logout = buildService().unregisterDevice();
      await pumpEventQueue();
      when(() => gateway.currentUserId).thenReturn('user-2');
      token.complete('token-2');
      await logout;
      verifyNever(() => gateway.unregisterDevice(any(),
          expectedUserId: any(named: 'expectedUserId')));
      verifyNever(() => gateway.deleteToken());
    });

    test('a stalled native APNs read cannot block repair or logout', () async {
      when(() => gateway.isIOS).thenReturn(true);
      when(() => gateway.getApnsToken())
          .thenAnswer((_) => Completer<String?>().future);
      final service = buildService();
      expect(await service.repairDeviceRegistration(),
          DeviceRegistrationResult.tokenUnavailable);
      await service.unregisterDevice();
      verifyNever(() => gateway.registerDevice(any(),
          expectedUserId: any(named: 'expectedUserId')));
      verify(() => gateway.deleteToken()).called(1);
    });

    for (final platform in ['iOS', 'Android']) {
      test('$platform signup defers until prompted then registers', () async {
        SharedPreferences.setMockInitialValues({});
        when(() => gateway.isIOS).thenReturn(platform == 'iOS');
        when(() => gateway.isAndroid).thenReturn(platform == 'Android');
        when(() => gateway.getApnsToken())
            .thenAnswer((_) async => 'apns-token');
        final service = buildService();
        expect(await service.initialize(),
            DeviceRegistrationResult.deferredUntilPrompted);
        verifyNever(() => gateway.requestMessagingPermission());
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notifications_prompted:user-1', true);
        expect(await service.initialize(), DeviceRegistrationResult.registered);
      });

      test('$platform denied permission remains retryable after enabling it',
          () async {
        when(() => gateway.isIOS).thenReturn(platform == 'iOS');
        when(() => gateway.isAndroid).thenReturn(platform == 'Android');
        when(() => gateway.getApnsToken())
            .thenAnswer((_) async => 'apns-token');
        final denied = _MockNotificationSettings();
        when(() => denied.authorizationStatus)
            .thenReturn(AuthorizationStatus.denied);
        when(() => gateway.requestMessagingPermission())
            .thenAnswer((_) => Future<NotificationSettings>.value(denied));
        final service = buildService();
        expect(await service.initialize(),
            DeviceRegistrationResult.permissionDenied);
        verifyNever(() => gateway.registerDevice(any(),
            expectedUserId: any(named: 'expectedUserId')));
        when(() => gateway.requestMessagingPermission())
            .thenAnswer((_) async => _authorizedSettings);
        expect(await service.initialize(), DeviceRegistrationResult.registered);
      });
    }

    test('account switch waits for the prior account token refresh upsert',
        () async {
      SharedPreferences.setMockInitialValues({
        'notifications_prompted:user-1': true,
        'notifications_prompted:user-2': true
      });
      final service = buildService();
      expect(await service.initialize(), DeviceRegistrationResult.registered);
      final oldWrite = Completer<bool>();
      when(() => gateway.registerDevice('token-2', expectedUserId: 'user-1'))
          .thenAnswer((_) => oldWrite.future);
      when(() => gateway.registerDevice('token-2', expectedUserId: 'user-2'))
          .thenAnswer((_) async => true);
      tokenRefreshController.add('token-2');
      await pumpEventQueue();
      when(() => gateway.currentUserId).thenReturn('user-2');
      when(() => gateway.getToken())
          .thenAnswer((_) => Future<String?>.value('token-2'));
      final login = service.initialize();
      await pumpEventQueue();
      verifyNever(
          () => gateway.registerDevice('token-2', expectedUserId: 'user-2'));
      oldWrite.complete(true);
      expect(await login, DeviceRegistrationResult.registered);
      verifyInOrder([
        () => gateway.registerDevice('token-2', expectedUserId: 'user-1'),
        () => gateway.registerDevice('token-2', expectedUserId: 'user-2'),
      ]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('device_reg:user-2:token'), 'token-2');
      await service.handleSessionEnded(userId: 'user-1');
      verifyNever(() => gateway.deleteToken());
      expect(prefs.getString('device_reg:user-1:token'), isNull);
    });

    test('logout and same-account login preserve another physical device',
        () async {
      final serverTokens = {'token-1', 'other-device-token'};
      when(() => gateway.registerDevice(any(), expectedUserId: 'user-1'))
          .thenAnswer((call) async {
        serverTokens.add(call.positionalArguments.first as String);
        return true;
      });
      when(() => gateway.unregisterDevice(any(), expectedUserId: 'user-1'))
          .thenAnswer((call) async {
        serverTokens.remove(call.positionalArguments.first);
        return true;
      });
      final service = buildService();
      expect(await service.initialize(), DeviceRegistrationResult.registered);
      await service.unregisterDevice();
      expect(serverTokens, {'other-device-token'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('device_reg:user-1:token'), isNull);
      when(() => gateway.getToken())
          .thenAnswer((_) => Future<String?>.value('token-2'));
      expect(await service.initialize(), DeviceRegistrationResult.registered);
      expect(serverTokens, {'token-2', 'other-device-token'});
    });

    test(
        'account deletion or session loss still clears local token when backend auth is gone',
        () async {
      final service = buildService();
      expect(await service.initialize(), DeviceRegistrationResult.registered);
      when(() => gateway.hasActiveSession).thenReturn(false);
      when(() => gateway.currentUserId).thenReturn(null);
      await service.handleSessionEnded(userId: 'user-1');
      verifyNever(() => gateway.unregisterDevice(any(),
          expectedUserId: any(named: 'expectedUserId')));
      verify(() => gateway.deleteToken()).called(1);
      tokenRefreshController.add('token-2');
      await pumpEventQueue();
      verifyNever(() => gateway.registerDevice('token-2',
          expectedUserId: any(named: 'expectedUserId')));
      expect(
          await service.initialize(), DeviceRegistrationResult.unauthenticated);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('device_reg:user-1:token'), isNull);
    });

    test('token stream failure is handled and allows registration on resume',
        () async {
      final service = buildService();
      expect(await service.initialize(), DeviceRegistrationResult.registered);
      tokenRefreshController
          .addError(StateError('Native token stream unavailable'));
      await pumpEventQueue();
      expect(await service.initialize(), DeviceRegistrationResult.registered);
    });

    test(
        'revoked permission does not let a later refresh restore initialized state',
        () async {
      final service = buildService();
      expect(await service.initialize(), DeviceRegistrationResult.registered);
      final denied = _MockNotificationSettings();
      when(() => denied.authorizationStatus)
          .thenReturn(AuthorizationStatus.denied);
      when(() => gateway.requestMessagingPermission())
          .thenAnswer((_) => Future<NotificationSettings>.value(denied));
      expect(await service.repairDeviceRegistration(),
          DeviceRegistrationResult.permissionDenied);
      tokenRefreshController.add('token-2');
      await pumpEventQueue();
      verifyNever(() => gateway.registerDevice('token-2',
          expectedUserId: any(named: 'expectedUserId')));
      when(() => gateway.requestMessagingPermission())
          .thenAnswer((_) async => _authorizedSettings);
      expect(await service.initialize(), DeviceRegistrationResult.registered);
    });

    test('backend rejection remains retryable and is not initialized',
        () async {
      when(() => gateway.registerDevice('token-1',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) async => false);
      final service = buildService();

      final firstResult = await service.initialize();
      expect(firstResult, DeviceRegistrationResult.backendRejected);
      expect(
        await service.initialize(),
        DeviceRegistrationResult.backendRejected,
      );

      verify(() => gateway.registerDevice('token-1',
          expectedUserId: any(named: 'expectedUserId'))).called(2);
    });

    test('initialization timeout releases lifecycle waiters', () async {
      final neverCompletes = Completer<void>();
      final service = buildServiceWithInteractionInitializer(
        () => neverCompletes.future,
      );

      expect(
        await service.initialize(),
        DeviceRegistrationResult.failed,
      );
      await service.unregisterDevice();

      verify(() => gateway.deleteToken()).called(1);
    });

    test('missing APNs token remains retryable and never calls backend',
        () async {
      when(() => gateway.isIOS).thenReturn(true);
      when(() => gateway.getApnsToken()).thenAnswer((_) async => null);
      final service = buildService();

      expect(
        await service.initialize(),
        DeviceRegistrationResult.tokenUnavailable,
      );
      expect(
        await service.initialize(),
        DeviceRegistrationResult.tokenUnavailable,
      );

      verifyNever(() => gateway.registerDevice(any(),
          expectedUserId: any(named: 'expectedUserId')));
    });

    test('explicit repair bypasses prompt and fresh local cache', () async {
      SharedPreferences.setMockInitialValues({
        'device_reg:user-1:token': 'token-1',
        'device_reg:user-1:registered_at': DateTime.now().toIso8601String(),
      });
      final service = buildService();

      final result = await service.repairDeviceRegistration();

      expect(result, DeviceRegistrationResult.registered);
      verify(() => gateway.registerDevice('token-1',
          expectedUserId: any(named: 'expectedUserId'))).called(1);
      verifyNever(() => gateway.unregisterDevice(any(),
          expectedUserId: any(named: 'expectedUserId')));
      verifyNever(() => gateway.deleteToken());
    });

    test('unregister failure cannot block the next initialization', () async {
      final service = buildService();
      expect(
        await service.initialize(),
        DeviceRegistrationResult.registered,
      );
      when(() => gateway.unregisterDevice('token-1',
              expectedUserId: any(named: 'expectedUserId')))
          .thenThrow(Exception('offline'));

      await service.unregisterDevice();
      final secondResult = await service.initialize();

      expect(secondResult, DeviceRegistrationResult.registered);
      verify(() => gateway.registerDevice('token-1',
          expectedUserId: any(named: 'expectedUserId'))).called(2);
      verify(() => gateway.deleteToken()).called(1);
    });

    test('concurrent initialization performs one backend upsert', () async {
      final registration = Completer<bool>();
      when(() => gateway.registerDevice('token-1',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) => registration.future);
      final service = buildService();

      final first = service.initialize();
      final second = service.initialize();
      registration.complete(true);

      expect(await first, DeviceRegistrationResult.registered);
      expect(await second, DeviceRegistrationResult.registered);
      verify(() => gateway.registerDevice('token-1',
          expectedUserId: any(named: 'expectedUserId'))).called(1);
    });

    test('token refresh registers the replacement token', () async {
      when(() => gateway.registerDevice('token-2',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) async => true);
      final service = buildService();
      expect(
        await service.initialize(),
        DeviceRegistrationResult.registered,
      );

      tokenRefreshController.add('token-2');
      await Future<void>.delayed(Duration.zero);

      verify(() => gateway.registerDevice('token-2',
          expectedUserId: any(named: 'expectedUserId'))).called(1);
      verify(() => gateway.unregisterDevice('token-1',
          expectedUserId: any(named: 'expectedUserId'))).called(1);
    });

    test('overlapping token refreshes persist only the latest token', () async {
      final token2Registration = Completer<bool>();
      when(() => gateway.registerDevice('token-2',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) => token2Registration.future);
      when(() => gateway.registerDevice('token-3',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) async => true);
      final service = buildService();
      expect(
        await service.initialize(),
        DeviceRegistrationResult.registered,
      );

      tokenRefreshController
        ..add('token-2')
        ..add('token-3');
      await Future<void>.delayed(Duration.zero);
      token2Registration.complete(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('device_reg:user-1:token'), 'token-3');
      verifyInOrder([
        () => gateway.registerDevice('token-2',
            expectedUserId: any(named: 'expectedUserId')),
        () => gateway.registerDevice('token-3',
            expectedUserId: any(named: 'expectedUserId')),
      ]);
      verify(() => gateway.unregisterDevice('token-1',
          expectedUserId: any(named: 'expectedUserId'))).called(1);
      verify(() => gateway.unregisterDevice('token-2',
          expectedUserId: any(named: 'expectedUserId'))).called(1);
    });

    test('switching accounts registers the token for the new user', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_prompted:user-1': true,
        'notifications_prompted:user-2': true,
      });
      final service = buildService();
      expect(
        await service.initialize(),
        DeviceRegistrationResult.registered,
      );

      when(() => gateway.currentUserId).thenReturn('user-2');
      final secondResult = await service.initialize();

      expect(secondResult, DeviceRegistrationResult.registered);
      verify(() => gateway.registerDevice('token-1',
          expectedUserId: any(named: 'expectedUserId'))).called(2);
    });

    test('logout waits for initialization and removes its backend token',
        () async {
      final registration = Completer<bool>();
      when(() => gateway.registerDevice('token-1',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) => registration.future);
      final service = buildService();

      final initialization = service.initialize();
      await Future<void>.delayed(Duration.zero);
      final logout = service.unregisterDevice();
      registration.complete(true);

      expect(
        await initialization,
        DeviceRegistrationResult.unauthenticated,
      );
      await logout;
      verify(() => gateway.unregisterDevice('token-1',
          expectedUserId: any(named: 'expectedUserId'))).called(1);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('device_reg:user-1:token'), isNull);
    });

    test('logout cannot remove a different account after waiting', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_prompted:user-1': true,
        'device_reg:user-1:token': 'token-1',
        'device_reg:user-2:token': 'token-2',
      });
      final registration = Completer<bool>();
      when(() => gateway.registerDevice('token-1',
              expectedUserId: any(named: 'expectedUserId')))
          .thenAnswer((_) => registration.future);
      final service = buildService();

      final initialization = service.initialize();
      await Future<void>.delayed(Duration.zero);
      final logout = service.unregisterDevice();
      when(() => gateway.currentUserId).thenReturn('user-2');
      registration.complete(true);

      await initialization;
      await logout;
      verifyNever(() => gateway.unregisterDevice('token-2',
          expectedUserId: any(named: 'expectedUserId')));
      verifyNever(() => gateway.deleteToken());
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('device_reg:user-2:token'), 'token-2');
    });

    test('forced repair queues behind a weaker initialization request',
        () async {
      final permission = Completer<NotificationSettings>();
      when(() => gateway.requestMessagingPermission())
          .thenAnswer((_) => permission.future);
      final service = buildService();

      final initialization = service.initialize();
      await Future<void>.delayed(Duration.zero);
      final repair = service.repairDeviceRegistration();
      permission.complete(_authorizedSettings);

      expect(
        await initialization,
        DeviceRegistrationResult.registered,
      );
      expect(await repair, DeviceRegistrationResult.registered);
      verify(() => gateway.registerDevice('token-1',
          expectedUserId: any(named: 'expectedUserId'))).called(2);
    });

    test('session ending resets registration without requesting a new token',
        () async {
      final service = buildService();
      expect(
        await service.initialize(),
        DeviceRegistrationResult.registered,
      );

      await service.handleSessionEnded(userId: 'user-1');

      verify(() => gateway.deleteToken()).called(1);
      verify(() => gateway.getToken()).called(1);
      expect(
        await service.initialize(),
        DeviceRegistrationResult.registered,
      );
      verify(() => gateway.registerDevice('token-1',
          expectedUserId: any(named: 'expectedUserId'))).called(2);
    });

    test('delayed session end cannot clear a newly signed-in user', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_prompted:user-2': true,
      });
      when(() => gateway.currentUserId).thenReturn('user-2');
      final service = buildService();
      expect(
        await service.initialize(),
        DeviceRegistrationResult.registered,
      );

      await service.handleSessionEnded(userId: 'user-1');

      verifyNever(() => gateway.deleteToken());
      expect(
        await service.initialize(),
        DeviceRegistrationResult.alreadyRegistered,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('device_reg:user-2:token'), 'token-1');
    });

    test('distinct session-end events are serialized rather than dropped',
        () async {
      when(() => gateway.currentUserId).thenReturn(null);
      when(() => gateway.hasActiveSession).thenReturn(false);
      final firstDelete = Completer<void>();
      var deleteCalls = 0;
      when(() => gateway.deleteToken()).thenAnswer((_) {
        deleteCalls += 1;
        return deleteCalls == 1 ? firstDelete.future : Future<void>.value();
      });
      final service = buildService();

      final firstCleanup = service.handleSessionEnded(userId: 'user-1');
      await Future<void>.delayed(Duration.zero);
      final secondCleanup = service.handleSessionEnded(userId: 'user-2');
      firstDelete.complete();

      await Future.wait([firstCleanup, secondCleanup]);
      verify(() => gateway.deleteToken()).called(2);
    });
  });
}
