import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/services/preferred_language_sync_service.dart';

void main() {
  group('shouldSyncPreferredTimezone', () {
    test('syncs when no timezone has been cached', () {
      expect(
        shouldSyncPreferredTimezone(
          cachedTimezone: null,
          currentTimezone: 'Europe/London',
        ),
        isTrue,
      );
    });

    test('does nothing when the current timezone matches the cache', () {
      expect(
        shouldSyncPreferredTimezone(
          cachedTimezone: 'Europe/London',
          currentTimezone: 'Europe/London',
        ),
        isFalse,
      );
    });

    test('syncs when the device timezone changes', () {
      expect(
        shouldSyncPreferredTimezone(
          cachedTimezone: 'America/New_York',
          currentTimezone: 'Europe/London',
        ),
        isTrue,
      );
    });
  });
}
