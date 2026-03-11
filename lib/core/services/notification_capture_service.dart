import 'dart:io';

import 'package:flutter/services.dart';

/// Data class representing a recently-seen notification source app.
class RecentNotificationApp {
  const RecentNotificationApp({
    required this.packageName,
    required this.appLabel,
    required this.lastSeenAt,
    required this.enabled,
  });

  final String packageName;
  final String appLabel;
  final int lastSeenAt;
  final bool enabled;

  factory RecentNotificationApp.fromMap(Map<String, dynamic> map) {
    return RecentNotificationApp(
      packageName: map['packageName'] as String? ?? '',
      appLabel: map['appLabel'] as String? ?? '',
      lastSeenAt: (map['lastSeenAt'] as num?)?.toInt() ?? 0,
      enabled: map['enabled'] as bool? ?? false,
    );
  }
}

/// Configuration state for Android notification-based transaction capture.
class NotificationCaptureConfig {
  const NotificationCaptureConfig({
    required this.enabled,
    required this.scopeId,
    required this.scopeName,
    required this.isPortfolio,
    required this.hasNotificationAccess,
    required this.enabledPackages,
    required this.recentApps,
  });

  final bool enabled;
  final String scopeId;
  final String scopeName;
  final bool isPortfolio;
  final bool hasNotificationAccess;
  final List<String> enabledPackages;
  final List<RecentNotificationApp> recentApps;

  factory NotificationCaptureConfig.fromMap(Map<String, dynamic> map) {
    final rawApps = map['recentApps'] as List<dynamic>? ?? [];
    final rawPackages = map['enabledPackages'] as List<dynamic>? ?? [];

    return NotificationCaptureConfig(
      enabled: map['enabled'] as bool? ?? false,
      scopeId: map['scopeId'] as String? ?? 'personal',
      scopeName: map['scopeName'] as String? ?? 'Personal',
      isPortfolio: map['isPortfolio'] as bool? ?? false,
      hasNotificationAccess: map['hasNotificationAccess'] as bool? ?? false,
      enabledPackages: rawPackages.cast<String>().toList(),
      recentApps: rawApps
          .cast<Map<dynamic, dynamic>>()
          .map((e) => RecentNotificationApp.fromMap(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
    );
  }

  NotificationCaptureConfig copyWith({
    bool? enabled,
    String? scopeId,
    String? scopeName,
    bool? isPortfolio,
    bool? hasNotificationAccess,
    List<String>? enabledPackages,
    List<RecentNotificationApp>? recentApps,
  }) {
    return NotificationCaptureConfig(
      enabled: enabled ?? this.enabled,
      scopeId: scopeId ?? this.scopeId,
      scopeName: scopeName ?? this.scopeName,
      isPortfolio: isPortfolio ?? this.isPortfolio,
      hasNotificationAccess:
          hasNotificationAccess ?? this.hasNotificationAccess,
      enabledPackages: enabledPackages ?? this.enabledPackages,
      recentApps: recentApps ?? this.recentApps,
    );
  }

  static const NotificationCaptureConfig disabled = NotificationCaptureConfig(
    enabled: false,
    scopeId: 'personal',
    scopeName: 'Personal',
    isPortfolio: false,
    hasNotificationAccess: false,
    enabledPackages: [],
    recentApps: [],
  );
}

/// Flutter service bridging to the native Android MethodChannel for
/// notification-based transaction capture configuration.
///
/// Android-only — returns disabled/no-op on other platforms.
class NotificationCaptureService {
  NotificationCaptureService._();

  static final NotificationCaptureService instance =
      NotificationCaptureService._();

  static const MethodChannel _channel =
      MethodChannel('moneko/notification_capture');

  /// Sync Supabase auth credentials to the native Android layer so the
  /// background NotificationListenerService can call save-wallet-transaction.
  Future<void> syncAuthContext({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String accessToken,
    required String refreshToken,
    required String userId,
    required int expiresAt,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('syncAuthContext', {
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': supabaseAnonKey,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'userId': userId,
      'expiresAt': expiresAt,
    });
  }

  Future<void> clearAuthContext() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('clearAuthContext');
  }

  /// Retrieve the full notification capture configuration from native.
  Future<NotificationCaptureConfig> getConfig() async {
    if (!Platform.isAndroid) return NotificationCaptureConfig.disabled;
    final result = await _channel.invokeMapMethod<String, dynamic>('getConfig');
    if (result == null) return NotificationCaptureConfig.disabled;
    return NotificationCaptureConfig.fromMap(result);
  }

  /// Update config fields (enabled, scopeId, scopeName, isPortfolio).
  Future<void> setConfig({
    bool? enabled,
    String? scopeId,
    String? scopeName,
    bool? isPortfolio,
  }) async {
    if (!Platform.isAndroid) return;
    final args = <String, dynamic>{};
    if (enabled != null) args['enabled'] = enabled;
    if (scopeId != null) args['scopeId'] = scopeId;
    if (scopeName != null) args['scopeName'] = scopeName;
    if (isPortfolio != null) args['isPortfolio'] = isPortfolio;
    await _channel.invokeMethod<void>('setConfig', args);
  }

  /// Enable or disable capture for a specific notification source app.
  Future<void> setPackageEnabled({
    required String packageName,
    required bool enabled,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setPackageEnabled', {
      'packageName': packageName,
      'enabled': enabled,
    });
  }

  /// Get the list of recently-seen notification source apps.
  Future<List<RecentNotificationApp>> getRecentApps() async {
    if (!Platform.isAndroid) return [];
    final result = await _channel.invokeListMethod<dynamic>('getRecentApps');
    if (result == null) return [];
    return result
        .cast<Map<dynamic, dynamic>>()
        .map((e) => RecentNotificationApp.fromMap(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  /// Check whether the user has granted Notification Access to Moneko.
  Future<bool> checkNotificationAccess() async {
    if (!Platform.isAndroid) return false;
    final result = await _channel.invokeMethod<bool>('checkNotificationAccess');
    return result ?? false;
  }

  /// Open system Notification Access settings so the user can grant access.
  Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openNotificationSettings');
  }

  /// Update the destination scope for auto-captured transactions.
  Future<void> setDestinationScope({
    required String scopeId,
    required String scopeName,
    required bool isPortfolio,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setConfig', {
      'scopeId': scopeId,
      'scopeName': scopeName,
      'isPortfolio': isPortfolio,
    });
  }
}
