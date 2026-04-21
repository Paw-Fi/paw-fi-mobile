import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_stack_card.dart';

void main() {
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
}
