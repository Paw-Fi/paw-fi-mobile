import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/home/presentation/state/dashboard_cache_store.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/insights/presentation/state/monthly_report_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pocket_details_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_cache_store.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';

final userFinancialCacheCleanupProvider =
    Provider<UserFinancialCacheCleanup>(UserFinancialCacheCleanup.new);
final userFinancialCacheCleanupInProgressProvider =
    StateProvider<bool>((ref) => false);

class UserFinancialCacheCleanup {
  UserFinancialCacheCleanup(this.ref);

  final Ref ref;

  Future<void> clearForFinancialDataReset({required String userId}) async {
    await _withMainShellSuspended(
      () async {
        await _purge(userId);
        _refreshMainShellProviders();
      },
      releaseOnError: false,
    );
  }

  Future<void> clearForLogout({
    required String userId,
    Future<void> Function()? signOut,
  }) {
    return _withMainShellSuspended(() async {
      await _purge(userId);
      await signOut?.call();
    });
  }

  Future<void> _withMainShellSuspended(
    Future<void> Function() cleanup, {
    bool releaseOnError = true,
  }) async {
    final cleanupState =
        ref.read(userFinancialCacheCleanupInProgressProvider.notifier);
    cleanupState.state = true;
    var succeeded = false;
    try {
      await cleanup();
      succeeded = true;
    } finally {
      if (succeeded || releaseOnError) {
        cleanupState.state = false;
      }
    }
  }

  Future<void> _purge(String userId) async {
    if (userId.trim().isEmpty) return;

    final dashboardBypass =
        ref.read(dashboardPersistedCacheBypassCountProvider.notifier);
    final walletsBypass =
        ref.read(walletsPersistedCacheBypassCountProvider.notifier);
    final walletPageBypass =
        ref.read(walletsPageStatePersistedCacheBypassProvider.notifier);
    final pocketsBypass =
        ref.read(pocketsPersistedCacheBypassCountProvider.notifier);
    dashboardBypass.state++;
    walletsBypass.state++;
    walletPageBypass.state++;
    pocketsBypass.state++;

    clearDashboardSessionCache();
    clearDashboardProviderMemoryForUser(ref, userId);
    clearWalletsPageStateMemoryCaches(ref);
    ref.read(walletsListSessionCacheProvider.notifier).state = const {};
    ref.read(walletsPageStateSessionCacheProvider.notifier).state = const {};
    ref.read(optimisticScopedAccountsOverridesProvider.notifier).state =
        const {};

    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> runCleanup(Future<void> Function() cleanup) async {
      try {
        await cleanup();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    try {
      await runCleanup(
        () => clearPocketsCachesForUser(ref, userId: userId),
      );
      await runCleanup(() async {
        final database = await ref.read(localDatabaseProvider.future);
        await database.clearAllLocalData();
      });
      await runCleanup(
        () => clearAllDashboardPersistedCachesForUser(ref, userId: userId),
      );
      await runCleanup(
        () => clearAllWalletsCachesForUser(ref, userId: userId),
      );
    } finally {
      dashboardBypass.state =
          dashboardBypass.state > 0 ? dashboardBypass.state - 1 : 0;
      walletsBypass.state =
          walletsBypass.state > 0 ? walletsBypass.state - 1 : 0;
      walletPageBypass.state =
          walletPageBypass.state > 0 ? walletPageBypass.state - 1 : 0;
      pocketsBypass.state =
          pocketsBypass.state > 0 ? pocketsBypass.state - 1 : 0;
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  void _refreshMainShellProviders() {
    ref.read(transactionsFeedRefreshSignalProvider.notifier).state++;
    ref.read(dashboardRefreshSignalProvider.notifier).state++;
    ref.read(walletsRefreshSignalProvider.notifier).state++;

    ref.invalidate(analyticsProvider);
    ref.invalidate(currencyTransactionCountsProvider);
    ref.invalidate(recurringTransactionsProvider);
    ref.invalidate(recurringOccurrenceTimelineProvider);
    ref.invalidate(pocketsProvider);
    ref.invalidate(pocketDetailsProvider);
    ref.invalidate(scopedWalletsProvider);
    ref.invalidate(archivedScopedAccountsProvider);
    ref.invalidate(walletsPageStateProvider);
    ref.invalidate(walletsHistoryProvider);
    ref.invalidate(walletsMonthSnapshotProvider);
    ref.invalidate(bankConnectionsProvider);
    ref.invalidate(monthlyFinancialReportProvider);
    ref.invalidate(householdProvider);
    ref.invalidate(householdMembersProvider);
    ref.invalidate(householdBudgetsProvider);
    ref.invalidate(householdExpensesProvider);
    ref.invalidate(householdSplitsProvider);
  }
}
