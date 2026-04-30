import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/local_database/app_database_provider.dart';
import '../domain/transaction_repository.dart';
import 'transaction_repository_impl.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return TransactionRepositoryImpl(database: database);
});
