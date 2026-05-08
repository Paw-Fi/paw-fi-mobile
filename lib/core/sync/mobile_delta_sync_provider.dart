import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/sync/mobile_delta_sync_service.dart';

final mobileDeltaSyncServiceProvider =
    FutureProvider<MobileDeltaSyncService>((ref) async {
  final database = await ref.watch(localDatabaseProvider.future);
  return MobileDeltaSyncService(
    database: database,
    fetchDelta: supabaseMobileDeltaFetcher(),
  );
});
