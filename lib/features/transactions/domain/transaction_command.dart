enum TransactionCommandType {
  expense,
  income,
  transfer,
}

enum TransactionCaptureSource {
  manual,
  aiText,
  receiptPhoto,
  voiceNote,
  emailReceipt,
  whatsApp,
  bankImport,
  plaidImport,
}

class CreateTransactionCommand {
  const CreateTransactionCommand({
    required this.userId,
    required this.householdId,
    required this.walletId,
    this.bankAccountId,
    this.contactId,
    this.splitGroupId,
    required this.type,
    required this.amountCents,
    required this.currency,
    this.category,
    this.merchant,
    this.rawText,
    this.description,
    this.breakdown = const [],
    required this.date,
    required this.captureSource,
    this.confidenceScore,
    this.reviewReasons = const [],
    this.receiptLocalPath,
    this.receiptImageUrl,
    this.recurrenceRule,
    this.customSplits,
    this.providerTransactionId,
    this.provider,
    this.payerUserId,
    this.isRecurring = false,
    this.isPortfolio = false,
  });

  final String userId;
  final String? householdId;
  final String? walletId;
  final String? bankAccountId;
  final String? contactId;
  final String? splitGroupId;
  final TransactionCommandType type;
  final int amountCents;
  final String currency;
  final String? category;
  final String? merchant;
  final String? rawText;
  final String? description;
  final List<String> breakdown;
  final DateTime date;
  final TransactionCaptureSource captureSource;
  final double? confidenceScore;
  final List<String> reviewReasons;
  final String? receiptLocalPath;
  final String? receiptImageUrl;
  final Map<String, dynamic>? recurrenceRule;
  final Map<String, dynamic>? customSplits;
  final String? providerTransactionId;
  final String? provider;
  final String? payerUserId;
  final bool isRecurring;
  final bool isPortfolio;
}
