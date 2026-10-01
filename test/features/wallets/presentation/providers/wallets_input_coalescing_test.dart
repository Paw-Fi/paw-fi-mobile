import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/network/network_reachability_provider.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';

class _HeldFeed extends EmptyTransactionsFeedService {
  final gates = <Completer<List<ExpenseEntry>>>[];

  @override
  Future<List<ExpenseEntry>> fetchAllPages(TransactionsFeedQuery query) {
    final gate = Completer<List<ExpenseEntry>>();
    gates.add(gate);
    return gate.future;
  }
}

void main() {
  late MonekoDatabase database;
  late ProviderContainer container;
  late _HeldFeed feed;
  late WalletsScopeQuery scope;

  setUp(() async {
    database = MonekoDatabase.inMemory();
    feed = _HeldFeed();
    final now = effectiveNow(preferredTimezone: 'UTC');
    scope = WalletsScopeQuery(
      userId: 'user-1',
      householdId: null,
      selectedCurrency: 'USD',
      currentMonthStart: DateTime(now.year, now.month, 1),
    );
    container = ProviderContainer(overrides: [
      appPreferredTimezoneProvider.overrideWith((ref) => 'UTC'),
      walletAuthHeadersProvider.overrideWith((ref) => null),
      networkReachabilityProvider.overrideWith((ref) => Stream.value(false)),
      localDatabaseProvider.overrideWith((ref) async => database),
      transactionsFeedServiceProvider.overrideWithValue(feed),
      currencyRateTableProvider
          .overrideWith((ref) async => const CurrencyRateTable(
                baseCurrency: 'USD',
                rates: {'USD': 1},
              )),
      householdScopeProvider.overrideWithValue(const HouseholdScope(
        viewMode: ViewMode.personal,
        selected: SelectedHouseholdState(),
        portfolioHouseholdIds: <String>{},
      )),
    ]);
    container.read(walletsListSessionCacheProvider.notifier).state = {
      walletsListCacheKey(
        userId: scope.userId,
        householdId: scope.householdId,
        selectedCurrency: scope.selectedCurrency,
        selectedCurrencies: scope.normalizedSelectedCurrencies,
        currentMonthStart: scope.currentMonthStart,
      ): const <WalletEntity>[],
    };
    await container.read(localDatabaseProvider.future);
    await pumpEventQueue();
  });

  tearDown(() async {
    for (final gate in feed.gates) {
      if (!gate.isCompleted) gate.complete(const []);
    }
    await pumpEventQueue();
    container.dispose();
    await database.close();
  });

  test('concurrent history and current snapshot share exact legacy inputs',
      () async {
    final loader = container.read(walletsLegacyDataLoaderProvider);
    final history = loader.fetchHistory(scope);
    final snapshot = loader.fetchMonthSnapshot(WalletsMonthQuery(
      scope: scope,
      monthStart: scope.currentMonthStart,
    ));
    await pumpEventQueue();
    expect(feed.gates.length, 1);
    feed.gates.single.complete(const []);
    await Future.wait([history, snapshot]);
    final subsequent = loader.fetchHistory(scope);
    await pumpEventQueue();
    expect(feed.gates.length, 2);
    feed.gates.last.complete(const []);
    await subsequent;
  });

  test('historical snapshot keeps its distinct transaction date range',
      () async {
    final loader = container.read(walletsLegacyDataLoaderProvider);
    final history = loader.fetchHistory(scope);
    final snapshot = loader.fetchMonthSnapshot(WalletsMonthQuery(
      scope: scope,
      monthStart: DateTime(
          scope.currentMonthStart.year, scope.currentMonthStart.month - 1, 1),
    ));
    await pumpEventQueue();
    expect(feed.gates.length, 2);
    for (final gate in feed.gates) {
      gate.complete(const []);
    }
    await Future.wait([history, snapshot]);
  });

  test('a committed transaction revision cannot join older wallet inputs',
      () async {
    final loader = container.read(walletsLegacyDataLoaderProvider);
    final older = loader.fetchHistory(scope);
    await pumpEventQueue();
    expect(feed.gates.length, 1);
    final revision = database.transactionRevision;
    await database.upsertTransactions([
      ExpenseEntry(
        id: 'new',
        userId: scope.userId,
        amountCents: 5000,
        currency: 'USD',
        category: 'food',
        type: 'expense',
        date: scope.currentMonthStart,
        createdAt: scope.currentMonthStart,
      )
    ]);
    expect(database.transactionRevision, greaterThan(revision));
    final newer = loader.fetchHistory(scope);
    await pumpEventQueue();
    expect(feed.gates.length, 2);
    feed.gates.last.complete(const []);
    await newer;
    feed.gates.first.complete(const []);
    await older;
  });
}
