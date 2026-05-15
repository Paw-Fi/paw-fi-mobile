import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/smart_transaction_input.dart';

void main() {
  group('suggestCategoryForMerchant', () {
    test('uses previous merchant category with high confidence', () {
      final suggestion = suggestCategoryForMerchant(
        merchant: 'Starbucks',
        history: [
          _entry(
            id: 'old_1',
            merchant: 'starbucks',
            category: 'coffee',
            date: DateTime(2026, 4, 1),
          ),
        ],
      );

      expect(suggestion?.category, 'coffee');
      expect(suggestion?.confidence, SmartInputConfidence.high);
    });

    test('returns null for unknown merchant', () {
      final suggestion = suggestCategoryForMerchant(
        merchant: 'Unknown shop',
        history: [
          _entry(
            id: 'old_1',
            merchant: 'Starbucks',
            category: 'coffee',
          ),
        ],
      );

      expect(suggestion, isNull);
    });
  });

  group('detectRecurringCandidate', () {
    test('detects same merchant and amount near monthly cadence', () {
      final suggestion = detectRecurringCandidate(
        merchant: 'Netflix',
        amountCents: 1299,
        date: DateTime(2026, 5, 12),
        history: [
          _entry(
            id: 'old_1',
            merchant: 'Netflix',
            amountCents: 1299,
            date: DateTime(2026, 4, 12),
          ),
          _entry(
            id: 'old_2',
            merchant: 'Netflix',
            amountCents: 1299,
            date: DateTime(2026, 3, 13),
          ),
        ],
      );

      expect(suggestion?.frequency, RecurringCandidateFrequency.monthly);
      expect(suggestion?.confidence, SmartInputConfidence.high);
    });

    test('ignores mismatched amount', () {
      final suggestion = detectRecurringCandidate(
        merchant: 'Netflix',
        amountCents: 1599,
        date: DateTime(2026, 5, 12),
        history: [
          _entry(
            id: 'old_1',
            merchant: 'Netflix',
            amountCents: 1299,
            date: DateTime(2026, 4, 12),
          ),
        ],
      );

      expect(suggestion, isNull);
    });
  });

  group('SmartInputAnalysisMemory', () {
    test(
        'reuses a previous single-item analysis when only the amount changes and word order changes',
        () {
      final memory = SmartInputAnalysisMemory.fromAnalysisResponse(
        inputText: 'coffee €5.50',
        responseData: {
          'success': true,
          'data': {
            'items': [
              {
                'description': 'coffee',
                'amount': 5.50,
                'currency': 'EUR',
                'currencySymbol': '€',
                'category': 'coffee',
                'date': '2026-05-07',
                'type': 'expense',
              },
            ],
          },
        },
        defaultDateYmd: '2026-05-07',
      );

      expect(memory, isNotNull);

      final reused = memory!.tryBuildResponseFor(
        inputText: '€7,25 coffee',
        defaultDateYmd: '2026-05-08',
      );

      expect(reused, isNotNull);
      final items = ((reused!['data'] as Map)['items'] as List).cast<Map>();
      expect(items.single['amount'], 7.25);
      expect(items.single['date'], '2026-05-08');
      expect(items.single['category'], 'coffee');
    });

    test('allows the same adjacent amount marker on either side', () {
      final memory = SmartInputAnalysisMemory.fromAnalysisResponse(
        inputText: 'coffee €5.50',
        responseData: {
          'success': true,
          'data': {
            'items': [
              {
                'description': 'coffee',
                'amount': 5.50,
                'currency': 'EUR',
                'currencySymbol': '€',
                'category': 'coffee',
                'date': '2026-05-07',
              },
            ],
          },
        },
        defaultDateYmd: '2026-05-07',
      );

      final reused = memory!.tryBuildResponseFor(
        inputText: 'coffee 7.25€',
        defaultDateYmd: '2026-05-08',
      );

      expect(reused, isNotNull);
    });

    test('does not reuse when another numeric value makes the input ambiguous',
        () {
      final memory = SmartInputAnalysisMemory.fromAnalysisResponse(
        inputText: 'coffee 5',
        responseData: {
          'success': true,
          'data': {
            'items': [
              {
                'description': 'coffee',
                'amount': 5,
                'currency': 'EUR',
                'currencySymbol': '€',
                'category': 'coffee',
                'date': '2026-05-07',
              },
            ],
          },
        },
        defaultDateYmd: '2026-05-07',
      );

      expect(
        memory!.tryBuildResponseFor(
          inputText: 'coffee 7 on 12/05',
          defaultDateYmd: '2026-05-08',
        ),
        isNull,
      );
    });

    test('does not cache analysis with an explicit or relative date result',
        () {
      final memory = SmartInputAnalysisMemory.fromAnalysisResponse(
        inputText: 'coffee yesterday 5',
        responseData: {
          'success': true,
          'data': {
            'items': [
              {
                'description': 'coffee yesterday',
                'amount': 5,
                'currency': 'EUR',
                'currencySymbol': '€',
                'category': 'coffee',
                'date': '2026-05-06',
              },
            ],
          },
        },
        defaultDateYmd: '2026-05-07',
      );

      expect(memory, isNull);
    });

    test('supports non-Latin decimal digits and separators', () {
      final memory = SmartInputAnalysisMemory.fromAnalysisResponse(
        inputText: 'قهوة ١٢٫٥٠',
        responseData: {
          'success': true,
          'data': {
            'items': [
              {
                'description': 'قهوة',
                'amount': 12.50,
                'currency': 'EUR',
                'currencySymbol': '€',
                'category': 'coffee',
                'date': '2026-05-07',
              },
            ],
          },
        },
        defaultDateYmd: '2026-05-07',
      );

      expect(memory, isNotNull);

      final reused = memory!.tryBuildResponseFor(
        inputText: 'قهوة ١٥٫٧٥',
        defaultDateYmd: '2026-05-08',
      );
      final items = ((reused!['data'] as Map)['items'] as List).cast<Map>();

      expect(items.single['amount'], 15.75);
    });
  });
}

ExpenseEntry _entry({
  required String id,
  String? merchant,
  String? category,
  int amountCents = 1000,
  DateTime? date,
}) {
  return ExpenseEntry(
    id: id,
    userId: 'user_1',
    date: date ?? DateTime(2026, 4, 1),
    amountCents: amountCents,
    currency: 'EUR',
    category: category ?? 'other',
    createdAt: DateTime.utc(2026, 4, 1),
    merchant: merchant,
    type: 'expense',
  );
}
