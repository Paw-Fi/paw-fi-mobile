import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../local_database/app_database_provider.dart';
import 'sync_queue_service.dart';

final syncRemoteClientProvider = Provider<SyncRemoteClient>((ref) {
  return SupabaseSyncRemoteClient(Supabase.instance.client);
});

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final remoteClient = ref.watch(syncRemoteClientProvider);
  return SyncQueueService(
    database: database,
    remoteClient: remoteClient,
  );
});

final syncQueueProcessorProvider = Provider<SyncQueueProcessor>((ref) {
  return ref.watch(syncQueueServiceProvider);
});
