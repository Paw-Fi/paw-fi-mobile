import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';

void main() {
  group('recurring occurrence confirmation identity', () {
    test('uses one stable idempotency key for duplicate confirmation taps', () {
      final first = recurringOccurrenceIdempotencyKey(
        userId: 'user-1',
        recurringId: 'rent-series',
        scheduledOccurrenceDate: DateTime(2026, 7, 24),
      );
      final replay = recurringOccurrenceIdempotencyKey(
        userId: 'user-1',
        recurringId: 'rent-series',
        scheduledOccurrenceDate: DateTime(2026, 7, 24, 23, 59),
      );

      expect(replay, first);
      expect(first, 'recurring-occurrence:v1:user-1:rent-series:2026-07-24');
    });

    test('keeps separate occurrences independently idempotent', () {
      final overdue = recurringOccurrenceIdempotencyKey(
        userId: 'user-1',
        recurringId: 'rent-series',
        scheduledOccurrenceDate: DateTime(2026, 6, 24),
      );
      final current = recurringOccurrenceIdempotencyKey(
        userId: 'user-1',
        recurringId: 'rent-series',
        scheduledOccurrenceDate: DateTime(2026, 7, 24),
      );

      expect(current, isNot(overdue));
    });

    test(
        'parses persisted imported occurrences without requiring a transaction',
        () {
      final item = RecurringOccurrenceTimelineItem.fromPersistedJson({
        'occurrence': {
          'scheduled_occurrence_date': '2026-07-01',
          'status': 'confirmed',
          'paid_date': '2026-07-02',
          'amount_cents': 1234,
          'currency': 'USD',
          'confirmed_at': '2026-07-02T10:00:00Z',
          'confirmation_source': 'legacy_migration',
        },
        'transaction': null,
        'settlement_locked': true,
      });

      expect(item.isConfirmed, isTrue);
      expect(item.isImported, isTrue);
      expect(item.actualTransaction, isNull);
      expect(item.amountCents, 1234);
      expect(item.paidDate, DateTime(2026, 7, 2));
      expect(item.isSettlementLocked, isTrue);
    });

    test('parses list-occurrence summaries without a detail wrapper', () {
      final item = RecurringOccurrenceTimelineItem.fromOccurrenceSummaryJson({
        'id': 'occurrence-1',
        'recurring_id': 'rent-series',
        'scheduled_occurrence_date': '2026-08-12',
        'status': 'confirmed',
        'actual_transaction_id': 'actual-1',
        'paid_date': '2026-08-12',
        'amount_cents': 485000,
        'currency': 'USD',
        'confirmed_at': '2026-08-12T10:00:00Z',
      });

      expect(item.isConfirmed, isTrue);
      expect(item.actualTransactionId, 'actual-1');
      expect(item.actualTransaction, isNull);
      expect(item.scheduledOccurrenceDate, DateTime(2026, 8, 12));
    });
  });
}
