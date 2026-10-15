class WalletTransfer {
  final String id;
  final String fromAccountId;
  final String toAccountId;
  final int amountCents;
  final String currency;
  final int? toAmountCents;
  final String? toCurrency;
  final String? exchangeRate;
  final int feeAmountCents;
  final String? feeExpenseId;
  final int transferContractVersion;

  int get effectiveToAmountCents => toAmountCents ?? amountCents;
  String get effectiveToCurrency => toCurrency ?? currency;
  final DateTime date;
  final String? time;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WalletTransfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountCents,
    required this.currency,
    required this.date,
    this.toAmountCents,
    this.toCurrency,
    this.exchangeRate,
    this.feeAmountCents = 0,
    this.feeExpenseId,
    this.transferContractVersion = 1,
    this.time,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory WalletTransfer.fromJson(Map<String, dynamic> json) {
    return WalletTransfer(
      id: json['id'] as String,
      fromAccountId: json['from_account_id'] as String,
      toAccountId: json['to_account_id'] as String,
      amountCents: (json['amount_cents'] as num?)?.round() ?? 0,
      currency: (json['currency'] as String?) ?? 'USD',
      toAmountCents: (json['to_amount_cents'] as num?)?.round(),
      toCurrency: json['to_currency'] as String?,
      exchangeRate: json['exchange_rate']?.toString(),
      feeAmountCents: (json['fee_amount_cents'] as num?)?.round() ?? 0,
      feeExpenseId: json['fee_expense_id'] as String?,
      transferContractVersion:
          (json['transfer_contract_version'] as num?)?.toInt() ?? 1,
      date:
          DateTime.tryParse((json['date'] as String?) ?? '') ?? DateTime.now(),
      note: json['note'] as String?,
      time: json['time'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}
