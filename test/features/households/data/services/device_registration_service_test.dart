import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
      when(() => gateway.onTokenRefresh)
          .thenAnswer((_) => tokenRefreshController.stream);
      when(() => gateway.requestMessagingPermission())
          .thenAnswer((_) async => _authorizedSettings);
      when(() => gateway.configureForegroundPresentation())
          .thenAnswer((_) async {});
      when(() => gateway.getToken())
          .thenAnswer((_) => Future<String?>.value('token-1'));
      when(() => gateway.deleteToken()).thenAnswer((_) async {});
      when(() => gateway.registerDevice('token-1'))
          .thenAnswer((_) async => true);
      when(() => gateway.unregisterDevice('token-1'))
          .thenAnswer((_) async => true);
      when(() => gateway.unregisterDevice('token-2'))
          .thenAnswer((_) async => true);
    });

    tearDown(() async {
      await tokenRefreshController.close();
    });

    test('backend rejection remains retryable and is not initialized',
        () async {
      when(() => gateway.registerDevice('token-1'))
          .thenAnswer((_) async => false);
      final service = buildService();

      final firstResult = await service.initialize();
      expect(firstResult, DeviceRegistrationResult.backendRejected);
      expect(
        await service.initialize(),
        DeviceRegistrationResult.backendRejected,
      );

      verify(() => gateway.registerDevice('token-1')).called(2);
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

      verifyNever(() => gateway.registerDevice(any()));
    });

    test('explicit repair bypasses prompt and fresh local cache', () async {
      SharedPreferences.setMockInitialValues({
        'device_reg:user-1:token': 'token-1',
        'device_reg:user-1:registered_at': DateTime.now().toIso8601String(),
      });
      final service = buildService();

      final result = await service.repairDeviceRegistration();

      expect(result, DeviceRegistrationResult.registered);
      verify(() => gateway.registerDevice('token-1')).called(1);
      verifyNever(() => gateway.unregisterDevice(any()));
      verifyNever(() => gateway.deleteToken());
    });

    test('unregister failure cannot block the next initialization', () async {
      final service = buildService();
      expect(
        await service.initialize(),
        DeviceRegistrationResult.registered,
      );
      when(() => gateway.unregisterDevice('token-1'))
          .thenThrow(Exception('offline'));

      await service.unregisterDevice();
      final secondResult = await service.initialize();

      expect(secondResult, DeviceRegistrationResult.registered);
      verify(() => gateway.registerDevice('token-1')).called(2);
      verify(() => gateway.deleteToken()).called(1);
    });

    test('concurrent initialization performs one backend upsert', () async {
      final registration = Completer<bool>();
      when(() => gateway.registerDevice('token-1'))
          .thenAnswer((_) => registration.future);
      final service = buildService();

      final first = service.initialize();
      final second = service.initialize();
      registration.complete(true);

      expect(await first, DeviceRegistrationResult.registered);
      expect(await second, DeviceRegistrationResult.registered);
      verify(() => gateway.registerDevice('token-1')).called(1);
    });

    test('token refresh registers the replacement token', () async {
      when(() => gateway.registerDevice('token-2'))
          .thenAnswer((_) async => true);
      final service = buildService();
      expect(
        await service.initialize(),
        DeviceRegistrationResult.registered,
      );

      tokenRefreshController.add('token-2');
      await Future<void>.delayed(Duration.zero);

      verify(() => gateway.registerDevice('token-2')).called(1);
      verify(() => gateway.unregisterDevice('token-1')).called(1);
    });

    test('overlapping token refreshes persist only the latest token', () async {
      final token2Registration = Completer<bool>();
      when(() => gateway.registerDevice('token-2'))
          .thenAnswer((_) => token2Registration.future);
      when(() => gateway.registerDevice('token-3'))
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
        () => gateway.registerDevice('token-2'),
        () => gateway.registerDevice('token-3'),
      ]);
      verify(() => gateway.unregisterDevice('token-1')).called(1);
      verify(() => gateway.unregisterDevice('token-2')).called(1);
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
      verify(() => gateway.registerDevice('token-1')).called(2);
    });

    test('logout waits for initialization and removes its backend token',
        () async {
      final registration = Completer<bool>();
      when(() => gateway.registerDevice('token-1'))
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
      verify(() => gateway.unregisterDevice('token-1')).called(1);
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
      when(() => gateway.registerDevice('token-1'))
          .thenAnswer((_) => registration.future);
      final service = buildService();

      final initialization = service.initialize();
      await Future<void>.delayed(Duration.zero);
      final logout = service.unregisterDevice();
      when(() => gateway.currentUserId).thenReturn('user-2');
      registration.complete(true);

      await initialization;
      await logout;
      verifyNever(() => gateway.unregisterDevice('token-2'));
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
      verify(() => gateway.registerDevice('token-1')).called(2);
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
      verify(() => gateway.registerDevice('token-1')).called(2);
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
