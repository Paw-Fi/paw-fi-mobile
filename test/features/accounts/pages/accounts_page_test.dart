import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/accounts/presentation/pages/accounts_page.dart';
import 'package:moneko/features/accounts/presentation/providers/account_providers.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';

class _FakeAnalyticsNotifier extends AnalyticsNotifier {
  _FakeAnalyticsNotifier(Ref ref) : super(ref) {
    state = AnalyticsData();
  }
}

void main() {
  testWidgets('accounts page renders provided account', (tester) async {
    const accounts = [
      AccountEntity(
        id: 'a1',
        userId: 'u1',
        householdId: null,
        name: 'Spending',
        icon: 'wallet',
        color: '#6B7280',
        openingBalanceCents: 0,
        goalAmountCents: null,
        isDefault: true,
        isSystem: true,
        isArchived: false,
        currentBalanceCents: 1200,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scopedAccountsProvider.overrideWith((ref) async => accounts),
          analyticsProvider.overrideWith((ref) => _FakeAnalyticsNotifier(ref)),
          householdScopeProvider.overrideWith(
            (ref) => const HouseholdScope(
              viewMode: ViewMode.personal,
              selected: SelectedHouseholdState(),
              portfolioHouseholdIds: <String>{},
            ),
          ),
        ],
        child: const MaterialApp(home: AccountsPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Spending'), findsOneWidget);
    expect(find.text('Account Overview'), findsOneWidget);
  });
}
