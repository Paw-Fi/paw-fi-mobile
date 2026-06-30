import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/monitoring/auth_logout_debug_telemetry.dart';

void main() {
  group('AuthLogoutDebugTelemetry', () {
    test('rememberRoute redacts opaque path identifiers', () {
      AuthLogoutDebugTelemetry.rememberRoute(
        '/households/550e8400-e29b-41d4-a716-446655440000/settings'
        '?tab=members',
      );

      expect(
        AuthLogoutDebugTelemetry.currentRoute,
        '/households/<id>/settings',
      );
    });

    test('auth state payload is token-free and includes transition context',
        () {
      final payload = AuthLogoutDebugTelemetry.authStatePayload(
        event: 'tokenRefreshed',
        previousUserId: 'user-123',
        nextUserId: 'user-123',
        hasSession: true,
        sessionExpiresAt: 1893456000,
        sessionIsExpired: false,
        lifecycleState: 'resumed',
        route: '/dashboard',
        platform: 'android',
        appVersion: '2.2.1+195',
      );

      expect(payload['event'], 'tokenRefreshed');
      expect(payload['previousAuthState'], 'authenticated');
      expect(payload['nextAuthState'], 'authenticated');
      expect(payload['userChanged'], isFalse);
      expect(payload['sessionPresent'], isTrue);
      expect(payload['sessionExpiresAt'], 1893456000);
      expect(payload['sessionIsExpired'], isFalse);
      expect(payload['lifecycleState'], 'resumed');
      expect(payload['route'], '/dashboard');
      expect(payload['platform'], 'android');
      expect(payload['appVersion'], '2.2.1+195');
      expect(payload.containsKey('accessToken'), isFalse);
      expect(payload.containsKey('refreshToken'), isFalse);
      expect(payload.values, isNot(contains('user-123')));
      expect(payload['nextUserIdHash'], isNotEmpty);
    });

    test('auth stream error payload classifies refresh token reuse', () {
      final payload = AuthLogoutDebugTelemetry.authStreamErrorPayload(
        error: Exception('Invalid Refresh Token: Already Used'),
        hasSession: true,
        sessionExpiresAt: 1893456000,
        sessionIsExpired: true,
        lifecycleState: 'resumed',
        route: '/dashboard',
        platform: 'android',
        appVersion: '2.2.1+195',
        notificationCapture: const AuthDebugNativeCaptureSnapshot(
          available: true,
          enabled: true,
          hasAuthStorage: true,
          hasCredentials: true,
          isReady: true,
          hasNotificationAccess: true,
          enabledPackagesCount: 2,
          expiresAt: 1893456000,
          isAccessTokenExpired: true,
        ),
      );

      expect(payload['errorKind'], 'refresh_token_reuse');
      expect(payload['sessionPresent'], isTrue);
      expect(payload['sessionIsExpired'], isTrue);
      expect(payload['notificationCaptureEnabled'], isTrue);
      expect(payload['notificationCaptureReady'], isTrue);
      expect(payload['notificationCaptureEnabledPackagesCount'], 2);
      expect(payload.values.join('|').contains('Already Used'), isFalse);
    });
  });

  group('AuthLogoutDebugSnapshot', () {
    test('support snapshot includes auth and native capture state only', () {
      const debugSnapshot = AuthLogoutDebugSnapshot(
        platform: 'android',
        appVersion: '2.2.1+195',
        lifecycleState: 'resumed',
        route: '/settings',
        flutterSession: AuthDebugSessionSnapshot(
          hasSession: true,
          isExpired: false,
          expiresAt: 1893456000,
          userId: 'user-123',
        ),
        androidNotificationCapture: AuthDebugNativeCaptureSnapshot(
          available: true,
          enabled: true,
          hasAuthStorage: true,
          hasCredentials: true,
          isReady: true,
          hasNotificationAccess: true,
          enabledPackagesCount: 3,
          expiresAt: 1893456000,
          isAccessTokenExpired: false,
        ),
      );
      final snapshot = debugSnapshot.toJson();

      expect(snapshot['platform'], 'android');
      expect(snapshot['flutterSessionPresent'], isTrue);
      expect(snapshot['flutterSessionExpired'], isFalse);
      expect(snapshot['flutterSessionExpiresAt'], 1893456000);
      expect(snapshot['flutterUserIdHash'], isNotEmpty);
      expect(snapshot['androidNotificationCaptureEnabled'], isTrue);
      expect(
          snapshot['androidNotificationCaptureHasNotificationAccess'], isTrue);
      expect(snapshot['androidNotificationCaptureEnabledPackagesCount'], 3);
      expect(snapshot.values, isNot(contains('user-123')));
      expect(snapshot.containsKey('accessToken'), isFalse);
      expect(snapshot.containsKey('refreshToken'), isFalse);
    });
  });
}
