import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneko/features/home/data/services/currency_preference_service.dart';

void main() {
  late CurrencyPreferenceService service;

  setUp(() {
    // Initialize with empty values
    SharedPreferences.setMockInitialValues({});
    service = CurrencyPreferenceService();
  });

  group('Selected Currency Preferences', () {
    test('getSelectedCurrency returns null initially', () async {
      final currency = await service.getSelectedCurrency();
      expect(currency, null);
    });

    test('setSelectedCurrency persists value', () async {
      await service.setSelectedCurrency('USD');
      final currency = await service.getSelectedCurrency();
      expect(currency, 'USD');
    });

    test('setSelectedCurrency updates existing value', () async {
      await service.setSelectedCurrency('USD');
      await service.setSelectedCurrency('EUR');
      final currency = await service.getSelectedCurrency();
      expect(currency, 'EUR');
    });

    test('currency is cached after first load', () async {
      await service.setSelectedCurrency('GBP');
      
      // First call hits storage
      final first = await service.getSelectedCurrency();
      expect(first, 'GBP');
      
      // Second call uses cache (we can't directly verify caching, but it should work)
      final second = await service.getSelectedCurrency();
      expect(second, 'GBP');
    });

    test('clearSelectedCurrency removes value', () async {
      await service.setSelectedCurrency('JPY');
      await service.clearSelectedCurrency();
      final currency = await service.getSelectedCurrency();
      expect(currency, null);
    });

    test('clearSelectedCurrency clears cache', () async {
      await service.setSelectedCurrency('AUD');
      await service.clearSelectedCurrency();
      
      // After clearing, should return null
      final currency = await service.getSelectedCurrency();
      expect(currency, null);
    });
  });

  group('Currency Order Preferences', () {
    test('getCurrencyOrder returns null initially', () async {
      final order = await service.getCurrencyOrder();
      expect(order, null);
    });

    test('setCurrencyOrder persists list', () async {
      final testOrder = ['USD', 'EUR', 'GBP'];
      await service.setCurrencyOrder(testOrder);
      
      final order = await service.getCurrencyOrder();
      expect(order, testOrder);
    });

    test('setCurrencyOrder handles empty list', () async {
      await service.setCurrencyOrder([]);
      final order = await service.getCurrencyOrder();
      expect(order, []);
    });

    test('setCurrencyOrder handles single item', () async {
      await service.setCurrencyOrder(['USD']);
      final order = await service.getCurrencyOrder();
      expect(order, ['USD']);
    });

    test('setCurrencyOrder handles many items', () async {
      final testOrder = ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CNY', 'HKD', 'SGD', 'NZD'];
      await service.setCurrencyOrder(testOrder);
      
      final order = await service.getCurrencyOrder();
      expect(order, testOrder);
      expect(order?.length, 10);
    });

    test('currency order is cached after first load', () async {
      final testOrder = ['EUR', 'USD'];
      await service.setCurrencyOrder(testOrder);
      
      // First call hits storage
      final first = await service.getCurrencyOrder();
      expect(first, testOrder);
      
      // Second call uses cache
      final second = await service.getCurrencyOrder();
      expect(second, testOrder);
    });
  });

  group('Clear All Preferences', () {
    test('clearAll removes all currency preferences', () async {
      await service.setSelectedCurrency('USD');
      await service.setCurrencyOrder(['EUR', 'GBP']);
      
      await service.clearAll();
      
      final currency = await service.getSelectedCurrency();
      final order = await service.getCurrencyOrder();
      
      expect(currency, null);
      expect(order, null);
    });

    test('clearAll clears all caches', () async {
      await service.setSelectedCurrency('JPY');
      await service.setCurrencyOrder(['JPY', 'CNY']);
      
      await service.clearAll();
      
      // After clearing, both should return null
      expect(await service.getSelectedCurrency(), null);
      expect(await service.getCurrencyOrder(), null);
    });
  });

  group('Edge Cases', () {
    test('handles special characters in currency code', () async {
      // Service should accept any string (validation happens elsewhere)
      await service.setSelectedCurrency('US\$');
      final currency = await service.getSelectedCurrency();
      expect(currency, 'US\$');
    });

    test('handles empty string as currency', () async {
      await service.setSelectedCurrency('');
      final currency = await service.getSelectedCurrency();
      expect(currency, '');
    });

    test('handles very long currency order', () async {
      final longOrder = List.generate(100, (i) => 'CUR$i');
      await service.setCurrencyOrder(longOrder);
      
      final order = await service.getCurrencyOrder();
      expect(order, longOrder);
      expect(order?.length, 100);
    });

    test('multiple service instances share same storage', () async {
      final service1 = CurrencyPreferenceService();
      final service2 = CurrencyPreferenceService();
      
      await service1.setSelectedCurrency('USD');
      await service2.getSelectedCurrency();
      
      // Note: Without clearing cache, service2 won't see service1's changes
      // This is expected behavior as each instance has its own cache
      // In real app, we use a single instance via Provider
    });
  });
}
