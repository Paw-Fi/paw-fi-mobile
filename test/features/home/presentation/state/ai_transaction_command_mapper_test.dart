import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/ai_transaction_command_mapper.dart';
import 'package:moneko/features/transactions/domain/transaction_command.dart';

void main() {
  test('buildAiTransactionCommand carries AI metadata into local capture', () {
    final command = buildAiTransactionCommand(
      userId: 'user-1',
      householdId: 'household-1',
      walletId: 'wallet-1',
      isPortfolio: false,
      transaction: ParsedExpense(
        amount: 25,
        category: 'groceries',
        currency: 'EUR',
        currencySymbol: '€',
        date: DateTime.utc(2026, 4, 30),
        description: 'Weekly shop',
        merchant: 'Tesco',
        breakdown: const ['Milk', 'Bread'],
      ),
      captureSource: TransactionCaptureSource.receiptPhoto,
      receiptImageUrl: 'https://example.com/receipt.jpg',
      localImagePath: '/tmp/receipt.jpg',
      raw: const {'confidenceScore': 0.93},
      isRecurring: true,
      recurrenceRule: const {
        'frequency': 'monthly',
        'anchor_date': '2026-04-30',
      },
      customSplits: const {
        'splitType': 'percentage',
        'memberSplits': [
          {'userId': 'user-1', 'percentage': 60},
          {'userId': 'user-2', 'percentage': 40},
        ],
      },
      payerUserId: 'user-1',
    );

    expect(command.userId, 'user-1');
    expect(command.householdId, 'household-1');
    expect(command.walletId, 'wallet-1');
    expect(command.type, TransactionCommandType.expense);
    expect(command.amountCents, 2500);
    expect(command.currency, 'EUR');
    expect(command.category, 'groceries');
    expect(command.merchant, 'Tesco');
    expect(command.breakdown, ['Milk', 'Bread']);
    expect(command.captureSource, TransactionCaptureSource.receiptPhoto);
    expect(command.confidenceScore, 0.93);
    expect(command.receiptLocalPath, '/tmp/receipt.jpg');
    expect(command.receiptImageUrl, 'https://example.com/receipt.jpg');
    expect(command.recurrenceRule?['frequency'], 'monthly');
    expect(command.customSplits?['splitType'], 'percentage');
    expect(command.payerUserId, 'user-1');
    expect(command.isRecurring, isTrue);
    expect(command.reviewReasons, isEmpty);
  });

  test('buildAiTransactionCommand sends low confidence items to review', () {
    final command = buildAiTransactionCommand(
      userId: 'user-1',
      householdId: null,
      walletId: null,
      isPortfolio: false,
      transaction: ParsedExpense(
        amount: 12,
        category: '',
        currency: 'EUR',
        currencySymbol: '€',
        date: DateTime.utc(2026, 4, 30),
      ),
      captureSource: TransactionCaptureSource.aiText,
      raw: const {'confidence': 0.54},
    );

    expect(command.reviewReasons, contains('missingWallet'));
    expect(command.reviewReasons, contains('missingCategory'));
    expect(command.reviewReasons, contains('lowConfidence'));
  });

  test('resolveAiCaptureSource reflects the user capture channel', () {
    expect(
      resolveAiCaptureSource(
        hasImageInput: false,
        hasAudioInput: true,
        hasAttachments: false,
      ),
      TransactionCaptureSource.voiceNote,
    );
    expect(
      resolveAiCaptureSource(
        hasImageInput: true,
        hasAudioInput: false,
        hasAttachments: false,
      ),
      TransactionCaptureSource.receiptPhoto,
    );
    expect(
      resolveAiCaptureSource(
        hasImageInput: false,
        hasAudioInput: false,
        hasAttachments: true,
      ),
      TransactionCaptureSource.receiptPhoto,
    );
    expect(
      resolveAiCaptureSource(
        hasImageInput: false,
        hasAudioInput: false,
        hasAttachments: false,
      ),
      TransactionCaptureSource.aiText,
    );
  });
}
