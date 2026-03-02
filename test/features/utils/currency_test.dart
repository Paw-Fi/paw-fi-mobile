import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/utils/currency.dart';

void main() {
  group('Currency Symbol Resolution', () {
    test('returns correct symbols for major currencies', () {
      expect(resolveCurrencySymbol('USD'), '\$');
      expect(resolveCurrencySymbol('EUR'), '€');
      expect(resolveCurrencySymbol('GBP'), '£');
      expect(resolveCurrencySymbol('JPY'), '¥');
      expect(resolveCurrencySymbol('AUD'), 'A\$');
      expect(resolveCurrencySymbol('CAD'), 'C\$');
      expect(resolveCurrencySymbol('AED'), 'د.إ');
      expect(resolveCurrencySymbol('INR'), '₹');
      expect(resolveCurrencySymbol('ZMW'), 'ZK');
    });

    test('handles null and empty codes', () {
      expect(resolveCurrencySymbol(null), '\$');
      expect(resolveCurrencySymbol(''), '\$');
      expect(resolveCurrencySymbol('   '), '\$');
    });

    test('handles invalid currency codes', () {
      expect(resolveCurrencySymbol('INVALID'), '\$');
      expect(resolveCurrencySymbol('XXX'), '\$');
      expect(resolveCurrencySymbol('123'), '\$');
      expect(resolveCurrencySymbol('XX'), '\$');
      expect(resolveCurrencySymbol('USDD'), '\$');
    });

    test('normalizes to uppercase', () {
      expect(resolveCurrencySymbol('usd'), '\$');
      expect(resolveCurrencySymbol('eur'), '€');
      expect(resolveCurrencySymbol('Gbp'), '£');
      expect(resolveCurrencySymbol('JpY'), '¥');
    });

    test('trims whitespace', () {
      expect(resolveCurrencySymbol(' USD '), '\$');
      expect(resolveCurrencySymbol('  EUR  '), '€');
      expect(resolveCurrencySymbol('\tGBP\n'), '£');
    });
  });

  group('Currency Code Validation', () {
    test('validates supported currencies', () {
      expect(isSupportedCurrencyCode('USD'), true);
      expect(isSupportedCurrencyCode('EUR'), true);
      expect(isSupportedCurrencyCode('GBP'), true);
      expect(isSupportedCurrencyCode('AED'), true);
      expect(isSupportedCurrencyCode('JPY'), true);
      expect(isSupportedCurrencyCode('CNY'), true);
    });

    test('rejects unsupported currencies', () {
      expect(isSupportedCurrencyCode('XXX'), false);
      expect(isSupportedCurrencyCode('INVALID'), false);
      expect(isSupportedCurrencyCode('ABC'), false);
    });

    test('rejects invalid formats', () {
      expect(isSupportedCurrencyCode(''), false);
      expect(isSupportedCurrencyCode(null), false);
      expect(isSupportedCurrencyCode('US'), false);
      expect(isSupportedCurrencyCode('USDD'), false);
      expect(isSupportedCurrencyCode('12'), false);
      expect(isSupportedCurrencyCode('US1'), false);
      expect(isSupportedCurrencyCode('1USD'), false);
    });

    test('rejects special characters (security test)', () {
      expect(isSupportedCurrencyCode("'; DROP TABLE--"), false);
      expect(isSupportedCurrencyCode('<script>'), false);
      expect(isSupportedCurrencyCode('USD; DELETE'), false);
      expect(isSupportedCurrencyCode('USD\$'), false);
      expect(isSupportedCurrencyCode('USD#'), false);
      expect(isSupportedCurrencyCode('US@'), false);
    });

    test('handles case insensitivity', () {
      expect(isSupportedCurrencyCode('usd'), true);
      expect(isSupportedCurrencyCode('USD'), true);
      expect(isSupportedCurrencyCode('Usd'), true);
      expect(isSupportedCurrencyCode('UsD'), true);
    });

    test('handles whitespace', () {
      expect(isSupportedCurrencyCode(' USD '), true);
      expect(isSupportedCurrencyCode('  EUR  '), true);
      expect(isSupportedCurrencyCode('\tGBP\n'), true);
    });
  });

  group('Available Currency Options', () {
    test('returns immutable map', () {
      final options = getAvailableCurrencyOptions();
      expect(options, isNotEmpty);
      expect(options['USD'], '\$');
      expect(options['EUR'], '€');
      expect(() => options['TEST'] = 'X', throwsUnsupportedError);
    });

    test('contains all expected currencies', () {
      final options = getAvailableCurrencyOptions();
      expect(options.containsKey('USD'), true);
      expect(options.containsKey('EUR'), true);
      expect(options.containsKey('GBP'), true);
      expect(options.containsKey('AED'), true);
      expect(options.containsKey('JPY'), true);
      expect(options.containsKey('CNY'), true);
      expect(options.containsKey('SGD'), true);
      expect(options.containsKey('INR'), true);
      expect(options.containsKey('ZMW'), true);
    });

    test('contains correct symbol mappings', () {
      final options = getAvailableCurrencyOptions();
      expect(options['USD'], '\$');
      expect(options['EUR'], '€');
      expect(options['GBP'], '£');
      expect(options['JPY'], '¥');
      expect(options['CNY'], '¥');
      expect(options['INR'], '₹');
      expect(options['AED'], 'د.إ');
      expect(options['ZMW'], 'ZK');
    });
  });

  group('Integration Tests', () {
    test('resolveCurrencySymbol uses validation internally', () {
      // Valid currencies should return correct symbol
      expect(resolveCurrencySymbol('USD'), '\$');

      // Invalid currencies should return default symbol
      expect(resolveCurrencySymbol('INVALID'), '\$');
      expect(resolveCurrencySymbol('XXX'), '\$');
      expect(resolveCurrencySymbol('123'), '\$');

      // Security: SQL injection attempts should be rejected
      expect(resolveCurrencySymbol("'; DROP TABLE expenses;--"), '\$');
    });
  });
}
