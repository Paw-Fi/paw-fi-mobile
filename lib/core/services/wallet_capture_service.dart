import 'dart:io';

import 'package:flutter/services.dart';

class WalletCaptureConfig {
  const WalletCaptureConfig({
    required this.enabled,
    required this.scopeId,
    required this.scopeName,
    required this.isPortfolio,
  });

  final bool enabled;
  final String scopeId;
  final String scopeName;
  final bool isPortfolio;

  factory WalletCaptureConfig.fromMap(Map<String, dynamic> map) {
    return WalletCaptureConfig(
      enabled: map['enabled'] as bool? ?? false,
      scopeId: (map['scopeId'] as String?) ?? 'personal',
      scopeName: (map['scopeName'] as String?) ?? 'Personal',
      isPortfolio: map['isPortfolio'] as bool? ?? false,
    );
  }

  WalletCaptureConfig copyWith({
    bool? enabled,
    String? scopeId,
    String? scopeName,
    bool? isPortfolio,
  }) {
    return WalletCaptureConfig(
      enabled: enabled ?? this.enabled,
      scopeId: scopeId ?? this.scopeId,
      scopeName: scopeName ?? this.scopeName,
      isPortfolio: isPortfolio ?? this.isPortfolio,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'scopeId': scopeId,
      'scopeName': scopeName,
      'isPortfolio': isPortfolio,
    };
  }

  static const WalletCaptureConfig disabled = WalletCaptureConfig(
    enabled: false,
    scopeId: 'personal',
    scopeName: 'Personal',
    isPortfolio: false,
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

  Future<void> setConfig(WalletCaptureConfig config) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>(
      'setWalletCaptureConfig',
      config.toMap(),
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
  }) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>(
      'setWalletCaptureConfig',
      {
        'scopeId': scopeId,
        'scopeName': scopeName,
        'isPortfolio': isPortfolio,
      },
    );
  }
}
