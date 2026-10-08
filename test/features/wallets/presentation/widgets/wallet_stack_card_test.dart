import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_stack_card.dart';

void main() {
  const debtWallet = WalletEntity(
    id: 'debt-wallet',
    userId: 'user-1',
    householdId: null,
    name: 'Loan',
    icon: 'card',
    color: '#FF6467',
    currency: 'EUR',
    openingBalanceCents: -5000000,
    goalAmountCents: 0,
    isDefault: false,
    isSystem: false,
    isArchived: false,
    currentBalanceCents: -5000000,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    WalletEntity wallet = debtWallet,
    required int balanceCents,
    bool showProgress = true,
    Widget? footer,
    bool isDark = false,
    bool disableAnimations = false,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          theme: isDark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: const TextScaler.linear(2),
              disableAnimations: disableAnimations,
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  height: 260,
                  child: WalletStackCard(
                    wallet: wallet,
                    currencyCode: 'USD',
                    displayBalanceCents: balanceCents,
                    isExpanded: true,
                    showGoalProgress: showProgress,
                    footer: footer,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  for (final scenario in [
    (balance: -5000000, repaid: '€0', progress: 0.0),
    (balance: -2500000, repaid: '€25,000', progress: 0.5),
    (balance: -1500000, repaid: '€35,000', progress: 0.7),
    (balance: -6000000, repaid: '€0', progress: 0.0),
    (balance: 0, repaid: '€50,000', progress: 1.0),
    (balance: 25000, repaid: '€50,000', progress: 1.0),
  ]) {
    testWidgets('debt progress at ${scenario.balance} cents', (tester) async {
      await pumpCard(tester, balanceCents: scenario.balance);
      await tester.pumpAndSettle();

      expect(find.text('Repaid'), findsOneWidget);
      expect(find.text('Initial debt'), findsOneWidget);
      expect(find.text(scenario.repaid), findsWidgets);
      expect(find.text('€50,000'), findsWidgets);
      expect(
        find.text(scenario.balance < 0
            ? 'Remaining debt'
            : scenario.balance == 0
                ? 'Debt paid off'
                : 'Balance'),
        findsOneWidget,
      );
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, scenario.progress);
      expect(indicator.semanticsLabel, 'Repaid');
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (balance: -5000000, progress: 0.0),
    (balance: -2500000, progress: 5 / 12),
    (balance: 0, progress: 5 / 6),
    (balance: 500000, progress: 11 / 12),
    (balance: 1000000, progress: 1.0),
    (balance: 1500000, progress: 1.0),
    (balance: -6000000, progress: 0.0),
  ]) {
    testWidgets('positive debt goal at ${scenario.balance} cents', (
      tester,
    ) async {
      await pumpCard(
        tester,
        wallet: debtWallet.copyWith(goalAmountCents: 1000000),
        balanceCents: scenario.balance,
      );
      await tester.pumpAndSettle();
      expect(find.text('Starting balance'), findsOneWidget);
      expect(find.text('Target balance'), findsOneWidget);
      expect(find.text('-€50,000'), findsWidgets);
      expect(find.text('€10,000'), findsWidgets);
      expect(find.text('Repaid'), findsNothing);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(scenario.progress, 0.000001));
      expect(indicator.semanticsLabel, 'Target balance');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('changing a debt goal recalculates the same card',
      (tester) async {
    await pumpCard(tester, balanceCents: 0);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .value,
      1,
    );
    await pumpCard(
      tester,
      wallet: debtWallet.copyWith(goalAmountCents: 1000000),
      balanceCents: 0,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .value,
      closeTo(5 / 6, 0.000001),
    );
    expect(find.text('Debt paid off'), findsOneWidget);
    expect(find.text('Target balance'), findsOneWidget);
  });

  testWidgets('animates repayment and reverses progress after a rollback', (
    tester,
  ) async {
    await pumpCard(tester, balanceCents: -5000000);
    await tester.pumpAndSettle();
    await pumpCard(tester, balanceCents: -2500000);
    await tester.pump(const Duration(milliseconds: 100));
    double progress() => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;
    expect(progress(), greaterThan(0));
    expect(progress(), lessThan(0.5));
    await tester.pumpAndSettle();
    expect(progress(), 0.5);

    await pumpCard(tester, balanceCents: -5000000);
    await tester.pumpAndSettle();
    expect(progress(), 0);
    expect(find.text('€0'), findsOneWidget);
  });

  testWidgets('debt progress uses success colors in both themes',
      (tester) async {
    for (final isDark in [false, true]) {
      await pumpCard(tester, balanceCents: -2500000, isDark: isDark);
      await tester.pumpAndSettle();
      final finder = find.byType(LinearProgressIndicator);
      final indicator = tester.widget<LinearProgressIndicator>(finder);
      final colors = Theme.of(tester.element(finder)).colorScheme;
      expect(indicator.valueColor!.value, colors.success);
      expect(find.text('-€25,000'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('repayment respects reduced motion', (tester) async {
    await pumpCard(
      tester,
      balanceCents: -5000000,
      disableAnimations: true,
    );
    await pumpCard(
      tester,
      balanceCents: 0,
      disableAnimations: true,
    );
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .value,
      1,
    );
  });

  testWidgets('ordinary wallets retain savings progress even when overdrawn', (
    tester,
  ) async {
    for (final balance in [250000, -250000]) {
      await pumpCard(
        tester,
        wallet: debtWallet.copyWith(
          openingBalanceCents: 100000,
          goalAmountCents: 1000000,
        ),
        balanceCents: balance,
      );
      await tester.pumpAndSettle();
      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('Repaid'), findsNothing);
      expect(find.text('Initial debt'), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        balance < 0 ? 0 : 0.25,
      );
    }
    await pumpCard(
      tester,
      wallet: const WalletEntity(
        id: 'ordinary-wallet',
        userId: 'user-1',
        householdId: null,
        name: 'Cash',
        icon: 'wallet',
        color: '#3B82F6',
        openingBalanceCents: 0,
        goalAmountCents: null,
        isDefault: false,
        isSystem: false,
        isArchived: false,
        currentBalanceCents: 0,
      ),
      balanceCents: 0,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .value,
      1,
    );
  });

  testWidgets('debt progress preserves hidden progress and custom footers', (
    tester,
  ) async {
    await pumpCard(tester, balanceCents: -2500000, showProgress: false);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Repaid'), findsNothing);
    await pumpCard(
      tester,
      balanceCents: -2500000,
      footer: const Text('Bank review action'),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Repaid'), findsNothing);
    expect(find.text('Bank review action'), findsOneWidget);
  });

  testWidgets('renders expanded wallet stack card metadata and action', (
    tester,
  ) async {
    const wallet = WalletEntity(
      id: 'wallet-1',
      userId: 'user-1',
      householdId: null,
      name: 'Apple Cash',
      icon: 'card',
      color: '#3B82F6',
      openingBalanceCents: 250000,
      goalAmountCents: 500000,
      isDefault: true,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 325000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 304,
              child: WalletStackCard(
                wallet: wallet,
                currencyCode: 'USD',
                displayBalanceCents: wallet.currentBalanceCents,
                isExpanded: true,
                subtitle: 'Personal Wallet',
                showBalanceChevron: false,
                headerAction: const Text('Edit'),
                metadataChips: const [
                  Text('USD'),
                  Text('Checking'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Apple Cash'), findsNWidgets(2));
    expect(find.text('Personal Wallet'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('Checking'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('marks wallets excluded from analytics', (tester) async {
    const wallet = WalletEntity(
      id: 'wallet-1',
      userId: 'user-1',
      householdId: null,
      name: 'Reserve',
      icon: 'savings',
      color: '#3B82F6',
      openingBalanceCents: 250000,
      goalAmountCents: null,
      isDefault: false,
      isSystem: false,
      isArchived: false,
      currentBalanceCents: 250000,
      excludeFromAnalytics: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 260,
            child: WalletStackCard(
              wallet: wallet,
              currencyCode: 'USD',
              displayBalanceCents: 250000,
              isExpanded: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Excluded from analytics'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_rounded), findsWidgets);
  });
}
