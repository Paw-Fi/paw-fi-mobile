import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';

void main() {
  group('receiptStoragePathFromPublicUrl', () {
    test('extracts receipt object path from public Supabase URL', () {
      final path = receiptStoragePathFromPublicUrl(
        'https://project.supabase.co/storage/v1/object/public/expense-receipts/receipts/user-123/photo.jpg',
      );

      expect(path, 'receipts/user-123/photo.jpg');
    });

    test('returns null for URLs outside the expense receipts bucket', () {
      final path = receiptStoragePathFromPublicUrl(
        'https://project.supabase.co/storage/v1/object/public/avatars/user-123/photo.jpg',
      );

      expect(path, isNull);
    });
  });
}
