import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';

void main() {
  test('income list requests only actual income rows', () {
    final request = buildIncomeListRequest(
      userId: 'user-1',
      limit: 50,
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 31),
      currency: 'EUR',
    );

    expect(request['excludeRecurring'], isTrue);
    expect(request['startDate'], '2026-07-01');
    expect(request['endDate'], '2026-07-31');
  });
}
