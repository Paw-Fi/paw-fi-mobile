import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/util/constants.dart';

bool shouldRemovePendingNotificationCapture({
  required int status,
  Object? responseBody,
}) {
  final isRequestInProgress = switch (responseBody) {
    Map() => responseBody['code']?.toString() == 'REQUEST_IN_PROGRESS',
    String() => responseBody.contains('REQUEST_IN_PROGRESS'),
    _ => false,
  };
  if (status == 409 && isRequestInProgress) return false;
  if (status == 200 || status == 201) {
    return responseBody is Map &&
        responseBody['success'] == true &&
        (responseBody['ignored'] == true ||
            responseBody['duplicate'] == true ||
            (responseBody['data'] is Map &&
                (responseBody['data'] as Map)['id'] is String &&
                ((responseBody['data'] as Map)['id'] as String)
                    .trim()
                    .isNotEmpty));
  }
  return status == 400 || status == 403 || status == 409 || status == 422;
}

/// Replays a batch for its original actor, stopping on transient failure or an
/// account switch. The caller must also freeze that actor's Authorization header.
Future<List<String>> replayPendingNotificationCaptures({
  required String userId,
  required List<Map<dynamic, dynamic>> records,
  required String? Function() currentUserId,
  required Future<FunctionResponse> Function(
    String functionName,
    Map<String, dynamic> body,
  ) invoke,
}) async {
  final completedIds = <String>[];
  for (final rawRecord in records) {
    if (currentUserId() != userId) break;
    final record = Map<String, dynamic>.from(rawRecord);
    final id = record['id']?.toString() ?? '';
    final owner = record['userId']?.toString() ?? '';
    final rawBody = record['body']?.toString() ?? '';
    if (id.isEmpty || owner != userId || rawBody.isEmpty) continue;
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is! Map<String, dynamic>) {
        completedIds.add(id);
        continue;
      }
      final response = await invoke(
        decoded['notification'] is Map
            ? 'classify-notification-capture'
            : 'save-wallet-transaction',
        decoded,
      );
      if (!shouldRemovePendingNotificationCapture(
        status: response.status,
        responseBody: response.data,
      )) {
        break;
      }
      completedIds.add(id);
    } on FunctionException catch (error) {
      if (!shouldRemovePendingNotificationCapture(
        status: error.status,
        responseBody: error.details,
      )) {
        break;
      }
      completedIds.add(id);
    } catch (_) {
      break;
    }
  }
  return completedIds;
}

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
    this.accountId,
    this.accountName,
    this.accountCurrency,
    required this.hasAuthStorage,
    required this.hasCredentials,
    required this.isReady,
    required this.expiresAt,
    required this.isAccessTokenExpired,
    required this.hasNotificationAccess,
    required this.enabledPackages,
    required this.recentApps,
  });

  final bool enabled;
  final String scopeId;
  final String scopeName;
  final bool isPortfolio;
  final String? accountId;
  final String? accountName;
  final String? accountCurrency;
  final bool hasAuthStorage;
  final bool hasCredentials;
  final bool isReady;
  final int expiresAt;
  final bool isAccessTokenExpired;
  final bool hasNotificationAccess;
  final List<String> enabledPackages;
  final List<RecentNotificationApp> recentApps;

  factory NotificationCaptureConfig.fromMap(Map<String, dynamic> map) {
    final rawApps = map['recentApps'] as List<dynamic>? ?? [];
    final rawPackages = map['enabledPackages'] as List<dynamic>? ?? [];
    String? optionalString(Object? value) {
      final raw = value as String?;
      final trimmed = raw?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    return NotificationCaptureConfig(
      enabled: map['enabled'] as bool? ?? false,
      scopeId: map['scopeId'] as String? ?? 'personal',
      scopeName: map['scopeName'] as String? ?? 'Personal',
      isPortfolio: map['isPortfolio'] as bool? ?? false,
      accountId: optionalString(map['accountId']),
      accountName: optionalString(map['accountName']),
      accountCurrency: optionalString(map['accountCurrency'])?.toUpperCase(),
      hasAuthStorage: map['hasAuthStorage'] as bool? ?? true,
      hasCredentials: map['hasCredentials'] as bool? ?? false,
      isReady: map['isReady'] as bool? ?? false,
      expiresAt: (map['expiresAt'] as num?)?.toInt() ?? 0,
      isAccessTokenExpired: map['isAccessTokenExpired'] as bool? ?? false,
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
    String? accountId,
    String? accountName,
    String? accountCurrency,
    bool clearAccountSelection = false,
    bool? hasAuthStorage,
    bool? hasCredentials,
    bool? isReady,
    int? expiresAt,
    bool? isAccessTokenExpired,
    bool? hasNotificationAccess,
    List<String>? enabledPackages,
    List<RecentNotificationApp>? recentApps,
  }) {
    return NotificationCaptureConfig(
      enabled: enabled ?? this.enabled,
      scopeId: scopeId ?? this.scopeId,
      scopeName: scopeName ?? this.scopeName,
      isPortfolio: isPortfolio ?? this.isPortfolio,
      accountId: clearAccountSelection ? null : accountId ?? this.accountId,
      accountName:
          clearAccountSelection ? null : accountName ?? this.accountName,
      accountCurrency: clearAccountSelection
          ? null
          : accountCurrency ?? this.accountCurrency,
      hasAuthStorage: hasAuthStorage ?? this.hasAuthStorage,
      hasCredentials: hasCredentials ?? this.hasCredentials,
      isReady: isReady ?? this.isReady,
      expiresAt: expiresAt ?? this.expiresAt,
      isAccessTokenExpired: isAccessTokenExpired ?? this.isAccessTokenExpired,
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
    accountId: null,
    accountName: null,
    accountCurrency: null,
    hasAuthStorage: true,
    hasCredentials: false,
    isReady: false,
    expiresAt: 0,
    isAccessTokenExpired: false,
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
  NotificationCaptureService._() {
    if (_isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'capturesChanged' && call.arguments is Map) {
          _publishRevision(Map<dynamic, dynamic>.from(call.arguments as Map));
        }
      });
    }
  }

  static final NotificationCaptureService instance =
      NotificationCaptureService._();

  static const MethodChannel _channel =
      MethodChannel('moneko/notification_capture');
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final _capturesSynced = StreamController<String>.broadcast();
  final _revisions = <String, int>{};
  Stream<String> get capturesSynced => _capturesSynced.stream;
  Future<void>? _pendingCaptureSync;
  String? _pendingCaptureUserId;
  String? _syncedAuthUserId;

  void _publishRevision(Map<dynamic, dynamic> status) {
    final userId = status['userId'] as String?;
    final revision = (status['revision'] as num?)?.toInt() ?? 0;
    if (userId == null ||
        userId != Supabase.instance.client.auth.currentUser?.id ||
        revision <= (_revisions[userId] ?? 0)) {
      return;
    }
    _revisions[userId] = revision;
    _capturesSynced.add(userId);
  }

  Future<Map<dynamic, dynamic>> getPendingCaptureStatus() async {
    if (!_isAndroid) return const {};
    final status = await _channel.invokeMapMethod<dynamic, dynamic>(
          'getPendingCaptureStatus',
        ) ??
        const {};
    _publishRevision(status);
    return status;
  }

  /// Sync Supabase auth credentials to the native Android layer so the
  /// background NotificationListenerService can call save-wallet-transaction.
  Future<void> syncAuthContext({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String accessToken,
    required String userId,
    required int expiresAt,
  }) async {
    if (!_isAndroid) return;
    if (_syncedAuthUserId != userId) {
      _revisions.remove(userId);
      _syncedAuthUserId = userId;
    }
    await _channel.invokeMethod<void>('syncAuthContext', {
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': supabaseAnonKey,
      'accessToken': accessToken,
      'userId': userId,
      'expiresAt': expiresAt,
    });
  }

  Future<void> clearAuthContext() async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('clearAuthContext');
    _revisions.clear();
    _syncedAuthUserId = null;
  }

  Future<void> syncPendingCaptures() {
    if (!_isAndroid) return Future.value();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return Future.value();
    final inFlight = _pendingCaptureSync;
    if (inFlight != null) {
      if (_pendingCaptureUserId == userId) return inFlight;
      // A new actor must not join a previous actor's replay or inherit its token.
      return inFlight
          .catchError((Object _) {})
          .then((_) => syncPendingCaptures());
    }
    final sync = _syncPendingCaptures(userId);
    _pendingCaptureSync = sync;
    _pendingCaptureUserId = userId;
    return sync.whenComplete(() {
      if (identical(_pendingCaptureSync, sync)) {
        _pendingCaptureSync = null;
        _pendingCaptureUserId = null;
      }
    });
  }

  Future<void> _syncPendingCaptures(String userId) async {
    final client = Supabase.instance.client;
    var forceRefresh = false;
    for (var attempt = 0; attempt < 2; attempt++) {
      var session = client.auth.currentSession;
      if (session == null || session.user.id != userId) return;
      final expiresSoon = session.expiresAt != null &&
          session.expiresAt! <=
              DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30;
      if (forceRefresh || session.isExpired || expiresSoon) {
        session = (await client.auth.refreshSession()).session;
      }
      if (session == null ||
          session.user.id != userId ||
          client.auth.currentUser?.id != userId) {
        return;
      }
      await syncAuthContext(
        supabaseUrl: Constants.supabaseUrl,
        supabaseAnonKey: Constants.supabaseAnon,
        accessToken: session.accessToken,
        userId: userId,
        expiresAt: session.expiresAt ?? 0,
      );
      if (client.auth.currentUser?.id != userId) return;
      final status = await _channel.invokeMapMethod<dynamic, dynamic>(
        'syncPendingCaptures',
        {'userId': userId},
      );
      if (status == null || client.auth.currentUser?.id != userId) return;
      _publishRevision(status);
      if (status['requiresSessionRefresh'] != true) return;
      forceRefresh = true;
    }
  }

  /// Retrieve the full notification capture configuration from native.
  Future<NotificationCaptureConfig> getConfig() async {
    if (!_isAndroid) return NotificationCaptureConfig.disabled;
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
    String? accountId,
    String? accountName,
    String? accountCurrency,
    bool clearAccount = false,
  }) async {
    if (!_isAndroid) return;
    final args = <String, dynamic>{};
    if (enabled != null) args['enabled'] = enabled;
    if (scopeId != null) args['scopeId'] = scopeId;
    if (scopeName != null) args['scopeName'] = scopeName;
    if (isPortfolio != null) args['isPortfolio'] = isPortfolio;
    if (clearAccount) {
      args['accountId'] = null;
      args['accountName'] = null;
      args['accountCurrency'] = null;
    } else {
      if (accountId != null) args['accountId'] = accountId;
      if (accountName != null) args['accountName'] = accountName;
      if (accountCurrency != null) args['accountCurrency'] = accountCurrency;
    }
    await _channel.invokeMethod<void>('setConfig', args);
  }

  /// Enable or disable capture for a specific notification source app.
  Future<void> setPackageEnabled({
    required String packageName,
    required bool enabled,
  }) async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('setPackageEnabled', {
      'packageName': packageName,
      'enabled': enabled,
    });
  }

  /// Get the list of recently-seen notification source apps.
  Future<List<RecentNotificationApp>> getRecentApps() async {
    if (!_isAndroid) return [];
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
    if (!_isAndroid) return false;
    final result = await _channel.invokeMethod<bool>('checkNotificationAccess');
    return result ?? false;
  }

  /// Open system Notification Access settings so the user can grant access.
  Future<void> openNotificationSettings() async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('openNotificationSettings');
  }

  /// Update the destination scope for auto-captured transactions.
  Future<void> setDestinationScope({
    required String scopeId,
    required String scopeName,
    required bool isPortfolio,
    String? accountId,
    String? accountName,
    String? accountCurrency,
  }) async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('setConfig', {
      'scopeId': scopeId,
      'scopeName': scopeName,
      'isPortfolio': isPortfolio,
      'accountId': accountId ?? '',
      'accountName': accountName ?? '',
      'accountCurrency': accountCurrency ?? '',
    });
  }
}
