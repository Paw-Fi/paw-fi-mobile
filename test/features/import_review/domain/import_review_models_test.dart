import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/import_review/domain/import_review_models.dart';

void main() {
  test('parses structured source and resolved transaction context', () {
    final review = ImportReview.fromJson({
      'status': 'completed',
      'version': 2,
      'expiresAt': '2026-08-14T10:00:00.000Z',
      'source': {
        'senderEmail': 'receipts@example.com',
        'subjectLine': 'August card receipts',
        'receivedAt': '2026-08-11T10:00:00.000Z',
        'files': [
          {
            'name': 'hotel.pdf',
            'status': 'processed',
            'transactionCount': 2,
          },
        ],
      },
      'items': [
        {
          'id': 'item-1',
          'summary': 'Airport ride',
          'transaction': {
            'type': 'expense',
            'amount': 42.5,
            'currency': 'USD',
            'date': '2026-08-10',
            'merchant': 'City Taxi',
            'description': 'Airport ride',
            'category': 'transportation',
          },
          'issues': [],
          'saveStatus': 'saved',
          'transactionId': 'transaction-id',
        },
      ],
    });

    expect(review.source.senderEmail, 'receipts@example.com');
    expect(review.source.files.single.name, 'hotel.pdf');
    expect(review.source.files.single.transactionCount, 2);
    expect(review.items.single.transaction.amount, 42.5);
    expect(review.items.single.transaction.merchant, 'City Taxi');
    expect(review.items.single.saveStatus, 'saved');
    expect(review.items.single.transactionId, 'transaction-id');
  });
}
