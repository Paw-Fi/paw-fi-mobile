import 'dart:io';

import 'package:flutter/services.dart';

class WalletCaptureDebugEntry {
  const WalletCaptureDebugEntry({
    required this.timestamp,
    required this.source,
    required this.action,
    required this.message,
    required this.details,
  });

  final String timestamp;
  final String source;
  final String action;
  final String message;
  final Map<String, dynamic> details;

  factory WalletCaptureDebugEntry.fromMap(Map<String, dynamic> map) {
    return WalletCaptureDebugEntry(
      timestamp: (map['timestamp'] as String?) ?? '',
      source: (map['source'] as String?) ?? 'native',
      action: (map['action'] as String?) ?? 'unknown',
      message: (map['message'] as String?) ?? '',
      details: Map<String, dynamic>.from(
        (map['details'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }
}

class WalletCaptureDebugSnapshot {
  const WalletCaptureDebugSnapshot({
    required this.hasSupabaseConfig,
    required this.hasCredentials,
    required this.isReady,
    required this.walletCaptureEnabled,
    required this.walletScopeId,
    required this.walletScopeName,
    required this.walletIsPortfolio,
    required this.expiresAt,
    required this.isAccessTokenExpired,
  });

  final bool hasSupabaseConfig;
  final bool hasCredentials;
  final bool isReady;
  final bool walletCaptureEnabled;
  final String walletScopeId;
  final String walletScopeName;
  final bool walletIsPortfolio;
  final int expiresAt;
  final bool isAccessTokenExpired;

  factory WalletCaptureDebugSnapshot.fromMap(Map<String, dynamic> map) {
    return WalletCaptureDebugSnapshot(
      hasSupabaseConfig: map['hasSupabaseConfig'] == true,
      hasCredentials: map['hasCredentials'] == true,
      isReady: map['isReady'] == true,
      walletCaptureEnabled: map['walletCaptureEnabled'] == true,
      walletScopeId: (map['walletScopeId'] as String?) ?? 'personal',
      walletScopeName: (map['walletScopeName'] as String?) ?? 'Personal',
      walletIsPortfolio: map['walletIsPortfolio'] == true,
      expiresAt: (map['expiresAt'] as num?)?.toInt() ?? 0,
      isAccessTokenExpired: map['isAccessTokenExpired'] == true,
    );
  }
}

class WalletCaptureDebugReport {
  const WalletCaptureDebugReport({
    required this.snapshot,
    required this.entries,
  });

  final WalletCaptureDebugSnapshot snapshot;
  final List<WalletCaptureDebugEntry> entries;

  factory WalletCaptureDebugReport.fromMap(Map<String, dynamic> map) {
    final snapshotMap = Map<String, dynamic>.from(
      (map['snapshot'] as Map?) ?? const <String, dynamic>{},
    );
    final entryList = (map['entries'] as List?) ?? const <dynamic>[];

    return WalletCaptureDebugReport(
      snapshot: WalletCaptureDebugSnapshot.fromMap(snapshotMap),
      entries: entryList
          .whereType<Map>()
          .map((entry) => WalletCaptureDebugEntry.fromMap(
                Map<String, dynamic>.from(entry),
              ))
          .toList(growable: false),
    );
  }
}

class WalletCaptureDebugService {
  WalletCaptureDebugService._();

  static final WalletCaptureDebugService instance =
      WalletCaptureDebugService._();

  static const MethodChannel _channel =
      MethodChannel('moneko/siri_shortcut_auth');

  static const WalletCaptureDebugReport _emptyReport = WalletCaptureDebugReport(
    snapshot: WalletCaptureDebugSnapshot(
      hasSupabaseConfig: false,
      hasCredentials: false,
      isReady: false,
      walletCaptureEnabled: false,
      walletScopeId: 'personal',
      walletScopeName: 'Personal',
      walletIsPortfolio: false,
      expiresAt: 0,
      isAccessTokenExpired: false,
    ),
    entries: <WalletCaptureDebugEntry>[],
  );

  Future<WalletCaptureDebugReport> getReport() async {
    if (!Platform.isIOS) {
      return _emptyReport;
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getWalletCaptureDebugReport',
      );

      return WalletCaptureDebugReport.fromMap(
        result ?? const <String, dynamic>{},
      );
    } on MissingPluginException {
      return _emptyReport;
    } on PlatformException {
      return _emptyReport;
    }
  }

  Future<void> clearReport() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('clearWalletCaptureDebugReport');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> appendEntry({
    required String source,
    required String action,
    required String message,
    Map<String, dynamic> details = const <String, dynamic>{},
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('appendWalletCaptureDebugEntry', {
        'source': source,
        'action': action,
        'message': message,
        'details': details,
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
