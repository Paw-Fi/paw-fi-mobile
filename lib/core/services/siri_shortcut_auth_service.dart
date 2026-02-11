import 'dart:io';

import 'package:flutter/services.dart';

class SiriShortcutAuthService {
  SiriShortcutAuthService._();

  static final SiriShortcutAuthService instance = SiriShortcutAuthService._();

  static const MethodChannel _channel =
      MethodChannel('moneko/siri_shortcut_auth');

  Future<void> syncAuthContext({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String? accessToken,
    required String? refreshToken,
    required String? userId,
    required int? expiresAt,
  }) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('syncAuthContext', {
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': supabaseAnonKey,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'userId': userId,
      'expiresAt': expiresAt,
    });
  }

  Future<Map<String, dynamic>> getStatus() async {
    if (!Platform.isIOS) {
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
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('clearAuthContext');
  }
}
