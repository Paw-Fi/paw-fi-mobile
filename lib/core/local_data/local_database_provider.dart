import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/moneko_database.dart';

final localDatabaseProvider = FutureProvider<MonekoDatabase>((ref) async {
  final database = await MonekoDatabase.openDefault();
  ref.onDispose(() {
    database.close();
  });
  return database;
});

/// Monotonic local transaction revision for transaction-derived surfaces.
///
/// This deliberately represents committed SQLite changes only. It lets a
/// persisted dashboard snapshot merge a newer locally reconciled transaction
/// while preserving stale-while-revalidate network behavior.
final localTransactionRevisionProvider = StreamProvider<int>((ref) async* {
  final database = await ref.watch(localDatabaseProvider.future);
  var revision = 0;
  await for (final _ in database.transactionChanges) {
    yield ++revision;
  }
});
