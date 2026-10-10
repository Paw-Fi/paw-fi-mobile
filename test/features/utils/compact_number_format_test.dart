import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/utils/intl_locale.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  test('English chart labels compact values without unnecessary zeroes', () {
    expect(formatCompactNumber(0), '0');
    expect(formatCompactNumber(-0.0), '0');
    expect(formatCompactNumber(12.34), '12.34');
    expect(formatCompactNumber(1000), '1K');
    expect(formatCompactNumber(10000), '10K');
    expect(formatCompactNumber(12345.67), '12.3K');
    expect(formatCompactNumber(1000000), '1M');
    expect(formatCompactNumber(1000000000), '1B');
    expect(formatCompactNumber(1000000000000), '1T');
    expect(formatCompactNumber(-12345.67), '-12.3K');
  });

  test('rounding carries across compact unit boundaries', () {
    expect(formatCompactNumber(999949), '999.9K');
    expect(formatCompactNumber(999950), '1M');
    expect(formatCompactNumber(-999950), '-1M');
  });

  test('East Asian locales use native ten-thousand units', () {
    expect(formatCompactNumber(10000, locale: const Locale('zh')), '1万');
    expect(formatCompactNumber(10000, locale: const Locale('zh', 'TW')), '1萬');
    expect(formatCompactNumber(10000, locale: const Locale('ja')), '1万');
    expect(formatCompactNumber(10000, locale: const Locale('ko')), '1만');
    expect(formatCompactNumber(100000000, locale: const Locale('zh')), '1亿');
  });

  test('German chart thousands abbreviate with localized decimal punctuation',
      () {
    const locale = Locale('de');
    expect(formatCompactNumber(10000, locale: locale), '10\u00a0Tsd.');
    expect(formatCompactNumber(12345.67, locale: locale), '12,3\u00a0Tsd.');
    expect(formatCompactNumber(-12345.67, locale: locale), '-12,3\u00a0Tsd.');
    expect(formatCompactNumber(999950, locale: locale),
        formatCompactNumber(1000000, locale: locale));
  });

  test('locale aliases and unsupported locales resolve safely', () {
    expect(formatCompactNumber(10000, locale: const Locale('kr')),
        formatCompactNumber(10000, locale: const Locale('ko', 'KR')));
    expect(
        formatCompactNumber(10000, locale: const Locale('yue', 'HK')), '10K');
  });

  for (final locale in AppLocalizations.supportedLocales) {
    test('large chart values are shorter in $locale', () {
      const value = 1234567890.12;
      final compact = formatCompactNumber(value, locale: locale);
      final full =
          NumberFormat.decimalPattern(intlSafeLocaleName(locale)).format(value);
      expect(compact, isNotEmpty);
      expect(compact.length, lessThan(full.length));
    });
  }

  test('compact currency retains the supplied currency identity', () {
    expect(formatCompactCurrency(10000, 'USD'), r'$10K');
    expect(formatCompactCurrency(10000, 'EUR'), '€10K');
    expect(formatCompactCurrency(10000, 'JPY'), '¥10K');
    expect(formatCompactCurrency(10000, 'IDR'),
        '${resolveCurrencySymbol('IDR')}10K');
    expect(formatCurrency(12345.67, 'USD'), r'$12,345.67');
  });
}
