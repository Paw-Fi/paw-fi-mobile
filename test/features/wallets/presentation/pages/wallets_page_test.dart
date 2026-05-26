import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/pages/wallets_page.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends Auth {
  @override
  AppUser build() {
    return const AppUser(uid: 'u1', email: 'u1@example.com');
  }
}

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

class _StubHouseholdRepository implements HouseholdRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

class _MismatchedCurrentBalanceWalletsDataService
    implements WalletsDataService {
  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    return WalletsHistorySummary(
      availableMonths: [query.currentMonthStart],
      netWorthSeries: [
        WalletNetWorthPoint(
          monthStart: query.currentMonthStart,
          netWorthCents: -600,
        ),
      ],
    );
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
    WalletsMonthQuery query,
  ) async {
    return WalletsMonthSnapshot(
      monthStart: query.monthStart,
      monthEndExclusive:
          DateTime(query.monthStart.year, query.monthStart.month + 1, 1),
      incomeTotalCents: 0,
      spentTotalCents: 0,
      netWorthCents: -600,
      walletBalances: const {'a1': -600},
    );
  }
}

class _ThrowingWalletsDataService implements WalletsDataService {
  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) {
    throw StateError('preview mode should not hit live history service');
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(WalletsMonthQuery query) {
    throw StateError('preview mode should not hit live month snapshot service');
  }
}

class _DelayedWalletsDataService implements WalletsDataService {
  _DelayedWalletsDataService({required this.snapshotCompleter});

  final Completer<void> snapshotCompleter;

  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    return WalletsHistorySummary(
      availableMonths: [DateTime(2026, 4, 1)],
      netWorthSeries: [
        WalletNetWorthPoint(
          monthStart: DateTime(2026, 4, 1),
          netWorthCents: 1200,
        ),
      ],
    );
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
    WalletsMonthQuery query,
  ) async {
    await snapshotCompleter.future;
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

class _FailingSnapshotWalletsDataService implements WalletsDataService {
  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    return WalletsHistorySummary(
      availableMonths: [DateTime(2026, 4, 1)],
      netWorthSeries: [
        WalletNetWorthPoint(
          monthStart: DateTime(2026, 4, 1),
          netWorthCents: 1200,
        ),
      ],
    );
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
    WalletsMonthQuery query,
  ) async {
    throw Exception('snapshot failed');
  }
}

class _WindowedWalletsDataService implements WalletsDataService {
  _WindowedWalletsDataService({required this.delayedMonths});

