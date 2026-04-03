import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/pages/wallets_page.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAnalyticsNotifier extends AnalyticsNotifier {
  _FakeAnalyticsNotifier(Ref ref) : super(ref) {
    state = AnalyticsData();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // AccountsPage watches authProvider which reads Supabase.instance.
    // Tests only need the singleton initialized (no real network).
    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('wallets page renders provided wallet', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    const accounts = [
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
          sharedPreferencesProvider.overrideWithValue(prefs),
          scopedWalletsProvider.overrideWith((ref) async => accounts),
          analyticsProvider.overrideWith((ref) => _FakeAnalyticsNotifier(ref)),
          householdScopeProvider.overrideWith(
            (ref) => const HouseholdScope(
              viewMode: ViewMode.personal,
              selected: SelectedHouseholdState(),
              portfolioHouseholdIds: <String>{},
            ),
          ),
          // Make test deterministic and avoid async SharedPreferences reads.
          viewModeProvider.overrideWith(
            (ref) => ViewModeNotifier()..setPersonalMode(),
          ),
        ],
        child: const MaterialApp(home: AccountsPage()),
      ),
    );

    await tester.pumpAndSettle();
    // Account name appears in multiple card states.
    expect(find.text('Spending'), findsWidgets);
    expect(find.text('Total Net Worth'), findsOneWidget);
  });
}
