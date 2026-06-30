import 'dart:convert';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:moneko/core/util/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthDebugSessionSnapshot {
  const AuthDebugSessionSnapshot({
    required this.hasSession,
    required this.isExpired,
    required this.expiresAt,
    required this.userId,
  });

  final bool hasSession;
  final bool isExpired;
  final int? expiresAt;
  final String? userId;

  factory AuthDebugSessionSnapshot.fromSession(Session? session) {
    return AuthDebugSessionSnapshot(
      hasSession: session != null,
      isExpired: session?.isExpired ?? false,
      expiresAt: session?.expiresAt,
      userId: session?.user.id,
    );
  }
}

class AuthDebugNativeCaptureSnapshot {
  const AuthDebugNativeCaptureSnapshot({
    required this.available,
    required this.enabled,
    required this.hasAuthStorage,
    required this.hasCredentials,
    required this.isReady,
    required this.hasNotificationAccess,
    required this.enabledPackagesCount,
    required this.expiresAt,
    required this.isAccessTokenExpired,
  });

  final bool available;
  final bool enabled;
  final bool hasAuthStorage;
  final bool hasCredentials;
  final bool isReady;
  final bool hasNotificationAccess;
  final int enabledPackagesCount;
  final int expiresAt;
  final bool isAccessTokenExpired;

  static const unavailable = AuthDebugNativeCaptureSnapshot(
    available: false,
    enabled: false,
    hasAuthStorage: false,
    hasCredentials: false,
    isReady: false,
    hasNotificationAccess: false,
    enabledPackagesCount: 0,
    expiresAt: 0,
    isAccessTokenExpired: false,
  );
}

class AuthLogoutDebugSnapshot {
  const AuthLogoutDebugSnapshot({
    required this.platform,
    required this.appVersion,
    required this.lifecycleState,
    required this.route,
    required this.flutterSession,
    this.androidNotificationCapture,
    this.iosWalletCapture,
  });

  final String platform;
  final String appVersion;
  final String lifecycleState;
  final String route;
  final AuthDebugSessionSnapshot flutterSession;
  final AuthDebugNativeCaptureSnapshot? androidNotificationCapture;
  final AuthDebugNativeCaptureSnapshot? iosWalletCapture;

  Map<String, dynamic> toJson() {
    final android = androidNotificationCapture ??
        AuthDebugNativeCaptureSnapshot.unavailable;
    final ios = iosWalletCapture ?? AuthDebugNativeCaptureSnapshot.unavailable;

    return <String, dynamic>{
      'platform': platform,
      'appVersion': appVersion,
      'lifecycleState': lifecycleState,
      'route': route,
      'flutterSessionPresent': flutterSession.hasSession,
      'flutterSessionExpired': flutterSession.isExpired,
      'flutterSessionExpiresAt': flutterSession.expiresAt,
      'flutterUserIdHash':
          AuthLogoutDebugTelemetry.shortUserHash(flutterSession.userId),
      'androidNotificationCaptureAvailable': android.available,
      'androidNotificationCaptureEnabled': android.enabled,
      'androidNotificationCaptureHasAuthStorage': android.hasAuthStorage,
      'androidNotificationCaptureHasCredentials': android.hasCredentials,
      'androidNotificationCaptureReady': android.isReady,
      'androidNotificationCaptureHasNotificationAccess':
          android.hasNotificationAccess,
      'androidNotificationCaptureEnabledPackagesCount':
          android.enabledPackagesCount,
      'androidNotificationCaptureExpiresAt': android.expiresAt,
      'androidNotificationCaptureAccessTokenExpired':
          android.isAccessTokenExpired,
      'iosWalletCaptureAvailable': ios.available,
      'iosWalletCaptureEnabled': ios.enabled,
      'iosWalletCaptureHasCredentials': ios.hasCredentials,
      'iosWalletCaptureReady': ios.isReady,
      'iosWalletCaptureExpiresAt': ios.expiresAt,
      'iosWalletCaptureAccessTokenExpired': ios.isAccessTokenExpired,
    };
  }
}

class AuthLogoutDebugTelemetry {
  AuthLogoutDebugTelemetry._();

  static String _currentRoute = 'unknown';
  static String _appVersion = 'unknown';

  static void rememberRoute(String route) {
    final trimmed = route.trim();
    if (trimmed.isNotEmpty) {
      _currentRoute = _sanitizeRoute(trimmed);
    }
  }

  static void setAppVersion(String appVersion) {
    final trimmed = appVersion.trim();
    if (trimmed.isNotEmpty) {
      _appVersion = trimmed;
    }
  }

  static String get currentRoute => _currentRoute;
  static String get appVersion => _appVersion;

  static String currentLifecycleState() {
    return WidgetsBinding.instance.lifecycleState?.name ?? 'unknown';
  }

  static String currentPlatform() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  static Map<String, dynamic> authStatePayload({
    required String event,
    required String? previousUserId,
    required String? nextUserId,
    required bool hasSession,
    required int? sessionExpiresAt,
    required bool sessionIsExpired,
    required String lifecycleState,
    required String route,
    required String platform,
    required String appVersion,
  }) {
    return <String, dynamic>{
      'event': event,
      'previousAuthState': _authStateName(previousUserId),
      'nextAuthState': _authStateName(nextUserId),
      'previousUserIdHash': shortUserHash(previousUserId),
      'nextUserIdHash': shortUserHash(nextUserId),
      'userChanged': (previousUserId ?? '') != (nextUserId ?? ''),
      'sessionPresent': hasSession,
      'sessionExpiresAt': sessionExpiresAt,
      'sessionIsExpired': sessionIsExpired,
      'lifecycleState': lifecycleState,
      'route': route,
      'platform': platform,
      'appVersion': appVersion,
    };
  }