  final Map<DateTime, Completer<void>> delayedMonths;

  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    return WalletsHistorySummary(
      availableMonths: [
        DateTime(2026, 4, 1),
        DateTime(2026, 3, 1),
        DateTime(2026, 2, 1),
      ],
      netWorthSeries: [
        WalletNetWorthPoint(
          monthStart: DateTime(2026, 2, 1),
          netWorthCents: 900,
        ),
        WalletNetWorthPoint(
          monthStart: DateTime(2026, 3, 1),
          netWorthCents: 1000,
        ),
        WalletNetWorthPoint(
          monthStart: DateTime(2026, 4, 1),
          netWorthCents: 1200,
        ),
      ],
    );
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
    WalletsMonthQuery query,
  ) async {
    final completer = delayedMonths[query.monthStart];
    if (completer != null) {
      await completer.future;
    }

    return WalletsMonthSnapshot(
      monthStart: query.monthStart,
      monthEndExclusive:
          DateTime(query.monthStart.year, query.monthStart.month + 1, 1),
      incomeTotalCents: 500,
      spentTotalCents: 300,
      netWorthCents: 1200 - ((4 - query.monthStart.month) * 100),
      walletBalances: {
        'a1': 1200 - ((4 - query.monthStart.month) * 100),
      },
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
          authAccessTokenProvider.overrideWith((ref) => 'token-123'),
          bankConnectionsProvider.overrideWith((ref) async => const []),
          appPreferredTimezoneProvider.overrideWith((ref) => null),
          mainShellTabIndexProvider.overrideWith((ref) => 0),
          sharedPreferencesProvider.overrideWithValue(prefs),
          scopedWalletsProvider
              .overrideWith(() => _StaticScopedWalletsNotifier(wallets)),
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Spending'), findsWidgets);
    expect(find.text('Total Net Worth'), findsWidgets);
  });

  testWidgets('current month net worth follows displayed wallet balances',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
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
        currentBalanceCents: -620,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthNotifier.new),
          authAccessTokenProvider.overrideWith((ref) => 'token-123'),
          bankConnectionsProvider.overrideWith((ref) async => const []),
          appPreferredTimezoneProvider.overrideWith((ref) => null),
          mainShellTabIndexProvider.overrideWith((ref) => 0),
          localDatabaseProvider.overrideWith((ref) async => database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          scopedWalletsProvider
              .overrideWith(() => _StaticScopedWalletsNotifier(wallets)),
          effectiveScopeWalletsProvider.overrideWith((ref) => wallets),
          walletsDataServiceProvider.overrideWithValue(
            _MismatchedCurrentBalanceWalletsDataService(),
          ),
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text(r'$-6.20'), findsWidgets);
    expect(find.text(r'$-6.00'), findsNothing);
  });

  testWidgets(
      'connect bank button remains on wallets page in supported timezone',
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
          authAccessTokenProvider.overrideWith((ref) => 'token-123'),
          appPreferredTimezoneProvider.overrideWith(
            (ref) => 'America/New_York',
          ),
          bankConnectionsProvider.overrideWith((ref) async => const []),
          mainShellTabIndexProvider.overrideWith((ref) => 0),
          sharedPreferencesProvider.overrideWithValue(prefs),
          scopedWalletsProvider
              .overrideWith(() => _StaticScopedWalletsNotifier(wallets)),
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
    await tester.dragUntilVisible(
      find.text('Connect Bank'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.text('Connect Bank'), findsOneWidget);
    expect(find.byType(AccountsPage), findsOneWidget);
  });

  testWidgets('wallets page renders preview wallet data in preview mode',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthNotifier.new),
          authAccessTokenProvider.overrideWith((ref) => 'token-123'),
          mainShellTabIndexProvider.overrideWith((ref) => 0),
          bankConnectionsProvider.overrideWith((ref) async => const []),
          sharedPreferencesProvider.overrideWithValue(prefs),
          previewModeProvider.overrideWith(
            (ref) => PreviewModeNotifier(initiallyActive: true),
          ),
          walletsDataServiceProvider
              .overrideWithValue(_ThrowingWalletsDataService()),
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

    final spendingCard = find.byKey(const ValueKey('preview-spending'));
    final savingsCard = find.byKey(const ValueKey('preview-savings'));

    expect(find.text('Everyday Spending'), findsWidgets);
    expect(find.text('Chase Sapphire'), findsWidgets);
    expect(find.text('High-Yield Savings'), findsWidgets);
    expect(
      tester.getTopLeft(spendingCard).dy,
      lessThan(tester.getTopLeft(savingsCard).dy),
    );
    expect(find.text('Total Net Worth'), findsWidgets);
  });

  testWidgets(
      'wallets page renders household preview wallet data without live service',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final previewHouseholds = <Household>[
      Household(
        id: 'preview-house-1',
        name: 'Preview Shared Space',
        ownerId: 'u1',
        currency: 'USD',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthNotifier.new),
          authAccessTokenProvider.overrideWith((ref) => 'token-123'),
          mainShellTabIndexProvider.overrideWith((ref) => 0),
          bankConnectionsProvider.overrideWith((ref) async => const []),
          sharedPreferencesProvider.overrideWithValue(prefs),
          previewModeProvider.overrideWith(
            (ref) => PreviewModeNotifier(initiallyActive: true),
          ),
          walletsDataServiceProvider
              .overrideWithValue(_ThrowingWalletsDataService()),
          userHouseholdsProvider.overrideWith(
            (ref, userId) => UserHouseholdsNotifier(
              _StubHouseholdRepository(),
              userId,
              ref,
              initialHouseholds: previewHouseholds,
            ),
          ),
          householdScopeProvider.overrideWith(
            (ref) => const HouseholdScope(
              viewMode: ViewMode.household,
              selected: SelectedHouseholdState(householdId: 'preview-house-1'),
              portfolioHouseholdIds: {'preview-card', 'preview-savings'},
            ),
          ),
          viewModeProvider.overrideWith(
            (ref) => ViewModeNotifier()..setMode(ViewMode.household),
          ),
        ],
        child: const MaterialApp(home: AccountsPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Loft Shared Spending'), findsWidgets);
    expect(find.text('Total Net Worth'), findsWidgets);
  });

  testWidgets('wallets page stays in skeleton state while auth is not ready',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_EmptyAuthNotifier.new),
          mainShellTabIndexProvider.overrideWith((ref) => 0),
          bankConnectionsProvider.overrideWith((ref) async => const []),
          sharedPreferencesProvider.overrideWithValue(prefs),
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

    await tester.pump();

    expect(find.text('Total Net Worth'), findsNothing);
    expect(find.text('New Wallet'), findsNothing);
  });

  testWidgets(
      'wallets page stays in skeleton state while auth session headers are unavailable',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthNotifier.new),
          walletAuthHeadersProvider.overrideWith((ref) => null),
          mainShellTabIndexProvider.overrideWith((ref) => 0),
          bankConnectionsProvider.overrideWith((ref) async => const []),
          sharedPreferencesProvider.overrideWithValue(prefs),
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

    await tester.pump();

    expect(find.text('Total Net Worth'), findsNothing);
    expect(find.text('New Wallet'), findsNothing);
    expect(find.text('No wallets yet'), findsNothing);
  });

  testWidgets('wallets page remains usable while selected snapshot resolves',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshotCompleter = Completer<void>();
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
          authAccessTokenProvider.overrideWith((ref) => 'token-123'),
          appPreferredTimezoneProvider.overrideWith((ref) => null),
          mainShellTabIndexProvider.overrideWith((ref) => 0),
          bankConnectionsProvider.overrideWith((ref) async => const []),
          sharedPreferencesProvider.overrideWithValue(prefs),
          scopedWalletsProvider
              .overrideWith(() => _StaticScopedWalletsNotifier(wallets)),
          effectiveScopeWalletsProvider.overrideWith((ref) => wallets),
          walletsDataServiceProvider.overrideWithValue(
            _DelayedWalletsDataService(snapshotCompleter: snapshotCompleter),
          ),
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

    await tester.pump();

    expect(find.text('Total Net Worth'), findsOneWidget);
    expect(find.text('Spending'), findsWidgets);
    expect(
      find.byKey(const ValueKey('wallets-overview-loading')),
      findsNothing,
    );

    snapshotCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('Total Net Worth'), findsWidgets);
    expect(find.text('Spending'), findsWidgets);
  });

  testWidgets(
      'wallets page keeps wallet content visible when snapshot load fails',
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
          authAccessTokenProvider.overrideWith((ref) => 'token-123'),
          appPreferredTimezoneProvider.overrideWith((ref) => null),
          mainShellTabIndexProvider.overrideWith((ref) => 0),
          bankConnectionsProvider.overrideWith((ref) async => const []),
          sharedPreferencesProvider.overrideWithValue(prefs),
          scopedWalletsProvider
              .overrideWith(() => _StaticScopedWalletsNotifier(wallets)),
          effectiveScopeWalletsProvider.overrideWith((ref) => wallets),
          walletsDataServiceProvider.overrideWithValue(
            _FailingSnapshotWalletsDataService(),
          ),
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Total Net Worth'), findsOneWidget);
    expect(find.text('Spending'), findsWidgets);
  });

  testWidgets('wallets page keeps wallet stack visible while older month loads',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final januaryCompleter = Completer<void>();
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
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_FakeAuthNotifier.new),
      authAccessTokenProvider.overrideWith((ref) => 'token-123'),
      appPreferredTimezoneProvider.overrideWith((ref) => null),
      mainShellTabIndexProvider.overrideWith((ref) => 0),
      bankConnectionsProvider.overrideWith((ref) async => const []),
      sharedPreferencesProvider.overrideWithValue(prefs),
      scopedWalletsProvider
          .overrideWith(() => _StaticScopedWalletsNotifier(wallets)),
      effectiveScopeWalletsProvider.overrideWith((ref) => wallets),
      walletsDataServiceProvider.overrideWithValue(
        _WindowedWalletsDataService(
          delayedMonths: {DateTime(2026, 1, 1): januaryCompleter},
        ),
      ),
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
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AccountsPage()),
      ),
    );

    await tester.pumpAndSettle();

    final scope = container.read(walletsScopeQueryProvider);
    final walletsPageState =
        await container.read(walletsPageStateProvider(scope).future);
    final olderMonthAnchor = walletsPageState.visibleMonths.last;

    await container
        .read(walletsPageStateProvider(scope).notifier)
        .selectMonth(olderMonthAnchor);
    await tester.pump();
    await container
        .read(walletsPageStateProvider(scope).notifier)
        .selectMonth(DateTime(2026, 1, 1));
    await tester.pump();
    await tester.pump();

    expect(
        find.byKey(const ValueKey('wallets-overview-loading')), findsOneWidget);
    expect(find.text('Spending'), findsWidgets);
    expect(find.text('New Wallet'), findsOneWidget);

    januaryCompleter.complete();
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('wallets-overview-loading')), findsNothing);
  });
}
