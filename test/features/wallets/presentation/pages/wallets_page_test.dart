import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/pages/wallets_page.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthNotifier extends Auth {
  @override
  AppUser build() {
    return const AppUser(uid: 'u1', email: 'u1@example.com');
  }
}

class _FakeWalletsDataService implements WalletsDataService {
  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    return WalletsHistorySummary(
      availableMonths: [DateTime(2026, 4, 1), DateTime(2026, 3, 1)],
      netWorthSeries: [
        WalletNetWorthPoint(
            monthStart: DateTime(2026, 3, 1), netWorthCents: 1000),
        WalletNetWorthPoint(
            monthStart: DateTime(2026, 4, 1), netWorthCents: 1200),
      ],
    );
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
      WalletsMonthQuery query) async {
    return WalletsMonthSnapshot(
      monthStart: query.monthStart,
      monthEndExclusive:
          DateTime(query.monthStart.year, query.monthStart.month + 1, 1),
      incomeTotalCents: 500,
      spentTotalCents: 300,
      netWorthCents: 1200,
      walletBalances: const {'a1': 1200},
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('wallets page renders rpc-backed wallet snapshot',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    const wallets = [
      WalletEntity(
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
          authProvider.overrideWith(_FakeAuthNotifier.new),
          appPreferredTimezoneProvider.overrideWith((ref) => null),
          mainShellTabIndexProvider.overrideWith((ref) => 3),
          sharedPreferencesProvider.overrideWithValue(prefs),
          scopedWalletsProvider.overrideWith((ref) async => wallets),
          effectiveScopeWalletsProvider.overrideWith((ref) => wallets),
          walletsDataServiceProvider
              .overrideWithValue(_FakeWalletsDataService()),
          householdScopeProvider.overrideWith(
            (ref) => const HouseholdScope(
              viewMode: ViewMode.personal,
              selected: SelectedHouseholdState(),
              portfolioHouseholdIds: <String>{},
            ),
          ),
          viewModeProvider.overrideWith(
            (ref) => ViewModeNotifier()..setPersonalMode(),
          ),
        ],
        child: const MaterialApp(home: AccountsPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Spending'), findsWidgets);
    expect(find.text('Total Net Worth'), findsWidgets);
  });
}
