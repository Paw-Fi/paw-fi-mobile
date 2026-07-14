import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/insights/presentation/pages/monthly_report_page.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';

void main() {
  test('MonthlyReportQuery preserves custom financial cycle route keys', () {
    final query = monthlyReportQueryFromUri(
      Uri.parse('/insights/monthly-report?month=2026-07-25&range=month'),
      financialMonthStartDay: 25,
    );

    expect(query.monthStart, DateTime(2026, 7, 25));
    expect(query.financialMonthStartDay, 25);
    expect(query.monthKey, '2026-07-25');
  });

  test('MonthlyReportQuery normalization includes financial start day', () {
    final calendar = MonthlyReportQuery(
      monthStart: DateTime(2026, 7, 1),
    ).normalized(financialMonthStartDay: 25);
    final financial = MonthlyReportQuery(
      monthStart: DateTime(2026, 7, 25),
      financialMonthStartDay: 25,
    ).normalized(financialMonthStartDay: 25);

    expect(calendar, financial);
    expect(calendar.monthStart, DateTime(2026, 7, 25));
    expect(calendar.hashCode, financial.hashCode);
  });
}
