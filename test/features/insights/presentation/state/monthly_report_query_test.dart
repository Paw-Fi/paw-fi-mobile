import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/insights/domain/monthly_financial_report.dart';
import 'package:moneko/features/insights/presentation/pages/monthly_report_page.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';

void main() {
  test('report title shows the exact custom financial month range', () {
    final labels = monthlyReportDateRangeLabels(
      const DefaultMaterialLocalizations(),
      MonthlyReportQuery(
        monthStart: DateTime(2026, 7, 25),
        financialMonthStartDay: 25,
      ),
      now: DateTime(2026, 7, 30),
    );

    expect(labels.title, 'Jul 25 – Aug 24');
    expect(labels.year, '2026');
  });

  test('report title shows the exact selected multi-month range', () {
    final labels = monthlyReportDateRangeLabels(
      const DefaultMaterialLocalizations(),
      MonthlyReportQuery(
        monthStart: DateTime(2026, 7, 25),
        financialMonthStartDay: 25,
        range: MonthlyReportRange.sixMonths,
      ),
      now: DateTime(2026, 7, 30),
    );

    expect(labels.title, 'Feb 25 – Aug 24');
    expect(labels.year, '2026');
  });

  test('calendar-month report title still shows its exact range', () {
    final labels = monthlyReportDateRangeLabels(
      const DefaultMaterialLocalizations(),
      MonthlyReportQuery(monthStart: DateTime(2026, 7, 1)),
      now: DateTime(2026, 7, 15),
    );

    expect(labels.title, 'Jul 1 – Jul 31');
    expect(labels.year, '2026');
  });

  test('cross-year report title shows both years in its metadata', () {
    final labels = monthlyReportDateRangeLabels(
      const DefaultMaterialLocalizations(),
      MonthlyReportQuery(
        monthStart: DateTime(2025, 12, 25),
        financialMonthStartDay: 25,
      ),
      now: DateTime(2026, 1, 2),
    );

    expect(labels.title, 'Dec 25 – Jan 24');
    expect(labels.year, '2025 – 2026');
  });

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

  test('forecast preview always retains the final month-end balance', () {
    final points = <MonthlyCashFlowPoint>[
      const MonthlyCashFlowPoint(label: 'Today', balance: 1000),
      for (var index = 1; index <= 6; index++)
        MonthlyCashFlowPoint(
          label: 'Event $index',
          balance: 1000 - index * 50,
          sourceTransactionId: 'event-$index',
        ),
      const MonthlyCashFlowPoint(label: 'Month end', balance: 700),
    ];

    final visible = visibleMonthlyReportForecastPoints(points);

    expect(visible, hasLength(6));
    expect(visible.first.label, 'Today');
    expect(visible.last.label, 'Month end');
    expect(visible.last.balance, 700);
  });

  test('drilldown transaction display keeps the row native currency', () {
    final transaction = ExpenseEntry(
      id: 'usd-row',
      date: DateTime(2026, 5, 4),
      amountCents: 12345,
      currency: 'USD',
      createdAt: DateTime(2026, 5, 4),
      type: 'expense',
    );

    final display = monthlyReportNativeTransactionDisplay(
      transaction,
      fallbackCurrency: 'EUR',
    );

    expect(display.amount, 123.45);
    expect(display.currency, 'USD');
  });
}
