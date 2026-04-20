import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/wallet_capture_debug_service.dart';

void main() {
  test('WalletCaptureDebugReport.fromMap parses native snapshot and entries',
      () {
    final report = WalletCaptureDebugReport.fromMap({
      'snapshot': {
        'isReady': true,
        'hasSupabaseConfig': true,
        'hasCredentials': true,
        'walletCaptureEnabled': true,
        'walletScopeId': 'household-123',
        'walletScopeName': 'Family',
        'walletIsPortfolio': false,
        'expiresAt': 1710000000,
        'isAccessTokenExpired': false,
      },
      'entries': [
        {
          'timestamp': '2026-04-15T09:10:11Z',
          'source': 'shortcut',
          'action': 'perform-start',
          'message': 'Intent started',
          'details': {'merchant': 'Tesco', 'amount': 12.4},
        },
      ],
    });

    expect(report.snapshot.isReady, isTrue);
    expect(report.snapshot.walletCaptureEnabled, isTrue);
    expect(report.snapshot.walletScopeId, 'household-123');
    expect(report.entries, hasLength(1));
    expect(report.entries.single.source, 'shortcut');
    expect(report.entries.single.action, 'perform-start');
    expect(report.entries.single.details['merchant'], 'Tesco');
  });

  test('WalletCaptureDebugReport.fromMap falls back to safe defaults', () {
    final report = WalletCaptureDebugReport.fromMap(const {});

    expect(report.snapshot.isReady, isFalse);
    expect(report.snapshot.walletScopeId, 'personal');
    expect(report.entries, isEmpty);
  });
}
