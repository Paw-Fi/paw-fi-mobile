import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';

final walletsRefreshSignalProvider = StateProvider<int>((ref) => 0);

abstract class WalletsDataService {
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query);
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(WalletsMonthQuery query);
}

class SupabaseWalletsDataService implements WalletsDataService {
  const SupabaseWalletsDataService();

  @override
  Future<WalletsHistorySummary> fetchHistory(WalletsScopeQuery query) async {
    final response = await supabase.rpc(
      'get_wallets_history_v1',
      params: query.toHistoryRpcParams(),
    );
    return WalletsHistorySummary.fromJson(_toMap(response));
  }

  @override
  Future<WalletsMonthSnapshot> fetchMonthSnapshot(
      WalletsMonthQuery query) async {
    final response = await supabase.rpc(
      'get_wallets_month_snapshot_v1',
      params: query.toRpcParams(),
    );
    return WalletsMonthSnapshot.fromJson(_toMap(response));
  }

  Map<String, dynamic> _toMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    return const <String, dynamic>{};
  }
}

final walletsDataServiceProvider = Provider<WalletsDataService>((ref) {
  return const SupabaseWalletsDataService();
});

final walletsHistoryProvider =
    FutureProvider.family<WalletsHistorySummary, WalletsScopeQuery>(
  (ref, query) async {
    ref.watch(walletsRefreshSignalProvider);
    ref.watch(dashboardRefreshSignalProvider);
    final service = ref.watch(walletsDataServiceProvider);
    return service.fetchHistory(query);
  },
);

final walletsMonthSnapshotProvider =
    FutureProvider.autoDispose.family<WalletsMonthSnapshot, WalletsMonthQuery>(
  (ref, query) async {
    ref.watch(walletsRefreshSignalProvider);
    ref.watch(dashboardRefreshSignalProvider);
    final service = ref.watch(walletsDataServiceProvider);
    return service.fetchMonthSnapshot(query);
  },
);
