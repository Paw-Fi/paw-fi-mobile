import '../../../core/local_database/app_database.dart';
import 'transaction_command.dart';

abstract class TransactionRepository {
  Future<String> createLocalTransaction(CreateTransactionCommand command);

  Future<List<LocalTransactionRecord>> needsReviewTransactions({
    required String userId,
    String? householdId,
    int limit = 50,
  });

  Future<void> markTransactionReviewed(String transactionId);

  Future<void> updateReviewCategory({
    required String transactionId,
    required String category,
  });
}
