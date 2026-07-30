import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/subscription/data/models/plan_option.dart';
import 'package:moneko/features/subscription/presentation/widgets/paywall_shared_sections.dart';
import 'package:moneko/features/subscription/presentation/widgets/unified_plan_card.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  testWidgets(
      'Yearly and Monthly cards use concise supporting text and equal heights',
      (tester) async {
    const plan = PlanOption(
      id: 'plus_yearly',
      serverPlanId: 'plus',
      billingInterval: 'yearly',
      name: 'Yearly',
      storePrice: null,
      regionalPrice: r'$6.67',
      displayPriceUsd: 6.67,
      tagline: 'Billed monthly for 12 months.',
      isCommitment: true,
      totalCommitmentPrice: r'$80.04',
    );
    const monthlyPlan = PlanOption(
      id: 'plus_monthly',
      serverPlanId: 'plus',
      billingInterval: 'monthly',
      name: 'Monthly',
      storePrice: null,
      regionalPrice: r'$10.99',
      displayPriceUsd: 10.99,
      tagline: 'Flexible. Cancel anytime.',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: UnifiedPlanCard(
            plans: const [plan, monthlyPlan],
            selectedPlanId: plan.id,
            onPlanSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('12-month commitment'), findsNothing);

    final billedMonthlyFinder = find.text('Billed monthly');
    expect(billedMonthlyFinder, findsOneWidget);
    expect(find.text('Cancel anytime'), findsOneWidget);

    final subtitle = tester.widget<Text>(billedMonthlyFinder);
    final context = tester.element(find.byType(UnifiedPlanCard));
    expect(
      subtitle.style?.color,
      Theme.of(context).colorScheme.mutedForeground,
    );
    expect(
      find.text('Billed monthly for 12 months · \$80.04 over 12 months'),
      findsNothing,
    );
    expect(find.text('How it works'), findsNothing);

    final yearlyCard = find.ancestor(
      of: find.text('Yearly'),
      matching: find.byType(AnimatedContainer),
    );
    final monthlyCard = find.ancestor(
      of: find.text('Monthly'),
      matching: find.byType(AnimatedContainer),
    );
    expect(
        tester.getSize(yearlyCard).height, tester.getSize(monthlyCard).height);

    final infoButton = find.byTooltip(
      'Learn how Annual Plan monthly payments work',
    );
    expect(infoButton, findsOneWidget);
    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        "You'll be charged \$6.67 each month for 12 months (12 monthly payments over the full commitment). You'll enjoy all Plus features throughout your subscription.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('upfront Yearly card shows the total paid for 12 months',
      (tester) async {
    const plan = PlanOption(
      id: 'plus_yearly',
      serverPlanId: 'plus',
      billingInterval: 'yearly',
      name: 'Yearly',
      storePrice: null,
      regionalPrice: r'$6.67',
      displayPriceUsd: 6.67,
      tagline: 'Paid upfront for 12 months.',
      upfrontYearlyPrice: r'$79.99',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: UnifiedPlanCard(
            plans: const [plan],
            selectedPlanId: plan.id,
            onPlanSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Yearly'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == r'$6.67/month',
      ),
      findsOneWidget,
    );
    expect(find.text('Paid upfront: \$79.99 for 12 months'), findsOneWidget);
  });

  testWidgets('yearly renewal terms use the upfront annual total',
      (tester) async {
    const plan = PlanOption(
      id: 'plus_yearly',
      serverPlanId: 'plus',
      billingInterval: 'yearly',
      name: 'Yearly',
      storePrice: null,
      regionalPrice: r'$6.67',
      tagline: 'Paid upfront for 12 months.',
      upfrontYearlyPrice: r'$79.99',
    );
    late String terms;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            terms = paywallAutoRenewTerms(
              context,
              option: plan,
              trialMode: false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(terms, contains(r'$79.99'));
    expect(terms, isNot(contains(r'$6.67')));
  });
}
