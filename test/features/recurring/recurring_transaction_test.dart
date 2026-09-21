import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

RecurringTransaction _tx({
  required DateTime anchor,
  required String frequency,
  int? interval,
}) {
  return RecurringTransaction(
    id: 't1',
    date: anchor,
    category: 'rent',
    description: 'Test',
    source: null,
    amount: 10.0,
    currency: 'USD',
    ownerType: 'me',
    privacyScope: 'full',
    householdId: null,
    payerUserId: null,
    recurrenceRule: RecurrenceRule(
      frequency: frequency,
      anchorDate: anchor,
      interval: interval,
    ),
    type: 'expense',
    attachments: const [],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: null,
  );
}

void main() {
  group('RecurringTransaction.getNextOccurrence', () {
    test('daily ignores time-of-day when reference is midnight', () {
      final tx = _tx(
        anchor: DateTime(2026, 2, 1, 14, 0),
        frequency: 'daily',
      );

      final next = tx.getNextOccurrence(DateTime(2026, 2, 2));
      expect(next.year, 2026);
      expect(next.month, 2);
      expect(next.day, 2);
      // Preserve time-of-day from anchor
      expect(next.hour, 14);
      expect(next.minute, 0);
    });

    test('weekly ignores time-of-day when reference is midnight', () {
      final tx = _tx(
        anchor: DateTime(2026, 2, 1, 14, 0),
        frequency: 'weekly',
      );

      final next = tx.getNextOccurrence(DateTime(2026, 2, 8));
      expect(next.year, 2026);
      expect(next.month, 2);
      expect(next.day, 8);
      expect(next.hour, 14);
      expect(next.minute, 0);
    });

    test('clamps monthly 31st into February', () {
      final tx = _tx(
        anchor: DateTime(2026, 1, 31, 9, 30),
        frequency: 'monthly',
      );
      final next = tx.getNextOccurrence(DateTime(2026, 2, 1));
      expect(next.year, 2026);
      expect(next.month, 2);
      expect(next.day, 28);
      // Preserve time-of-day
      expect(next.hour, 9);
      expect(next.minute, 30);
    });

    test('clamps yearly Feb 29th on non-leap years', () {
      final tx = _tx(
        anchor: DateTime(2024, 2, 29, 8, 0),
        frequency: 'yearly',
      );
      final next = tx.getNextOccurrence(DateTime(2025, 2, 28));
      expect(next.year, 2025);
      expect(next.month, 2);
      expect(next.day, 28);
      expect(next.hour, 8);
      expect(next.minute, 0);
    });

    test('supports interval-based monthly (every 3 months)', () {
      final tx = _tx(
        anchor: DateTime(2026, 1, 15),
        frequency: 'monthly',
        interval: 3,
      );
      final next = tx.getNextOccurrence(DateTime(2026, 2, 1));
      // Jan 15 -> Apr 15
      expect(next.year, 2026);
      expect(next.month, 4);
      expect(next.day, 15);
    });
  });
}
