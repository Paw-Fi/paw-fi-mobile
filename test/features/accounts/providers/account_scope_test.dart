import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _EmptyAuthNotifier extends Auth {
  @override
  AppUser build() => AppUser.empty;
}

class _StaticScopedWalletsNotifier extends ScopedWalletsNotifier {
  _StaticScopedWalletsNotifier(this.wallets);

  final List<WalletEntity> wallets;

  @override
  Future<List<WalletEntity>> build() async => wallets;

  @override
  Future<List<WalletEntity>> refreshFromNetwork() async => wallets;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    try {
      await Supabase.initialize(
        url: 'http://localhost',
        anonKey: 'test-anon-key',
      );
    } catch (_) {
      // Other tests may have already initialized the singleton.
    }
  });

  test('defaultScopedAccountProvider resolves default wallet', () async {
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
        isDefault: false,
        isSystem: true,
        isArchived: false,
        currentBalanceCents: 0,
      ),
      WalletEntity(
        id: 'a2',
        userId: 'u1',
        householdId: null,
        name: 'Travel',
        icon: 'plane',
        color: '#3B82F6',
        openingBalanceCents: 0,
        goalAmountCents: null,
        isDefault: true,
        isSystem: false,
        isArchived: false,
        currentBalanceCents: 0,
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        scopedWalletsProvider
            .overrideWith(() => _StaticScopedWalletsNotifier(wallets)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(scopedWalletsProvider.future);
    final resolved = container.read(defaultScopedAccountProvider);
    expect(resolved?.id, 'a2');
  });

  test('scopedWalletsProvider stays empty while auth is not ready', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_EmptyAuthNotifier.new),
        householdScopeProvider.overrideWith(
          (ref) => const HouseholdScope(
            viewMode: ViewMode.personal,
            selected: SelectedHouseholdState(),
            portfolioHouseholdIds: <String>{},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(scopedWalletsProvider.future),
      completion(isEmpty),
    );
  });
}
