import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/services/widget_sync_manager.dart';
import 'package:moneko/features/home/presentation/state/state.dart';

void main() {
  group('normalizeWidgetSyncCurrency', () {
    test('uses the selected home header currency in uppercase', () {
      expect(normalizeWidgetSyncCurrency(' eur '), 'EUR');
    });

    test('falls back to USD when the selected currency is blank', () {
      expect(normalizeWidgetSyncCurrency('  '), 'USD');
    });
  });

  group('WidgetSyncState.canSyncForCurrency', () {
    test('allows a currency change even inside the normal debounce window', () {
      final state = WidgetSyncState(
        appStartTime: DateTime.now(),
        lastAttemptTime: DateTime.now(),
        lastAttemptedCurrency: 'USD',
      );

      expect(state.canSyncForCurrency('USD'), isFalse);
      expect(state.canSyncForCurrency('EUR'), isTrue);
    });
  });
}
