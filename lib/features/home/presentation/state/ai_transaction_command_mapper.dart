import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/transactions/domain/transaction_command.dart';

TransactionCaptureSource resolveAiCaptureSource({
  required bool hasImageInput,
  required bool hasAudioInput,
  required bool hasAttachments,
}) {
  if (hasAudioInput) {
    return TransactionCaptureSource.voiceNote;
  }
  if (hasImageInput || hasAttachments) {
    return TransactionCaptureSource.receiptPhoto;
  }
  return TransactionCaptureSource.aiText;
}

CreateTransactionCommand buildAiTransactionCommand({
  required String userId,
  required String? householdId,
  required String? walletId,
  required bool isPortfolio,
  required ParsedExpense transaction,
  required TransactionCaptureSource captureSource,
  Map<String, dynamic> raw = const {},
  String? receiptImageUrl,
  String? localImagePath,
  bool isRecurring = false,
  Map<String, dynamic>? recurrenceRule,
  Map<String, dynamic>? customSplits,
  String? payerUserId,
}) {
  final normalizedWalletId = _normalizeOptionalId(walletId);
  final normalizedCategory = _syncableCategory(transaction.category);
  final confidenceScore = _parseConfidenceScore(raw);

  return CreateTransactionCommand(
    userId: userId,
    householdId: _normalizeOptionalId(householdId),
    walletId: normalizedWalletId,
    type: transaction.isIncome
        ? TransactionCommandType.income
        : TransactionCommandType.expense,
    amountCents: transaction.amountCents.abs(),
    currency: transaction.currency.trim().toUpperCase(),
    category: normalizedCategory,
    merchant: transaction.merchant,
    rawText: transaction.description,
    description: transaction.description,
    breakdown: transaction.breakdown ?? const [],
    date: DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    ),
    captureSource: captureSource,
    confidenceScore: confidenceScore,
    reviewReasons: const [],
    receiptLocalPath: localImagePath ?? transaction.localImagePath,
    receiptImageUrl: receiptImageUrl,
    recurrenceRule: recurrenceRule,
    customSplits: customSplits,
    payerUserId: payerUserId ?? transaction.payerUserId,
    isRecurring: isRecurring,
    isPortfolio: isPortfolio,
  );
}

String? _normalizeOptionalId(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _syncableCategory(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'uncategorized' : trimmed;
}

double? _parseConfidenceScore(Map<String, dynamic> raw) {
  final value = raw['confidenceScore'] ?? raw['confidence'];
  if (value is num) {
    return value.toDouble().clamp(0, 1).toDouble();
  }
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    return parsed?.clamp(0, 1).toDouble();
  }
  return null;
}
