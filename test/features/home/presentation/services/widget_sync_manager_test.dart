import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/services/widget_sync_manager.dart';
import 'package:moneko/features/home/presentation/state/state.dart';

void main() {
  test('catalog publication waits for fresh data after an account change', () {
    const previous = AsyncData<List<String>>(['old wallet']);
    const current = AsyncData<List<String>>([]);
    final reloading = const AsyncLoading<List<String>>()
        .copyWithPrevious(previous, isRefresh: false);
    final refresh =
        const AsyncLoading<List<String>>().copyWithPrevious(previous);
    final denied =
        AsyncError<List<String>>(StateError('denied'), StackTrace.empty)
            .copyWithPrevious(previous);
    for (final retained in [reloading, refresh, denied]) {
      expect(retained.hasValue, isTrue);
      expect(canPublishShortcutCatalog(current, [current, retained]), isFalse);
      expect(canPublishShortcutCatalog(retained, [current]), isFalse);
    }
    expect(canPublishShortcutCatalog(current, []), isFalse);
    expect(canPublishShortcutCatalog(current, [current]), isTrue);
  });

  group('normalizeWidgetSyncCurrency', () {
    test('uses the selected home header currency in uppercase', () {
      expect(normalizeWidgetSyncCurrency(' eur '), 'EUR');
    });

    test('falls back to USD when the selected currency is blank', () {
      expect(normalizeWidgetSyncCurrency('  '), 'USD');
    });

    test('keeps selected currencies for widget aggregate conversion', () {
      expect(
        normalizeWidgetSyncSelectedCurrencies(
          selectedCurrency: 'eur',
          selectedCurrencies: const ['USD', 'EUR'],
        ),
        ['EUR', 'USD'],
      );
    });
  });

  group('WidgetSyncState.canSyncForCurrency', () {
    test('allows a currency change even inside the normal debounce window', () {
      final state = WidgetSyncState(
        appStartTime: DateTime.now(),
        lastAttemptTime: DateTime.now(),
        lastAttemptedCurrency: 'USD',
      );

      expect(
        state.canSyncForCurrency('USD', widgetSyncVersion: 0),
        isFalse,
      );
      expect(
        state.canSyncForCurrency('EUR', widgetSyncVersion: 0),
        isTrue,
      );
    });

    test('allows a mutation refresh inside the debounce window', () {
      final state = WidgetSyncState(
        appStartTime: DateTime.now(),
        lastAttemptTime: DateTime.now(),
        lastAttemptedCurrency: 'USD',
        lastAttemptedWidgetSyncVersion: 3,
      );

      expect(
        state.canSyncForCurrency('USD', widgetSyncVersion: 4),
        isTrue,
      );
    });

    test('records the mutation generation when starting a sync', () {
      final notifier = WidgetSyncStateNotifier();

      notifier.startSync(currency: 'eur', widgetSyncVersion: 4);

      expect(notifier.state.lastAttemptedCurrency, 'EUR');
      expect(notifier.state.lastAttemptedWidgetSyncVersion, 4);
    });
  });
}
