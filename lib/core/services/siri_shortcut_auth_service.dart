import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SiriShortcutAuthService {
  SiriShortcutAuthService._();

  static final SiriShortcutAuthService instance = SiriShortcutAuthService._();

  static const MethodChannel _channel =
      MethodChannel('moneko/siri_shortcut_auth');

  Future<Map<String, dynamic>>? _syncAuthAndCaptureFuture;
  Future<void>? _clearAuthFuture;
  Future<void>? _sessionRefreshFuture;
  GoTrueClient? _sessionRefreshAuth;
  _SiriShortcutAuthSyncRequest? _activeSyncRequest;
  _SiriShortcutAuthSyncRequest? _queuedSyncRequest;
  int _syncGeneration = 0;
  final _walletCapturesSynced = StreamController<String>.broadcast();

  Stream<String> get walletCapturesSynced => _walletCapturesSynced.stream;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Available during engine startup, without waiting for a mounted app shell.
  /// Refresh-token rotation and persistence stay with the existing GoTrue client.
  void initializeSessionBridge({
    required Future<GoTrueClient> Function() authReady,
  }) {
    if (!_isIOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'getCurrentSessionForWalletCapture') {
        throw MissingPluginException();
      }
      final arguments = Map<Object?, Object?>.from(call.arguments as Map);
      final userId = arguments['userId'] as String?;
      if (userId == null || userId.isEmpty) {
        throw PlatformException(code: 'capture_session_unavailable');
      }
      final auth = await authReady();
      final clearFuture = _clearAuthFuture;
      if (clearFuture != null) await clearFuture;
      final generation = _syncGeneration;
      void checkOwner() {
        if (generation != _syncGeneration ||
            auth.currentSession?.user.id != userId) {
          throw PlatformException(code: 'capture_session_unavailable');
        }
      }

      checkOwner();
      if (arguments['forceRefresh'] == true ||
          !_hasUsableAccessToken(auth.currentSession!)) {
        await _refreshSession(auth);
      }
      checkOwner();
      final session = auth.currentSession!;
      if (!_hasUsableAccessToken(session)) {
        throw PlatformException(code: 'capture_session_unavailable');
      }
      return <String, dynamic>{
        'accessToken': session.accessToken,
        'userId': session.user.id,
        'expiresAt': session.expiresAt,
      };
    });
  }

  bool _hasUsableAccessToken(Session session) =>
      session.accessToken.isNotEmpty &&
      !session.isExpired &&
      (session.expiresAt == null ||
          session.expiresAt! >
              DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30);

  Future<void> _refreshSession(GoTrueClient auth) {
    final existing = _sessionRefreshFuture;
    if (existing != null && identical(_sessionRefreshAuth, auth)) {
      return existing;
    }
    final refresh = auth.refreshSession().then<void>((_) {});
    _sessionRefreshFuture = refresh;
    _sessionRefreshAuth = auth;
    void clear() {
      if (identical(_sessionRefreshFuture, refresh)) {
        _sessionRefreshFuture = null;
        _sessionRefreshAuth = null;
      }
    }

    refresh.then<void>((_) => clear(), onError: (_) => clear());
    return refresh;
  }

  Future<void> syncAuthContext({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String? accessToken,
    String? refreshToken,
    required String? userId,
    required int? expiresAt,
  }) async {
    if (!_isIOS) return;
    await _channel.invokeMethod<void>('syncAuthContext', {
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': supabaseAnonKey,
      'accessToken': accessToken,
      'userId': userId,
      'expiresAt': expiresAt,
    });
  }

  Future<Map<String, dynamic>> syncAuthContextAndPendingWalletCaptures({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String? accessToken,
    String? refreshToken,
    required String? userId,
    required int? expiresAt,
  }) async {
    if (!_isIOS) return const <String, dynamic>{};
    final clearFuture = _clearAuthFuture;
    if (clearFuture != null) await clearFuture;

    final request = _SiriShortcutAuthSyncRequest(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      accessToken: accessToken,
      userId: userId,
      expiresAt: expiresAt,
    );

    final existingSync = _syncAuthAndCaptureFuture;
    if (existingSync != null) {
      if (_activeSyncRequest != request && _queuedSyncRequest != request) {
        _queuedSyncRequest = request;
      }
      return existingSync;
    }

    _queuedSyncRequest = request;
    final syncFuture = _drainAuthContextAndPendingWalletCaptureSyncs(
      generation: _syncGeneration,
    );
    _syncAuthAndCaptureFuture = syncFuture;
    void clearInFlightSync() {
      if (identical(_syncAuthAndCaptureFuture, syncFuture)) {
        _syncAuthAndCaptureFuture = null;
      }
    }

    syncFuture.then<void>(
      (_) => clearInFlightSync(),
      onError: (_) => clearInFlightSync(),
    );
    return syncFuture;
  }

  Future<Map<String, dynamic>> _drainAuthContextAndPendingWalletCaptureSyncs({
    required int generation,
  }) async {
    var result = const <String, dynamic>{};
    while (_queuedSyncRequest != null && generation == _syncGeneration) {
      final request = _queuedSyncRequest!;
      _queuedSyncRequest = null;
      _activeSyncRequest = request;
      try {
        result = await _syncAuthContextAndPendingWalletCaptures(
          request,
          generation: generation,
        );
      } catch (error, stackTrace) {
        if (_queuedSyncRequest == null) {
          Error.throwWithStackTrace(error, stackTrace);
        }
      } finally {
        if (_activeSyncRequest == request) {
          _activeSyncRequest = null;
        }
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> _syncAuthContextAndPendingWalletCaptures(
      _SiriShortcutAuthSyncRequest request,
      {required int generation}) async {
    await syncAuthContext(
      supabaseUrl: request.supabaseUrl,
      supabaseAnonKey: request.supabaseAnonKey,
      accessToken: request.accessToken,
      userId: request.userId,
      expiresAt: request.expiresAt,
    );
    if (generation != _syncGeneration) return const <String, dynamic>{};
    final result = await syncPendingWalletCaptures();
    if (generation == _syncGeneration &&
        (result['synced'] as num? ?? 0) > 0 &&
        request.userId != null) {
      _walletCapturesSynced.add(request.userId!);
    }
    return result;
  }

  /// Flutter remains the only refresh-token owner. Native capture can persist
  /// offline, but replay must use a current session for the same account.
  Future<Map<String, dynamic>> syncPendingWalletCapturesWithCurrentSession({
    required GoTrueClient auth,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String userId,
  }) async {
    if (!_isIOS) return const <String, dynamic>{};
    final clearFuture = _clearAuthFuture;
    if (clearFuture != null) await clearFuture;
    final generation = _syncGeneration;
    bool isCurrentUser() =>
        generation == _syncGeneration && auth.currentSession?.user.id == userId;
    if (!isCurrentUser()) return const <String, dynamic>{};

    if (auth.currentSession!.isExpired) {
      await _refreshSession(auth);
    }
    if (!isCurrentUser() || auth.currentSession!.isExpired) {
      return const <String, dynamic>{};
    }

    Future<Map<String, dynamic>> sync() {
      final session = auth.currentSession!;
      return syncAuthContextAndPendingWalletCaptures(
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
        accessToken: session.accessToken,
        userId: session.user.id,
        expiresAt: session.expiresAt,
      );
    }

    var result = await sync();
    if (result['requiresSessionRefresh'] == true && isCurrentUser()) {
      await _refreshSession(auth);
      if (!isCurrentUser() || auth.currentSession!.isExpired) return result;
      result = await sync();
    }
    return result;
  }

  Future<Map<String, dynamic>> getStatus() async {
    if (!_isIOS) {
      return const <String, dynamic>{
        'hasSupabaseConfig': false,
        'hasCredentials': false,
        'isReady': false,
      };
    }
    final result = await _channel.invokeMapMethod<String, dynamic>('getStatus');
    return result ?? const <String, dynamic>{};
  }

  Future<void> clearAuthContext() async {
    final existingClear = _clearAuthFuture;
    if (existingClear != null) return existingClear;

    final clearCompleter = Completer<void>();
    final clearFuture = clearCompleter.future;
    _clearAuthFuture = clearFuture;

    Future<void>(() async {
      try {
        await _clearAuthContext();
        clearCompleter.complete();
      } catch (error, stackTrace) {
        clearCompleter.completeError(error, stackTrace);
      } finally {
        if (identical(_clearAuthFuture, clearFuture)) {
          _clearAuthFuture = null;
        }
      }
    });

    return clearFuture;
  }

  Future<void> _clearAuthContext() async {
    _syncGeneration++;
    _queuedSyncRequest = null;
    final inFlightSync = _syncAuthAndCaptureFuture;
    if (inFlightSync != null) {
      try {
        await inFlightSync;
      } catch (_) {}
    }

    _syncAuthAndCaptureFuture = null;
    _activeSyncRequest = null;
    _queuedSyncRequest = null;
    if (!_isIOS) return;
    await _channel.invokeMethod<void>('clearAuthContext');
  }

  Future<Map<String, dynamic>> syncPendingWalletCaptures() async {
    if (!_isIOS) return const <String, dynamic>{};
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'syncPendingWalletCaptures',
    );
    return result ?? const <String, dynamic>{};
  }
}

class _SiriShortcutAuthSyncRequest {
  const _SiriShortcutAuthSyncRequest({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.accessToken,
    required this.userId,
    required this.expiresAt,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? accessToken;
  final String? userId;
  final int? expiresAt;

  @override
  bool operator ==(Object other) {
    return other is _SiriShortcutAuthSyncRequest &&
        other.supabaseUrl == supabaseUrl &&
        other.supabaseAnonKey == supabaseAnonKey &&
        other.accessToken == accessToken &&
        other.userId == userId &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(
        supabaseUrl,
        supabaseAnonKey,
        accessToken,
        userId,
        expiresAt,
      );
}