  static Map<String, dynamic> authStreamErrorPayload({
    required Object error,
    required bool hasSession,
    required int? sessionExpiresAt,
    required bool sessionIsExpired,
    required String lifecycleState,
    required String route,
    required String platform,
    required String appVersion,
    AuthDebugNativeCaptureSnapshot? notificationCapture,
  }) {
    final capture =
        notificationCapture ?? AuthDebugNativeCaptureSnapshot.unavailable;

    return <String, dynamic>{
      'errorKind': classifyAuthError(error),
      'errorType': error.runtimeType.toString(),
      'errorFingerprint': _shortHash(error.toString()),
      'sessionPresent': hasSession,
      'sessionExpiresAt': sessionExpiresAt,
      'sessionIsExpired': sessionIsExpired,
      'lifecycleState': lifecycleState,
      'route': route,
      'platform': platform,
      'appVersion': appVersion,
      'notificationCaptureAvailable': capture.available,
      'notificationCaptureEnabled': capture.enabled,
      'notificationCaptureHasAuthStorage': capture.hasAuthStorage,
      'notificationCaptureHasCredentials': capture.hasCredentials,
      'notificationCaptureReady': capture.isReady,
      'notificationCaptureHasNotificationAccess': capture.hasNotificationAccess,
      'notificationCaptureEnabledPackagesCount': capture.enabledPackagesCount,
      'notificationCaptureExpiresAt': capture.expiresAt,
      'notificationCaptureAccessTokenExpired': capture.isAccessTokenExpired,
    };
  }

  static String classifyAuthError(Object error) {
    String? code;
    String? statusCode;
    if (error is AuthApiException) {
      code = error.code?.toLowerCase();
      statusCode = error.statusCode?.toLowerCase();
    }

    final message = error.toString().toLowerCase();
    if (code == 'refresh_token_already_used' ||
        message.contains('refresh_token_already_used') ||
        message.contains('invalid refresh token: already used') ||
        message.contains('refresh token: already used')) {
      return 'refresh_token_reuse';
    }
    if (code == 'refresh_token_not_found' ||
        message.contains('refresh_token_not_found') ||
        message.contains('refresh token not found')) {
      return 'refresh_token_missing';
    }
    if (code == 'flow_state_not_found' ||
        statusCode == 'flow_state_not_found' ||
        message.contains('flow_state_not_found') ||
        message.contains('flow state not found')) {
      return 'flow_state_missing';
    }
    if (_isNetworkError(message)) {
      return 'network';
    }
    return 'other';
  }

  static String shortUserHash(String? userId) {
    final normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return '';
    }
    return _shortHash(normalized);
  }

  static void logAuthStateEvent(Map<String, dynamic> payload) {
    _logPayload('auth_state_event', payload);
  }

  static void logSupportSnapshot(AuthLogoutDebugSnapshot snapshot) {
    _logPayload('auth_logout_support_snapshot', snapshot.toJson());
  }

  static void recordAuthStreamError(
    Object error,
    StackTrace? stackTrace,
    Map<String, dynamic> payload,
  ) {
    _logPayload('auth_stream_error', payload);
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: false,
        reason: 'auth_stream_error:${payload['errorKind']}',
      );
    } catch (_) {}
  }

  static void _logPayload(String eventName, Map<String, dynamic> payload) {
    final encoded = jsonEncode(payload);
    appLog('$eventName $encoded', name: 'AuthDebug');

    try {
      FirebaseCrashlytics.instance.log('$eventName $encoded');
      FirebaseCrashlytics.instance.setCustomKey(
        'auth_debug_last_event',
        eventName,
      );
      FirebaseCrashlytics.instance.setCustomKey(
        'auth_debug_last_payload',
        encoded.length > 900 ? encoded.substring(0, 900) : encoded,
      );
    } catch (_) {}
  }

  static String _authStateName(String? userId) {
    final normalized = userId?.trim();
    return normalized == null || normalized.isEmpty
        ? 'anonymous'
        : 'authenticated';
  }

  static String _sanitizeRoute(String route) {
    final withoutQuery = route.split('?').first.split('#').first;
    return withoutQuery
        .split('/')
        .map((segment) => _isSensitiveRouteSegment(segment) ? '<id>' : segment)
        .join('/');
  }

  static bool _isSensitiveRouteSegment(String segment) {
    if (segment.isEmpty) return false;
    final normalized = segment.toLowerCase();
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );
    if (uuidPattern.hasMatch(normalized)) return true;

    final opaqueIdPattern = RegExp(r'^[a-z0-9_-]{20,}$');
    return opaqueIdPattern.hasMatch(normalized);
  }

  static bool _isNetworkError(String message) {
    return message.contains('socketexception') ||
        message.contains('connection reset') ||
        message.contains('connection terminated') ||
        message.contains('handshakeexception') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('clientexception');
  }

  static String _shortHash(String value) {
    var hash = 0x811C9DC5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
