import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/pockets/presentation/widgets/pockets_header_card.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';

void main() {
  Widget buildHeader({
    required ThemeData theme,
    required ValueChanged<double>? onTotalChanged,
    VoidCallback? onBudgetEditBlocked,
    Map<String, double> currencyBudgets = const {},
    Future<void> Function(String currency, double amount)?
        onCurrencyBudgetChanged,
    bool showSlider = false,
  }) {
    return MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: PocketsHeaderCard(
            totalBudget: 4000000,
            periodMonth: DateTime(2026, 7),
            colorScheme: theme.colorScheme,
            onTotalChanged: onTotalChanged,
            onBudgetEditBlocked: onBudgetEditBlocked,
            currencyBudgets: currencyBudgets,
            onCurrencyBudgetChanged: onCurrencyBudgetChanged,
            currency: 'CLP',
            showSlider: showSlider,
          ),
        ),
      ),
    );
  }

  testWidgets('read-only budget explains restriction without opening editor',
      (tester) async {
    var blockedCount = 0;
    final theme = ThemeData.light(useMaterial3: true);

    await tester.pumpWidget(
      buildHeader(
        theme: theme,
        onTotalChanged: null,
        onBudgetEditBlocked: () => blockedCount += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveSlider), findsNothing);

    await tester.tap(find.byType(PocketsHeaderCard));
    await tester.pumpAndSettle();

    expect(blockedCount, 1);
    expect(find.byType(CalculatorKeypad), findsNothing);
  });

  testWidgets('editable budget still opens the calculator', (tester) async {
    final theme = ThemeData.light(useMaterial3: true);

    await tester.pumpWidget(
      buildHeader(
        theme: theme,
        onTotalChanged: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveSlider), findsNothing);

    await tester.tap(find.byType(PocketsHeaderCard));
    await tester.pumpAndSettle();

    expect(find.byType(CalculatorKeypad), findsOneWidget);
  });

  testWidgets('explicit onboarding mode retains the slider', (tester) async {
    final theme = ThemeData.light(useMaterial3: true);

    await tester.pumpWidget(
      buildHeader(
        theme: theme,
        onTotalChanged: (_) {},
        showSlider: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveSlider), findsOneWidget);
  });

  testWidgets('multi-currency budgets render and edit in native currency',
      (tester) async {
    final theme = ThemeData.light(useMaterial3: true);
    String? editedCurrency;
    double? editedAmount;

    await tester.pumpWidget(
      buildHeader(
        theme: theme,
        onTotalChanged: null,
        currencyBudgets: const {
          'EUR': 1000,
          'USD': 200,
        },
        onCurrencyBudgetChanged: (currency, amount) async {
          editedCurrency = currency;
          editedAmount = amount;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('currency_budget_EUR')), findsOneWidget);
    expect(find.byKey(const ValueKey('currency_budget_USD')), findsOneWidget);
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('currency_budget_USD')));
    await tester.pumpAndSettle();

    final keypad =
        tester.widget<CalculatorKeypad>(find.byType(CalculatorKeypad));
    expect(keypad.prefix, r'$');
    keypad.onConfirm('275');
    await tester.pumpAndSettle();

    expect(editedCurrency, 'USD');
    expect(editedAmount, 275);
  });
}
