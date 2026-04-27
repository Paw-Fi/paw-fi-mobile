import 'dart:io';

import 'package:flutter/services.dart';

class WalletCaptureConfig {
  const WalletCaptureConfig({
    required this.enabled,
    required this.scopeId,
    required this.scopeName,
    required this.isPortfolio,
    this.accountId,
    this.accountName,
  });

  final bool enabled;
  final String scopeId;
  final String scopeName;
  final bool isPortfolio;
  final String? accountId;
  final String? accountName;

  static String? _optionalString(Object? value) {
    final raw = value as String?;
    final trimmed = raw?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  factory WalletCaptureConfig.fromMap(Map<String, dynamic> map) {
    return WalletCaptureConfig(
      enabled: map['enabled'] as bool? ?? false,
      scopeId: (map['scopeId'] as String?) ?? 'personal',
      scopeName: (map['scopeName'] as String?) ?? 'Personal',
      isPortfolio: map['isPortfolio'] as bool? ?? false,
      accountId: _optionalString(map['accountId']),
      accountName: _optionalString(map['accountName']),
    );
  }

  WalletCaptureConfig copyWith({
    bool? enabled,
    String? scopeId,
    String? scopeName,
    bool? isPortfolio,
    String? accountId,
    String? accountName,
    bool clearAccountSelection = false,
  }) {
    return WalletCaptureConfig(
      enabled: enabled ?? this.enabled,
      scopeId: scopeId ?? this.scopeId,
      scopeName: scopeName ?? this.scopeName,
      isPortfolio: isPortfolio ?? this.isPortfolio,
      accountId: clearAccountSelection ? null : accountId ?? this.accountId,
      accountName:
          clearAccountSelection ? null : accountName ?? this.accountName,
    );
  }

  Map<String, dynamic> toMap({String? userId}) {
    return {
      'enabled': enabled,
      'scopeId': scopeId,
      'scopeName': scopeName,
      'isPortfolio': isPortfolio,
      'accountId': accountId ?? '',
      'accountName': accountName ?? '',
      if (userId != null) 'userId': userId,
    };
  }

  static const WalletCaptureConfig disabled = WalletCaptureConfig(
    enabled: false,
    scopeId: 'personal',
    scopeName: 'Personal',
    isPortfolio: false,
    accountId: null,
    accountName: null,
  );
}

class WalletCaptureService {
  WalletCaptureService._();

  static final WalletCaptureService instance = WalletCaptureService._();

  static const MethodChannel _channel =
      MethodChannel('moneko/siri_shortcut_auth');

  Future<WalletCaptureConfig> getConfig() async {
    if (!Platform.isIOS) {
      return WalletCaptureConfig.disabled;
    }
    final result = await _channel
        .invokeMapMethod<String, dynamic>('getWalletCaptureConfig');
    if (result == null) {
      return WalletCaptureConfig.disabled;
    }
    return WalletCaptureConfig.fromMap(result);
  }

  Future<void> setConfig(WalletCaptureConfig config, {String? userId}) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>(
      'setWalletCaptureConfig',
      config.toMap(userId: userId),
    );
  }

  Future<void> setEnabled(bool enabled) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>(
      'setWalletCaptureConfig',
      {'enabled': enabled},
    );
  }

  Future<void> setDestinationScope({
    required String scopeId,
    required String scopeName,
    required bool isPortfolio,
    String? accountId,
    String? accountName,
  }) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>(
      'setWalletCaptureConfig',
      {
        'scopeId': scopeId,
        'scopeName': scopeName,
        'isPortfolio': isPortfolio,
        'accountId': accountId ?? '',
        'accountName': accountName ?? '',
      },
    );
  }
}
