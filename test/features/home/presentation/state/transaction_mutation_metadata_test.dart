import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/state/ai_quick_log.dart';

void main() {
  group('Transaction mutation metadata', () {
    test('uses the optimistic id as the stable idempotency seed', () {
      const optimisticId = 'optimistic_123_7';

      final metadata = buildTransactionMutationMetadata(optimisticId);

      expect(metadata.clientRecordId, optimisticId);
      expect(metadata.clientMutationId, 'mobile:$optimisticId');
      expect(metadata.idempotencyKey, 'mobile:$optimisticId');
      expect(metadata.toRequestJson(), {
        'clientRecordId': optimisticId,
        'clientMutationId': 'mobile:$optimisticId',
        'idempotencyKey': 'mobile:$optimisticId',
      });
    });

    test('optimistic transaction ids are unique in tight loops', () {
      final ids = <String>{};

      for (var index = 0; index < 1000; index++) {
        ids.add(makeOptimisticTransactionId());
      }

      expect(ids.length, 1000);
    });

    test('record mutation metadata keeps the real record id', () {
      final metadata = buildTransactionMutationMetadataForRecord(
        clientRecordId: 'expense-123',
        operation: 'update transaction',
      );

      expect(metadata.clientRecordId, 'expense-123');
      expect(metadata.clientMutationId,
          startsWith('mobile:update_transaction_expense-123_'));
      expect(metadata.idempotencyKey, metadata.clientMutationId);
    });
  });
}
