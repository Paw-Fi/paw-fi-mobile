import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/utils/intl_locale.dart';

void main() {
  group('intlSafeLocaleName', () {
    test('maps app Korean locale kr -> ko_KR', () {
      expect(intlSafeLocaleName(const Locale('kr')), 'ko_KR');
      expect(intlSafeLocaleName(const Locale('kr', 'KR')), 'ko_KR');
    });

    test('canonicalizes country casing', () {
      expect(intlSafeLocaleName(const Locale('en', 'us')), 'en_US');
    });

    test('preserves zh_TW', () {
      expect(intlSafeLocaleName(const Locale('zh', 'TW')), 'zh_TW');
    });

    test('maps legacy language codes', () {
      expect(intlSafeLocaleName(const Locale('iw')), 'he');
      expect(intlSafeLocaleName(const Locale('in')), 'id');
      expect(intlSafeLocaleName(const Locale('ji')), 'yi');
    });

    test('allows Intl to format normalized Korean locale', () async {
      final localeName = intlSafeLocaleName(const Locale('kr'));
      await initializeDateFormatting(localeName, null);
      final formatted =
          DateFormat.yMMMMd(localeName).format(DateTime(2024, 1, 1));
      expect(formatted, isNotEmpty);
    });
  });
}
