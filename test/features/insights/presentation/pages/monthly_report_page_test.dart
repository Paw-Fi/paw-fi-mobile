import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/insights/presentation/pages/monthly_report_page.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('period navigator exposes exact range and navigation bounds',
      (tester) async {
    final currentQuery = MonthlyReportQuery(
      monthStart: DateTime(2026, 7, 25),
      financialMonthStartDay: 25,
    );
    var previousTaps = 0;
    var nextTaps = 0;
    var pickerTaps = 0;

    await tester.pumpWidget(buildTestApp(
      MonthlyReportPeriodNavigator(
        query: currentQuery,
        currentQuery: currentQuery,
        now: DateTime(2026, 7, 30),
        onPrevious: () => previousTaps += 1,
        onNext: () => nextTaps += 1,
        onSelectPeriod: () => pickerTaps += 1,
      ),
    ));

    expect(find.text('Jul 25 – Aug 24'), findsOneWidget);
    expect(find.text('Current period'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous period'));
    await tester.tap(find.text('Jul 25 – Aug 24'));
    await tester.tap(find.byTooltip('Next period'));

    expect(previousTaps, 1);
    expect(pickerTaps, 1);
    expect(nextTaps, 0);

    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('archive lists current plus twelve previous report periods',
      (tester) async {
    final currentQuery = MonthlyReportQuery(
      monthStart: DateTime(2026, 7, 25),
      financialMonthStartDay: 25,
    );
    MonthlyReportQuery? selected;

    await tester.pumpWidget(buildTestApp(
      SizedBox(
        height: 700,
        child: MonthlyReportArchiveSheet(
          queries: monthlyReportArchiveQueries(currentQuery: currentQuery),
          selectedQuery: shiftMonthlyReportQuery(currentQuery, -1),
          currentQuery: currentQuery,
          now: DateTime(2026, 7, 30),
          onSelected: (query) => selected = query,
        ),
      ),
    ));

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Jul 25 – Aug 24'), findsOneWidget);
    expect(find.text('Jun 25 – Jul 24'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text('Jun 25 – Jul 24'));

    expect(selected?.monthStart, DateTime(2026, 6, 25));
  });
}
