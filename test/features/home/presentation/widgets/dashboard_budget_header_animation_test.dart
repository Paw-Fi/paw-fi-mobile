import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/widgets/dashboard_budget_header.dart';
import 'package:moneko/l10n/app_localizations.dart';

final _gauge = find.byKey(const ValueKey('budget-companion-progress'));
final _percent = find.byKey(const ValueKey('budget-companion-percent'));
final _bubble = find.byKey(const ValueKey('budget-companion-bubble'));
final _mascot = find.byType(Image);

double _gaugeValue(WidgetTester tester) =>
    tester.widget<BudgetGaugeIndicator>(_gauge).value;

String _percentText(WidgetTester tester) =>
    tester.widget<Text>(_percent).data!;

Future<void> _pump(
  WidgetTester tester, {
  required double spent,
  double? budget = 100,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 1000),
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: DashboardBudgetHeader(
            summary:
                AsyncData(BudgetCompanionSummary(spent: spent, budget: budget)),
            currency: 'USD',
            mode: HomePeriodMode.monthly,
            onBudgetTap: () {},
            onRetry: () {},
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('intro holds 0%, counts up in sync, then reveals mascot and bubble',
      (tester) async {
    await _pump(tester, spent: 61);
    await tester.pump();

    // Phase 1: hold at 0% with nothing else on stage.
    expect(_gaugeValue(tester), 0);
    expect(_percentText(tester), '0%');
    expect(_mascot, findsNothing);
    expect(_bubble, findsNothing);
    await tester.pump(const Duration(milliseconds: 480));
    expect(_gaugeValue(tester), 0);
    expect(_percentText(tester), '0%');
    expect(_mascot, findsNothing);

    // Phase 2: gauge and text count up together, mascot still hidden.
    await tester.pump(const Duration(milliseconds: 620));
    final midway = _gaugeValue(tester);
    expect(midway, greaterThan(0));
    expect(midway, lessThan(.61));
    expect(_percentText(tester), '${(midway * 100).round()}%');
    expect(_mascot, findsNothing);
    expect(_bubble, findsNothing);

    // Phase 3: mascot pops in while the gauge is still filling.
    await tester.pump(const Duration(milliseconds: 400));
    expect(_mascot, findsOneWidget);
    expect(_bubble, findsNothing);
    expect(_gaugeValue(tester), greaterThan(midway));
    expect(_gaugeValue(tester), lessThan(.61));

    // Phase 4: bubble follows once the mascot has mostly landed.
    await tester.pump(const Duration(milliseconds: 350));
    expect(_mascot, findsOneWidget);
    expect(_bubble, findsOneWidget);
    expect(_gaugeValue(tester), closeTo(.61, 1e-9));
    expect(_percentText(tester), '61%');

    await tester.pumpAndSettle();
    expect(_gaugeValue(tester), closeTo(.61, 1e-9));
    expect(_percentText(tester), '61%');
    expect(tester.takeException(), isNull);
  });

  testWidgets('over-budget text counts past 100% while the arc clamps',
      (tester) async {
    await _pump(tester, spent: 108);
    await tester.pumpAndSettle();
    expect(_gaugeValue(tester), 1);
    expect(_percentText(tester), '108%');
  });

  testWidgets('later summary changes settle from the displayed value',
      (tester) async {
    await _pump(tester, spent: 40);
    await tester.pumpAndSettle();
    expect(_gaugeValue(tester), closeTo(.4, 1e-9));

    await _pump(tester, spent: 80);
    await tester.pump();
    expect(_gaugeValue(tester), closeTo(.4, 1e-9));
    await tester.pump(const Duration(milliseconds: 350));
    final midway = _gaugeValue(tester);
    expect(midway, greaterThan(.4));
    expect(midway, lessThan(.8));
    expect(_percentText(tester), '${(midway * 100).round()}%');
    expect(_mascot, findsOneWidget);
    expect(_bubble, findsOneWidget);
    await tester.pumpAndSettle();
    expect(_gaugeValue(tester), closeTo(.8, 1e-9));
    expect(_percentText(tester), '80%');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a change during the intro continues from the shown value',
      (tester) async {
    await _pump(tester, spent: 60);
    await tester.pump(const Duration(milliseconds: 1000));
    final shown = _gaugeValue(tester);
    expect(shown, greaterThan(0));

    await _pump(tester, spent: 90);
    await tester.pump();
    expect(_gaugeValue(tester), closeTo(shown, 1e-9));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_gaugeValue(tester), closeTo(shown, .05));
    await tester.pumpAndSettle();
    expect(_gaugeValue(tester), closeTo(.9, 1e-9));
    expect(_percentText(tester), '90%');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shows the final state immediately',
      (tester) async {
    await _pump(tester, spent: 61, disableAnimations: true);
    await tester.pump();
    expect(_gaugeValue(tester), closeTo(.61, 1e-9));
    expect(_percentText(tester), '61%');
    expect(_mascot, findsOneWidget);
    expect(_bubble, findsOneWidget);
  });

  testWidgets('disposing mid-intro does not throw', (tester) async {
    await _pump(tester, spent: 61);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
