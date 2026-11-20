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
    initializeSessionBridge(
        authReady: () async => Supabase.instance.client.auth);
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
  int _authGeneration = 0;
  int _authClears = 0;
  int _authTransitions = 0;
  Future<void>? _authTransitionTail;
  bool get _authBlocked => _authClears != 0 || _authTransitions != 0;
  Future<GoTrueClient> Function() _authReady =
      () async => Supabase.instance.client.auth;
  Future<AuthResponse>? _sessionRefresh;
  GoTrueClient? _sessionRefreshOwner;

  /// Native workers can request credentials before any Activity or shell exists.
  /// This handler must never await native replay: its dispatcher is awaiting us.
  void initializeSessionBridge({
    required Future<GoTrueClient> Function() authReady,
  }) {
    if (!_isAndroid) return;
    _authReady = authReady;
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments;
      if (call.method == 'capturesChanged' && arguments is Map) {
        await _publishRevision(arguments);
        return null;
      }
      if (call.method != 'getCurrentSessionForNotificationCapture') {
        throw MissingPluginException();
      }
      final userId = arguments is Map ? arguments['userId'] as String? : null;
      final generation = _authGeneration;
      final auth = await _authReady();
      void checkOwner() {
        if (_authBlocked ||
            generation != _authGeneration ||
            userId == null ||
            userId.isEmpty ||
            auth.currentSession?.user.id != userId ||
            auth.currentUser?.id != userId) {
          throw PlatformException(code: 'capture_session_unavailable');
        }
      }

      checkOwner();
      if (arguments['forceRefresh'] == true ||
          !_hasUsableAccessToken(auth.currentSession)) {
        final response = await _refreshSession(auth);
        checkOwner();
        if (!_hasUsableAccessToken(response.session) ||
            response.session?.user.id != userId) {
          throw PlatformException(code: 'capture_session_unavailable');
        }
      }
      checkOwner();
      final session = auth.currentSession;
      if (!_hasUsableAccessToken(session)) {
        throw PlatformException(code: 'capture_session_unavailable');
      }
      return <String, Object?>{
        'accessToken': session!.accessToken,
        'userId': session.user.id,
        'expiresAt': session.expiresAt,
      };
    });
  }

  bool _hasUsableAccessToken(Session? session) =>
      session != null &&
      session.accessToken.isNotEmpty &&
      !session.isExpired &&
      (session.expiresAt ?? 0) >
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30;

  Future<AuthResponse> _refreshSession(GoTrueClient auth) {
    if (_authBlocked ||
        (_sessionRefresh != null && !identical(_sessionRefreshOwner, auth))) {
      throw PlatformException(code: 'capture_session_unavailable');
    }
    if (_sessionRefresh != null) return _sessionRefresh!;
    final refresh = auth.refreshSession();
    _sessionRefresh = refresh;
    _sessionRefreshOwner = auth;
    void clear() {
      if (identical(_sessionRefresh, refresh)) {
        _sessionRefresh = null;
        _sessionRefreshOwner = null;
      }
    }

    refresh.then<void>((_) => clear(), onError: (Object _) => clear());
    return refresh;
  }

  /// Serializes explicit Android session changes with capture-owned refresh.
  /// GoTrue saves refresh responses before returning, so a reply fence alone
  /// cannot protect logout or a new actor. Do not nest transitions.
  Future<T> runAuthTransition<T>(Future<T> Function() action) {
    if (!_isAndroid) return action();
    // Close admission synchronously, including while another transition waits.
    _authTransitions++;
    _authGeneration++;
    final previous = _authTransitionTail;
    final done = Completer<void>();
    _authTransitionTail = done.future;
    return () async {
      try {
        await previous;
        final refresh = _sessionRefresh;
        try {
          // Invalidate native credentials now, retaining the original actor's
          // queue if authentication fails without actually changing the session.
          await _channel.invokeMethod<void>('suspendAuthContext');
        } finally {
          // Even a failed native clear must not reopen admission before the SDK
          // finishes mutating its session. Refresh failure must not prevent logout.
          try {
            await refresh;
          } catch (_) {}
        }
        return await action();
      } finally {
        _authGeneration++;
        _authTransitions--;
        if (_authTransitions == 0) {
          // Auth events during the transition were intentionally not exported.
          // Publish only the final SDK session; never sign out a newer actor.
          try {
            final generation = _authGeneration;
            final auth = await _authReady();
            final session = auth.currentSession;
            if (!_authBlocked && generation == _authGeneration) {
              if (session == null) {
                await clearAuthContext();
              } else {
                await syncAuthContext(
                  supabaseUrl: Constants.supabaseUrl,
                  supabaseAnonKey: Constants.supabaseAnon,
                  accessToken: session.accessToken,
                  userId: session.user.id,
                  expiresAt: session.expiresAt ?? 0,
                );
              }
            }
          } catch (_) {
            // Normal foreground auth synchronization can retry native transport.
          }
        }
        done.complete();
        if (identical(_authTransitionTail, done.future)) {
          _authTransitionTail = null;
        }
      }
    }();
  }

  /// Background startup initializes auth only; UI waits for a real Android host.
  Future<void> waitForForegroundHost() async {
    if (_isAndroid) await _channel.invokeMethod<void>('awaitForegroundHost');
  }

  Future<void> _publishRevision(Map<dynamic, dynamic> status) async {
    final generation = _authGeneration;
    final auth = await _authReady();
    final userId = status['userId'] as String?;
    final revision = (status['revision'] as num?)?.toInt() ?? 0;
    if (_authBlocked ||
        generation != _authGeneration ||
        userId == null ||
        userId != auth.currentUser?.id ||
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
    await _publishRevision(status);
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
    if (!_isAndroid || _authBlocked) return;
    final generation = _authGeneration;
    final auth = await _authReady();
    if (_authBlocked ||
        generation != _authGeneration ||
        auth.currentSession?.user.id != userId ||
        auth.currentSession?.accessToken != accessToken) {
      return;
    }
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
    _authGeneration++;
    _authClears++;
    _revisions.clear();
    _syncedAuthUserId = null;
    try {
      await _channel.invokeMethod<void>('clearAuthContext');
    } finally {
      _authClears--;
    }
  }

  Future<void> syncPendingCaptures() {
    if (!_isAndroid || _authBlocked) return Future.value();
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
    final generation = _authGeneration;
    var forceRefresh = false;
    for (var attempt = 0; attempt < 2; attempt++) {
      var session = client.auth.currentSession;
      if (_authBlocked ||
          generation != _authGeneration ||
          session == null ||
          session.user.id != userId) {
        return;
      }
      final expiresSoon = session.expiresAt != null &&
          session.expiresAt! <=
              DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30;
      if (forceRefresh || session.isExpired || expiresSoon) {
        session = (await _refreshSession(client.auth)).session;
      }
      if (_authBlocked ||
          generation != _authGeneration ||
          session == null ||
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
      await _publishRevision(status);
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
