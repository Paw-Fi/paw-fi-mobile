import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/utils/money_parser.dart';

void main() {
  group('tryParseMoneyToCents', () {
    test('parses integers', () {
      expect(tryParseMoneyToCents('0'), 0);
      expect(tryParseMoneyToCents('12'), 1200);
      expect(tryParseMoneyToCents('1,234'), 123400);
    });

    test('parses dot decimals', () {
      expect(tryParseMoneyToCents('12.3'), 1230);
      expect(tryParseMoneyToCents('12.30'), 1230);
      expect(tryParseMoneyToCents('1,234.56'), 123456);
    });

    test('parses comma decimals', () {
      expect(tryParseMoneyToCents('12,3'), 1230);
      expect(tryParseMoneyToCents('12,30'), 1230);
      expect(tryParseMoneyToCents('1234,56'), 123456);
    });

    test('rounds > 2 decimal digits', () {
      expect(tryParseMoneyToCents('12.344'), 1234);
      expect(tryParseMoneyToCents('12.345'), 1235);
      expect(tryParseMoneyToCents('12.349'), 1235);
    });

    test('ignores currency symbols', () {
      expect(tryParseMoneyToCents(r'$1,234.50'), 123450);
      expect(tryParseMoneyToCents('EUR 99,99'), 9999);
    });
  });
}
