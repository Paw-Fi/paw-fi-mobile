import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/subscription/presentation/widgets/plus_locked_sheet.dart';

void main() {
  test('formats yearly Plus price as a monthly equivalent', () {
    expect(formatPlusYearlyMonthlyEquivalent(79.99), r'$6.67');
  });
}
