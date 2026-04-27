import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SiriShortcutAuthService {
  SiriShortcutAuthService._();

  static final SiriShortcutAuthService instance = SiriShortcutAuthService._();

  static const MethodChannel _channel =
      MethodChannel('moneko/siri_shortcut_auth');

  Future<Map<String, dynamic>>? _syncAuthAndCaptureFuture;
  Future<void>? _clearAuthFuture;
  _SiriShortcutAuthSyncRequest? _activeSyncRequest;
  _SiriShortcutAuthSyncRequest? _queuedSyncRequest;
  int _syncGeneration = 0;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> syncAuthContext({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String? accessToken,
    required String? refreshToken,
    required String? userId,
    required int? expiresAt,
  }) async {
    if (!_isIOS) return;
    await _channel.invokeMethod<void>('syncAuthContext', {
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': supabaseAnonKey,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'userId': userId,
      'expiresAt': expiresAt,
    });
  }

  Future<Map<String, dynamic>> syncAuthContextAndPendingWalletCaptures({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String? accessToken,
    required String? refreshToken,
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
      refreshToken: refreshToken,
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
      refreshToken: request.refreshToken,
      userId: request.userId,
      expiresAt: request.expiresAt,
    );
    if (generation != _syncGeneration) return const <String, dynamic>{};
    return syncPendingWalletCaptures();
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
    required this.refreshToken,
    required this.userId,
    required this.expiresAt,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final int? expiresAt;

  @override
  bool operator ==(Object other) {
    return other is _SiriShortcutAuthSyncRequest &&
        other.supabaseUrl == supabaseUrl &&
        other.supabaseAnonKey == supabaseAnonKey &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.userId == userId &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(
        supabaseUrl,
        supabaseAnonKey,
        accessToken,
        refreshToken,
        userId,
        expiresAt,
      );
}
