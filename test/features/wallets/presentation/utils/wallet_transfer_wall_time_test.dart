import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_transfer_wall_time.dart';

void main() {
  test('IANA default uses configured zone instead of device timezone', () {
    final wall = walletTransferWallNow(
      preferredTimezone: 'Asia/Tokyo',
      at: DateTime.utc(2026, 10, 1, 23, 30),
    );
    expect([wall.year, wall.month, wall.day, wall.hour, wall.minute],
        [2026, 10, 2, 8, 30]);
  });

  test('IANA defaults respect summer and winter offsets', () {
    for (final month in [1, 7]) {
      final wall = walletTransferWallNow(
        preferredTimezone: 'America/New_York',
        at: DateTime.utc(2026, month, 1, 12),
      );
      expect(wall.hour, month == 1 ? 7 : 8);
    }
  });

  test('fixed offsets support fractional-hour zones', () {
    final wall = walletTransferWallNow(
      preferredTimezone: 'UTC+05:45',
      at: DateTime.utc(2026, 10, 1, 23),
    );
    expect([wall.day, wall.hour, wall.minute], [2, 4, 45]);
  });

  test('missing or invalid configured timezone uses device timezone', () {
    final instant = DateTime.utc(2026, 10, 1, 12);
    for (final zone in [null, '', 'Invalid/Zone']) {
      expect(walletTransferWallNow(preferredTimezone: zone, at: instant),
          instant.toLocal());
    }
  });
}
