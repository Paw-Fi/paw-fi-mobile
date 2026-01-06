import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/utils/currency_flags.dart';

void main() {
  group('Currency Flag Path Resolution', () {
    test('returns correct paths for currencies with flags', () {
      expect(getCurrencyFlagPath('USD'), 'lib/assets/images/flags/us.png');
      expect(getCurrencyFlagPath('EUR'), 'lib/assets/images/flags/europe.png');
      expect(getCurrencyFlagPath('GBP'), 'lib/assets/images/flags/uk.png');
      expect(getCurrencyFlagPath('AED'), 'lib/assets/images/flags/uae.png'); // Fixed typo!
      expect(getCurrencyFlagPath('JPY'), 'lib/assets/images/flags/jp.png');
      expect(getCurrencyFlagPath('CNY'), 'lib/assets/images/flags/cn.png');
      expect(getCurrencyFlagPath('AUD'), 'lib/assets/images/flags/au.png');
      expect(getCurrencyFlagPath('CAD'), 'lib/assets/images/flags/ca.png');
      expect(getCurrencyFlagPath('JMD'), 'lib/assets/images/flags/jamaica.png');
      expect(getCurrencyFlagPath('MWK'), 'lib/assets/images/flags/malawi.png');
    });

    test('returns null for currencies without flags', () {
      // Test unmapped or non-existent currencies
      expect(getCurrencyFlagPath('INVALID'), null);
      expect(getCurrencyFlagPath('XXX'), null);
    });

    test('handles case insensitivity', () {
      expect(getCurrencyFlagPath('usd'), 'lib/assets/images/flags/us.png');
      expect(getCurrencyFlagPath('Eur'), 'lib/assets/images/flags/europe.png');
      expect(getCurrencyFlagPath('GbP'), 'lib/assets/images/flags/uk.png');
      expect(getCurrencyFlagPath('aed'), 'lib/assets/images/flags/uae.png');
      expect(getCurrencyFlagPath('jmd'), 'lib/assets/images/flags/jamaica.png');
      expect(getCurrencyFlagPath('mwk'), 'lib/assets/images/flags/malawi.png');
    });

    test('handles empty and special input', () {
      expect(getCurrencyFlagPath(''), null);
      expect(getCurrencyFlagPath('   '), null);
    });

    test('returns correct paths for all mapped currencies', () {
      final mappedCurrencies = {
        'USD': 'us',
        'EUR': 'europe',
        'GBP': 'uk',
        'AUD': 'au',
        'CAD': 'ca',
        'CNY': 'cn',
        'JPY': 'jp',
        'JMD': 'jamaica',
        'HKD': 'hk',
        'SGD': 'sg',
        'NZD': 'nz',
        'CZK': 'cz',
        'CHF': 'switzerland',
        'KRW': 'kr',
        'INR': 'india',
        'RUB': 'russia',
        'BRL': 'brazil',
        'MXN': 'mexico',
        'ZAR': 'south_africa',
        'SEK': 'sweden',
        'NOK': 'norway',
        'DKK': 'denmark',
        'PLN': 'poland',
        'THB': 'thailand',
        'IDR': 'indonesia',
        'MYR': 'my',
        'MWK': 'malawi',
        'PHP': 'philippines',
        'TRY': 'turkey',
        'AED': 'uae', // Corrected from 'uab'
        'SAR': 'saudi_arabia',
        'EGP': 'egypt',
        'NGN': 'nigeria',
        'PKR': 'pakistan',
        'KES': 'kenya',
        'GHS': 'ghana',
        'VND': 'vietnam',
        'DOP': 'dominican',
      };

      for (final entry in mappedCurrencies.entries) {
        expect(
          getCurrencyFlagPath(entry.key),
          'lib/assets/images/flags/${entry.value}.png',
          reason: 'Currency ${entry.key} should map to ${entry.value}.png',
        );
      }
    });
  });

  group('AED Flag Regression Test', () {
    test('AED maps to uae, not uab (bug fix verification)', () {
      final path = getCurrencyFlagPath('AED');
      expect(path, 'lib/assets/images/flags/uae.png');
      expect(path, isNot('lib/assets/images/flags/uab.png'));
    });
  });
}
