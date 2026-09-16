import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/financial_month_start_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/insights/presentation/pages/monthly_report_page.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends Auth {
  @override
  AppUser build() {
    return const AppUser(uid: 'u1', email: 'u1@example.com');
  }
}

class _TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<Subscription?> build() async => null;
}

class _PendingMonthlyReportNotifier extends MonthlyReportNotifier {
  @override
  Future<MonthlyFinancialReportSnapshot> build(MonthlyReportQuery arg) {
    return Completer<MonthlyFinancialReportSnapshot>().future;
  }
}

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

  testWidgets('loading state displays curious mascot and progress feedback',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final query = MonthlyReportQuery(
      monthStart: DateTime(2026, 7, 25),
      financialMonthStartDay: 25,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_FakeAuthNotifier.new),
        householdScopeProvider.overrideWith(
          (ref) => const HouseholdScope(
            viewMode: ViewMode.personal,
            selected: SelectedHouseholdState(),
            portfolioHouseholdIds: <String>{},
          ),
        ),
        subscriptionNotifierProvider
            .overrideWith(_TestSubscriptionNotifier.new),
        financialMonthStartDayProvider.overrideWithValue(25),
        monthlyFinancialReportProvider
            .overrideWith(_PendingMonthlyReportNotifier.new),
      ],
      child: buildTestApp(
        MonthlyReportPage(initialQuery: query),
      ),
    ));

    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    final imageWidget = tester.widget<Image>(find.byType(Image));
    expect(
      (imageWidget.image as AssetImage).assetName,
      'lib/assets/gifs/moneko-curious.gif',
    );
    expect(find.text('Building monthly report'), findsOneWidget);
    expect(
      find.text('Checking budgets, trends, and upcoming commitments.'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
